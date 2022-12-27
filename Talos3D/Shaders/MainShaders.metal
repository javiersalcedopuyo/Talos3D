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
    float4 positionInLightSpace;
    float3 color;
    float3 normal;
    float2 texcoord;
};





vertex
VertexOut vertex_main(VertexIn                  vert            [[ stage_in ]],
                      constant SceneMatrices&   scene           [[ buffer(SCENE_MATRICES) ]],
                      constant ObjectMatrices&  obj             [[ buffer(OBJECT_MATRICES) ]],
                      constant float4x4&        lightViewProj   [[ buffer(LIGHT_MATRIX) ]])
{
    VertexOut out;
    out.position = scene.proj * scene.view * obj.model * float4(vert.position, 1.0f);
    out.positionInLightSpace = lightViewProj * obj.model * float4(vert.position, 1.0f);
    out.color    = vert.color;
    out.normal   = (scene.view * obj.normal * float4(vert.normal, 0)).xyz;
    out.texcoord = vert.texcoord;
    return out;
}





float ComputeShadow(float4 position, texture2d<float> shadowMap)
{
    constexpr sampler smp(min_filter::linear,
                          mag_filter::linear,
                          s_address::clamp_to_border,
                          t_address::clamp_to_border,
                          border_color::opaque_white);

    // Transform from clip to device coordinate system.
    // Orthographic projection matrices don't really need it.
    auto lightCoords = position / position.w;
    // Normalise the coordinates to the [0,1] range.
    // Depends on the projection matrix and the device coordinate system
    lightCoords.y = -lightCoords.y;
    lightCoords.xy = (lightCoords.xy + 1.f) * 0.5f;

    auto currentDepth = lightCoords.z;

    // Percentage-Closer Filtering (PCF)
    auto texelSize = 1.f / float2(shadowMap.get_width(), shadowMap.get_height());
    auto shadow = 0.f;

    auto sampleRadius = 2; // TODO: Make this configurable

    for (int u = -sampleRadius; u <= sampleRadius; ++u)
    {
        for (int v = -sampleRadius; v <= sampleRadius; ++v)
        {
            auto offset = float2(u,v) * texelSize;
            auto closestDepth = shadowMap.sample(smp, lightCoords.xy + offset).x;

            // NOTE: The bias is already applied in the shadow pass
            shadow += currentDepth >= closestDepth ? 1.f : 0.f;
        }
    }

    return shadow / pow(2 * sampleRadius + 1, 2.f);
}





fragment
float4 fragment_main(VertexOut                  frag        [[ stage_in ]],
                     texture2d<float>           tex         [[ texture(ALBEDO) ]],
                     texture2d<float>           shadowMap   [[ texture(SHADOW_MAP) ]],
                     constant SceneMatrices&    scene       [[ buffer(SCENE_MATRICES) ]],
                     constant DirectionalLight& light       [[ buffer(LIGHTS) ]],
                     constant float4x4&         lightMatrix [[ buffer(LIGHT_MATRIX) ]])
{
    constexpr sampler smp(min_filter::nearest,
                          mag_filter::linear,
                          s_address::mirrored_repeat,
                          t_address::mirrored_repeat);

    frag.normal = normalize(frag.normal);
    auto lightDirTransformed = normalize(scene.view * float4(-light.direction, 0)).xyz;

    auto albedo = is_null_texture(tex)
                    ? float4(1,0,1,1)
                    : tex.sample(smp, frag.texcoord.xy);

    auto lambertian = saturate(dot(frag.normal, lightDirTransformed.xyz));

    auto diffuse = light.color * light.intensity * lambertian;

    auto ambient = float3(0.2f);

    // TODO: Specular

    auto shadow = is_null_texture(shadowMap)
                    ? 0.f
                    : ComputeShadow(frag.positionInLightSpace, shadowMap);

    auto o = float4(0);
    o.rgb += albedo.rgb * (diffuse.rgb * (1.f - shadow) + ambient);

    // Debug normals
//    o.xyz = (frag.normal + 1.f) * 0.5f;

    o.a = 1.f;
    //return sqrt(o);
    return o;
}
