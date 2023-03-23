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
    float4 view_dir_in_world_space;
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

    // NOTE: Transposing them on the CPU would save time in the GPU, but it's only 4 vertices (3 in
    // the future, so the cost of rebinding the transposed matrices is probably higher than doing it
    // in the shader.
    out.view_dir_in_world_space = transpose(scene.view) * transpose(scene.proj) * -normalize(out.position);
    return out;
}

fragment
float4 skybox_fragment_main(VertexOut frag [[ stage_in ]],
                            texturecube<float, access::sample> skybox [[texture(SKYBOX)]])
{
    constexpr sampler smp(min_filter::linear,
                          mag_filter::linear,
                          s_address::clamp_to_edge,
                          t_address::clamp_to_edge);

    return sqrt(skybox.sample(smp, normalize(frag.view_dir_in_world_space.xyz)));
}


