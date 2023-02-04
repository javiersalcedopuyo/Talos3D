#include <metal_stdlib>

#include "ShadersCommon.h"

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
    float4 positionInViewSpace;
    float3 color;
    float3 normal;
    float2 texcoord;
};

constant constexpr float glossy = 64.f; // TODO: Make this a material attribute

// MARK: - Helper functions
/// Percentage-Closer Filtering (PCF) shadow mapping
/// - Parameters:
///     - texCoords: Fragment's position in the shadow map
///     - shadowMap
///     - fragDepth: Fragment's depth as seen from the camera
///     - sampleRadius
/// - Returns:
///     - shadow: [0,1] How shaded the fragment is (0 = fully lit, 1 = fully shaded)
float PCF(float2            texCoords,
          texture2d<float>  shadowMap,
          float             fragDepth,
          int               sampleRadius)
{
    constexpr sampler smp(min_filter::linear,
                          mag_filter::linear,
                          s_address::clamp_to_border,
                          t_address::clamp_to_border,
                          border_color::opaque_white);

    auto texelSize = 1.f / float2(shadowMap.get_width(), shadowMap.get_height());

    auto shadow = 0.f;
    for (int u = -sampleRadius; u <= sampleRadius; ++u)
    {
        for (int v = -sampleRadius; v <= sampleRadius; ++v)
        {
            auto offset = float2(u,v) * texelSize;
            auto mapDepth = shadowMap.sample(smp, texCoords.xy + offset).x;

            // NOTE: The bias is already applied in the shadow pass
            shadow += fragDepth >= mapDepth ? 1.f : 0.f;
        }
    }

    return shadow / pow(2 * sampleRadius + 1, 2.f);
}

/// Transforms the light's space fragment position into the shadow map's space
/// - Parameters:
///     - lightSpacePosition
/// - Returns:
///     - shadowMapCoord.xy = Shadow map coordinates
///     - shadowMapCoord.z  = Fragment's depth as seen from the light
float3 TransformPositionFromLightToShadowMap(float4 lightSpacePosition)
{
    // Transform from clip to device coordinate system.
    // Orthographic projection matrices don't really need it.
    auto shadowMapCoord = lightSpacePosition / lightSpacePosition.w;
    // Normalise the coordinates to the [0,1] range.
    // Depends on the projection matrix and the device coordinate system
    shadowMapCoord.y = -shadowMapCoord.y;
    shadowMapCoord.xy = (shadowMapCoord.xy + 1.f) * 0.5f;

    return shadowMapCoord.xyz;
}

/// Computes the shadow coefficient from a 2D shadow map
/// Parameters:
///     - lightSpacePosition
///     - shadowMap
/// - Returns:
///     - shadowCoefficient: [0,1] How shaded the fragment is (0 = fully lit, 1 = fully shaded)
float ComputeShadow(float4 lightSpacePosition, texture2d<float> shadowMap)
{
    auto shadowMapCoord = TransformPositionFromLightToShadowMap(lightSpacePosition);
    auto fragDepth = shadowMapCoord.z; // NOTE: Depth from the camera!

    auto sampleRadius = 2; // TODO: Make this configurable
    return PCF(shadowMapCoord.xy, shadowMap, fragDepth, sampleRadius);
}

/// Computes the specular highlight following to the Blinn model
/// Parameters:
///     - viewDirection
///     - lightDirection
///     - normal
///     - glossyCoefficient
/// Returns:
///     - Specular Coefficient
auto ComputeBlinnSpecular(float3 viewDirection,
                          float3 lightDirection,
                          float3 normal,
                          float  glossyCoefficient)
-> float
{
    auto halfVector = normalize(lightDirection + viewDirection);
    auto specularAngle = max(dot(halfVector, normal), 0.f);

    return pow(specularAngle, glossyCoefficient);
}

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

    // TODO: Add tint as a material property
    auto albedo = is_null_texture(tex)
                    ? float4(1,0,1,1)
                    : tex.sample(smp, frag.texcoord.xy);

    auto lambertian = saturate(dot(frag.normal, lightDirTransformed.xyz));

    auto ambient  = float4(0.2f) * albedo; // TODO: Make the ambient coefficient a Scene property
    auto diffuse  = lambertian * albedo;
    auto specular = ComputeBlinnSpecular(normalize(-frag.positionInViewSpace).xyz,  // viewDirection
                                         lightDirTransformed,                       // lightDirection
                                         frag.normal,                               // normal
                                         glossy);                                   // glossyCoefficient

    auto shadow = is_null_texture(shadowMap)
                    ? 0.f
                    : ComputeShadow(frag.positionInLightSpace, shadowMap);

    auto o = light.color * light.intensity * (diffuse + specular) * (1 - shadow) + ambient;
    // Debug normals
//    o.xyz = (frag.normal + 1.f) * 0.5f;

    o.a = 1.f;
    //return sqrt(o);
    return o;
}
