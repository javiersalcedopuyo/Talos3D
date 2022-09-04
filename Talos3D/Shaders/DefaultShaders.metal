//
//  DefaultShaders.metal
//  Talos3D
//
//  Created by Javier Salcedo on 4/9/22.
//

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
};

constant constexpr float4 DEBUG_PINK {1.f, 0.f, 1.f, 1.f};

vertex
VertexOut default_vertex_main(VertexIn vert [[ stage_in ]],
                              constant SceneMatrices& scene [[ buffer(SCENE_MATRICES) ]],
                              constant ObjectMatrices& obj  [[ buffer(OBJECT_MATRICES) ]])
{
    VertexOut out;
    out.position = scene.proj * scene.view * obj.model * float4(vert.position, 1.0f);
    return out;
}

fragment
float4 default_fragment_main(VertexOut frag [[ stage_in ]])
{
    return DEBUG_PINK;
}


