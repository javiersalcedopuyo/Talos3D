#include <metal_stdlib>

#include "ShadersCommon.h"

using namespace metal;

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

struct DirectionalLight
{
    packed_float3 direction;
    float  intensity;
    packed_float4 color;
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
    float3 color;
    float3 normal;
    float2 texcoord;
};

vertex
VertexOut vertex_main(VertexIn vert [[ stage_in ]],
                      constant SceneMatrices& scene [[ buffer(SCENE_MATRICES) ]],
                      constant ObjectMatrices& obj  [[ buffer(OBJECT_MATRICES) ]])
{
    VertexOut out;
    out.position = scene.proj * scene.view * obj.model * float4(vert.position, 1.0f);
    out.color    = vert.color;
    out.normal   = (scene.view * obj.normal * float4(vert.normal, 0)).xyz;
    out.texcoord = vert.texcoord;
    return out;
}

fragment
float4 fragment_main(VertexOut        frag [[ stage_in ]],
                     texture2d<float> tex  [[ texture(ALBEDO) ]],
                     constant SceneMatrices& scene    [[ buffer(SCENE_MATRICES) ]],
                     constant DirectionalLight& light [[ buffer(LIGHTS) ]])
{
    constexpr sampler smp(min_filter::nearest,
                          mag_filter::linear,
                          s_address::mirrored_repeat,
                          t_address::mirrored_repeat);
    
    frag.normal = normalize(frag.normal);
    auto lightDirTransformed = normalize(scene.view * float4(-light.direction, 0)).xyz;

    auto albedo = tex.sample(smp, frag.texcoord.xy);

    auto lambertian = saturate(dot(frag.normal, lightDirTransformed.xyz));

    auto diffuse = light.color * light.intensity * lambertian;

    auto ambient = float3(0.1f);

    // TODO: Specular

    auto o = float4(0);
    o.rgb += albedo.rgb * diffuse.rgb +
             ambient;

    // Debug normals
//    o.xyz = (frag.normal + 1.f) * 0.5f;

    o.a = 1.f;
    //return sqrt(o);
    return o;
}
