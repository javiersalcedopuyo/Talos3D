//
//  GBufferShaders.metal
//  Talos3D
//
//  Created by Javier Salcedo on 6/6/23.
//

#include <metal_stdlib>
#include "ShadersCommon.h"
using namespace metal;


// MARK: - Common struct definitions
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

// MARK: - Vertex Stage
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
VertexOut g_buffer_vertex_main(VertexIn                  vert            [[ stage_in ]],
                               constant SceneMatrices&   scene           [[ buffer(SCENE_MATRICES) ]],
                               constant ObjectMatrices&  obj             [[ buffer(OBJECT_MATRICES) ]],
                               constant float4x4&        lightViewProj   [[ buffer(LIGHT_MATRIX) ]])
{
    return {
        .position   = scene.proj * scene.view * obj.model * float4(vert.position, 1.0f),
        .color      = vert.color,
        .normal     = (scene.view * obj.normal * float4(vert.normal, 0)).xyz,
        .texcoord   = vert.texcoord
    };
}

// MARK: - Fragment Stage
struct MaterialParams
{
    packed_float3 tint;
    float roughness;
    float metallic;

    packed_float3 padding; // Do I need this?
};

struct GBufferOut
{
    float4 albedo_and_metallic  [[ color(0) ]];
    float4 normal_and_roughness [[ color(1) ]];
};

fragment
GBufferOut g_buffer_fragment_main(VertexOut                frag         [[ stage_in ]],
                                   texture2d<float>         tex         [[ texture(ALBEDO) ]],
                                   constant MaterialParams& material    [[ buffer(MATERIAL_PARAMS) ]])

{
    GBufferOut output;

    constexpr sampler smp(min_filter::nearest,
                          mag_filter::linear,
                          s_address::mirrored_repeat,
                          t_address::mirrored_repeat);

    auto albedo = is_null_texture(tex)
                    ? float4(1,0,1,1)
                    : tex.sample(smp, frag.texcoord.xy);

    albedo.rgb *= material.tint;

    output.albedo_and_metallic.rgb  = albedo.rgb;
    output.albedo_and_metallic.w    = material.metallic;

    auto normal_in_view_space = normalize(frag.normal);
    output.normal_and_roughness.xyz = (normal_in_view_space + 1.f) * 0.5f;
    output.normal_and_roughness.w   = material.roughness;

    return output;
}
