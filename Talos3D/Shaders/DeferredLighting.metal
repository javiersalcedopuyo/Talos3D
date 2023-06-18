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
    float4 ndc_position;
};

vertex
VertexOut deferred_lighting_vertex_main(uint id [[ vertex_id ]])
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

    o.ndc_position = o.position;
    return o;
}

// MARK: - Fragment
struct DirectionalLight
{
    float3 direction;
    float4 color;
};

struct Matrices
{
    float4x4 view;
    float4x4 proj;
};

// TODO: Support multiple lights
fragment
float4 deferred_lighting_fragment_main(VertexOut frag [[ stage_in ]],
                                       texture2d<float> g_buffer_0 [[ texture(ALBEDO_AND_METALLIC) ]],
                                       texture2d<float> g_buffer_1 [[ texture(NORMAL_AND_ROUGHNESS) ]],
                                       texture2d<float> g_buffer_2 [[ texture(DEPTH) ]],
                                       texture2d<float> shadow_map [[ texture(SHADOW_MAP) ]],
                                       constant Matrices& matrices [[ buffer(SCENE_MATRICES) ]],
                                       constant DirectionalLight& light [[ buffer(LIGHTS) ]],
                                       constant float4x4& light_matrix  [[ buffer(LIGHT_MATRIX) ]])
{
    // Read the G-Buffer
    auto fragment_coords = static_cast<uint2>(frag.position.xy);

    auto albedo_and_metallic  = g_buffer_0.read(fragment_coords);
    auto normal_and_roughness = g_buffer_1.read(fragment_coords);
    auto depth = g_buffer_2.read(fragment_coords).r;

    auto normal = normal_and_roughness.xyz * 2.f - 1.f;
    auto roughness = normal_and_roughness.w;

    // Diffuse
    auto lambertian = saturate(dot(normal, light.direction.xyz));

    auto albedo   = albedo_and_metallic.rgb;
    auto diffuse  = lambertian * albedo;

    // Ambient
    auto ambient  = float3(0.2f) * albedo; // TODO: Make the ambient coefficient a Scene property

    // Specular
    auto ndc_position = float4(frag.ndc_position.xy,
                               depth,
                               1.f);
    auto view_space_position = inverse(matrices.proj) * ndc_position;

    auto view_space_view_dir = normalize(-view_space_position.xyz);
    auto specular = ComputeGaussianSpecular(view_space_view_dir,
                                            light.direction.xyz,
                                            normal.xyz,
                                            roughness);
    // NOTE: When the lambertian is < 0, there should be no specular.
    // However, I prefer to calculate the specular every time rather than branching on a non-uniform.
    specular *= mix(0.f, 1.f, lambertian >= 0.f);

    // Shadow mapping
    auto light_space_position = light_matrix *
                                invert_linear_transform(matrices.view) *
                                view_space_position;

    auto shadow = is_null_texture(shadow_map)
                    ? 0.f
                    : ComputeShadow(light_space_position, shadow_map);

    // End color
    float4 o;
    o.rgb = light.color.rgb * (diffuse + specular) * (1 - shadow) + ambient;
    o.a = 1.f;

    return o;
}
