//
//  ShadowPass.metal
//  Talos3D
//
//  Created by Javier Salcedo on 11/12/22.
//

#include <metal_stdlib>
#include "ShadersCommon.h"

using namespace metal;

struct VertexIn
{
    float3 position [[ attribute(POSITION) ]];
};

struct VertexOut
{
    float4 position [[ position ]];
};

vertex
VertexOut shadow_vertex_main(VertexIn vert                 [[ stage_in ]],
                             constant float4x4& view_proj  [[ buffer(SCENE_MATRICES) ]],
                             constant float4x4& model      [[ buffer(OBJECT_MATRICES) ]])
{
    return { view_proj * model * float4(vert.position, 1.0f) };
}

