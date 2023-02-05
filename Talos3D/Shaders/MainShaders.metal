#include <metal_stdlib>

#include "ShadersCommon.h"
#include "ShaderLightingUtils.h"

using namespace metal;

// MARK: - Struct definitions
struct SceneMatrices
{
    float4x4 view;
    float4x4 proj;
};

struct ObjectMatrices
{
    float4x4 model;
    float4x4 normal;
};

struct VertexIn
{
    float3 position [[ attribute(POSITION) ]];
    float3 color    [[ attribute(COLOR) ]];
    float3 normal   [[ attribute(NORMAL) ]];
    float2 texcoord [[ attribute(TEXCOORD) ]];
};

struct VertexOut
{
    float4 position [[ position ]];
    float4 positionInLightSpace;
    float4 positionInViewSpace;
    float3 color;
    float3 normal;
    float2 texcoord;
};

// MARK: - Main functions
vertex
VertexOut vertex_main(VertexIn                  vert            [[ stage_in ]],
                      constant SceneMatrices&   scene           [[ buffer(SCENE_MATRICES) ]],
                      constant ObjectMatrices&  obj             [[ buffer(OBJECT_MATRICES) ]],
                      constant float4x4&        lightViewProj   [[ buffer(LIGHT_MATRIX) ]])
{
    VertexOut out;
    out.positionInViewSpace = scene.view * obj.model * float4(vert.position, 1.0f);
    out.positionInViewSpace /= out.positionInViewSpace.w;
    out.position = scene.proj * out.positionInViewSpace;
    out.positionInLightSpace = lightViewProj * obj.model * float4(vert.position, 1.0f);
    out.color    = vert.color;
    out.normal   = (scene.view * obj.normal * float4(vert.normal, 0)).xyz;
    out.texcoord = vert.texcoord;
    return out;
}

struct DirectionalLight
{
    packed_float3 direction;
    float  intensity;
    packed_float4 color;
};

struct MaterialParams
{
    packed_float3 tint;
    float roughness;
    float metallic;

    packed_float3 padding; // Do I need this?
};

fragment
float4 fragment_main(VertexOut                  frag        [[ stage_in ]],
                     texture2d<float>           tex         [[ texture(ALBEDO) ]],
                     texture2d<float>           shadowMap   [[ texture(SHADOW_MAP) ]],
                     constant SceneMatrices&    scene       [[ buffer(SCENE_MATRICES) ]],
                     constant DirectionalLight& light       [[ buffer(LIGHTS) ]],
                     constant float4x4&         lightMatrix [[ buffer(LIGHT_MATRIX) ]],
                     constant MaterialParams&   material    [[ buffer(MATERIAL_PARAMS) ]])
{
    constexpr sampler smp(min_filter::nearest,
                          mag_filter::linear,
                          s_address::mirrored_repeat,
                          t_address::mirrored_repeat);

    auto normalInViewSpace      = normalize(frag.normal);
    auto lightDirInViewSpace    = normalize(scene.view * float4(-light.direction, 0));
    auto viewDirInViewSpace     = normalize(-frag.positionInViewSpace);

    auto albedo = is_null_texture(tex)
                    ? float4(1,0,1,1)
                    : tex.sample(smp, frag.texcoord.xy);

    albedo.rgb *= material.tint;

    auto lambertian = saturate(dot(normalInViewSpace, lightDirInViewSpace.xyz));

    auto ambient  = float4(0.2f) * albedo; // TODO: Make the ambient coefficient a Scene property
    auto diffuse  = lambertian * albedo;
    auto specular = ComputeGaussianSpecular(viewDirInViewSpace.xyz,
                                            lightDirInViewSpace.xyz,
                                            normalInViewSpace.xyz,
                                            material.roughness);

    // NOTE: When the lambertian is < 0, there should be no specular.
    // However, I prefer to calculate the specular every time rather than branching on a non-uniform.
    specular *= mix(0.f, 1.f, lambertian >= 0.f);

    auto shadow = is_null_texture(shadowMap)
                    ? 0.f
                    : ComputeShadow(frag.positionInLightSpace, shadowMap);

    auto o = light.color * light.intensity * (diffuse + specular) * (1 - shadow) + ambient;
    // Debug normals
//    o.xyz = (normalInViewSpace + 1.f) * 0.5f;

    o.a = 1.f;
    //return sqrt(o);
    return o;
}
