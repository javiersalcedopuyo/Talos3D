//
//  Skybox.metal
//  Talos3D
//
//  Created by Javier Salcedo on 16/3/23.
//

#include <metal_stdlib>
#include "ShadersCommon.h"
using namespace metal;

struct SceneMatrices
{
    float4x4 view;
    float4x4 proj;
};

struct VertexOut
{
    float4 position [[ position ]];
    float4 position_in_view_space;
};

vertex
VertexOut skybox_vertex_main(uint id [[vertex_id]],
                             constant SceneMatrices& scene [[ buffer(SCENE_MATRICES) ]])
{
    VertexOut out;
    // TODO: Use math to avoid branching
    switch (id)
    {
        default:
        case 0:
            out.position = float4(-1, 1, 0, 1);
            break;
        case 1:
            out.position = float4(1, 1, 0, 1);
            break;
        case 2:
            out.position = float4(-1, -1, 0, 1);
            break;
        case 3:
            out.position = float4(1, -1, 0, 1);
            break;
    }

    // FIXME: This math doesn't really work because it's meant for world-space skyboxes!
    out.position_in_view_space = scene.proj * scene.view * out.position;
    return out;
}

fragment
float4 skybox_fragment_main(VertexOut frag [[ stage_in ]],
                            texturecube<float, access::sample> skybox [[texture(SKYBOX)]])
{
    constexpr sampler smp(min_filter::linear,
                          mag_filter::linear,
                          s_address::mirrored_repeat,
                          t_address::mirrored_repeat);

    return skybox.sample(smp, -frag.position_in_view_space.xyz);
}


