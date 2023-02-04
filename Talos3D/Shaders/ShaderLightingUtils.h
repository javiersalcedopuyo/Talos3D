//
//  ShaderLightingUtils.h
//  Talos3D
//
//  Created by Javier Salcedo on 4/2/23.
//
#ifndef __METAL_VERSION__
#error This file should only be included in shaders.
#else // __METAL_VERSION__

#ifndef ShaderLightingUtils_h
#define ShaderLightingUtils_h

#include <metal_stdlib>
using namespace metal;

// MARK: - Shadows
/// Percentage-Closer Filtering (PCF) shadow mapping
/// - Parameters:
///     - texCoords: Fragment's position in the shadow map
///     - shadowMap
///     - fragDepth: Fragment's depth as seen from the camera
///     - sampleRadius
/// - Returns:
///     - shadow: [0,1] How shaded the fragment is (0 = fully lit, 1 = fully shaded)
auto PCF(float2            texCoords,
         texture2d<float>  shadowMap,
         float             fragDepth,
         int               sampleRadius)
-> float
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

    shadow /= pow(2 * sampleRadius + 1, 2.f);
    return saturate(shadow);
}

/// Transforms the light's space fragment position into the shadow map's space
/// - Parameters:
///     - lightSpacePosition
/// - Returns:
///     - shadowMapCoord.xy = Shadow map coordinates
///     - shadowMapCoord.z  = Fragment's depth as seen from the light
auto TransformPositionFromLightToShadowMap(float4 lightSpacePosition) -> float3
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
auto ComputeShadow(float4 lightSpacePosition, texture2d<float> shadowMap) -> float
{
    auto shadowMapCoord = TransformPositionFromLightToShadowMap(lightSpacePosition);
    auto fragDepth = shadowMapCoord.z; // NOTE: Depth from the camera!

    auto sampleRadius = 2; // TODO: Make this configurable
    return PCF(shadowMapCoord.xy, shadowMap, fragDepth, sampleRadius);
}

// MARK: - Specular Highlights
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

#endif /* ShaderLightingUtils_h */
#endif // __METAL_VERSION__
