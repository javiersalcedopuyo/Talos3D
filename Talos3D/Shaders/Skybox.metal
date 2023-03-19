//
//  Skybox.metal
//  Talos3D
//
//  Created by Javier Salcedo on 16/3/23.
//

#include <metal_stdlib>
using namespace metal;

struct VertexOut
{
    float4 position [[ position ]];
};

constant constexpr float4 SKY_BLUE{.52f, .81f, .92f, 1.f};

vertex
VertexOut skybox_vertex_main(uint id [[vertex_id]])
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
    return out;
}

fragment
float4 skybox_fragment_main(VertexOut frag [[ stage_in ]])
{
    return SKY_BLUE;
}


