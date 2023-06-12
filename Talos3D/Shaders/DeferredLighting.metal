//
//  DeferredLighting.metal
//  Talos3D
//
//  Created by Javier Salcedo on 9/6/23.
//

#include <metal_stdlib>
#include "ShadersCommon.h"
#include "ShaderUtils.h"
#include "ShaderLightingUtils.h"

using namespace metal;


// MARK: - Vertex
struct VertexOut
{
    float4 position [[ position ]];
    float4 view_direction_in_view_space;
};

vertex
VertexOut deferred_lighting_vertex_main(uint id [[ vertex_id ]],
                                        constant float4x4& proj [[ buffer(SCENE_MATRICES) ]])
{
    VertexOut o;

    // TODO: Use math to avoid branching
    switch (id)
    {
        default:
        case 0:
            o.position  = float4(-1, 1, 0, 1);
            break;
        case 1:
            o.position  = float4(1, 1, 0, 1);
            break;
        case 2:
            o.position  = float4(-1, -1, 0, 1);
            break;
        case 3:
            o.position  = float4(1, -1, 0, 1);
            break;
    }

    // TODO: Invert the matrix in the CPU
    o.view_direction_in_view_space = inverse(proj) * -o.position;
    return o;
}

// MARK: - Fragment
struct DirectionalLight
{
    float3 direction;
    float4 color;
};

// TODO: Support multiple lights
fragment
float4 deferred_lighting_fragment_main(VertexOut frag [[ stage_in ]],
                                       texture2d<float> g_buffer_0 [[ texture(ALBEDO_AND_METALLIC) ]],
                                       texture2d<float> g_buffer_1 [[ texture(NORMAL_AND_ROUGHNESS) ]],
                                       constant DirectionalLight& light [[ buffer(LIGHTS) ]])
{
    auto fragment_coords = static_cast<uint2>(frag.position.xy);
    auto albedo_and_metallic  = g_buffer_0.read(fragment_coords);
    auto normal_and_roughness = g_buffer_1.read(fragment_coords);

    auto normal = normal_and_roughness.xyz * 2.f - 1.f;
    auto roughness = normal_and_roughness.w;

    auto lambertian = saturate(dot(normal, light.direction.xyz));

    auto albedo   = albedo_and_metallic.rgb;
    auto diffuse  = lambertian * albedo;

    auto ambient  = float3(0.2f) * albedo; // TODO: Make the ambient coefficient a Scene property

    auto specular = ComputeGaussianSpecular(normalize(frag.view_direction_in_view_space.xyz),
                                            light.direction.xyz,
                                            normal.xyz,
                                            roughness);
    // NOTE: When the lambertian is < 0, there should be no specular.
    // However, I prefer to calculate the specular every time rather than branching on a non-uniform.
    specular *= mix(0.f, 1.f, lambertian >= 0.f);

    // TODO: Shadow mapping

    float4 o;
    o.rgb = light.color.rgb * (diffuse + specular) /* (1 - shadow) */ + ambient;
    o.a = 1.f;

    return o;
}
