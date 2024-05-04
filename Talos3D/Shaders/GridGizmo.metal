//
//  GridGizmo.metal
//  Talos3D
//
//  Created by Javier Salcedo on 2/5/24.
//

// - MARK: Includes
#include <metal_stdlib>
#include "ShadersCommon.h"


// - MARK: Definitions
using namespace metal;

struct SceneMatrices
{
    float4x4 view;
    float4x4 proj;
};


struct VertexOut
{
    float4 position [[ position ]];
    float2 UVs;
};

using FragmentIn = VertexOut;


// - MARK: Constants
static constant auto grid_size = 100.0f;
static constant auto cell_size = 1.0f;
static constant auto subcell_size = 0.1f;

static constant auto grid_color = float4( 0.5, 0.5, 0.5, 0.5 );

static constant float4 positions[4]{
    { -0.5, 0.0,  0.5, 1.0 },
    {  0.5, 0.0,  0.5, 1.0 },
    { -0.5, 0.0, -0.5, 1.0 },
    {  0.5, 0.0, -0.5, 1.0 } };


// - MARK: Vertex
vertex
auto grid_gizmo_vertex_main(
    uint id [[vertex_id]],
    constant SceneMatrices& scene [[ buffer(SCENE_MATRICES) ]])
-> VertexOut
{
    auto vpos = positions[ id ];
    vpos.xyz *= grid_size;

    return {
        .position = scene.proj * scene.view * vpos,
        .UVs = positions[id].xz * 2.0 };
}


// - MARK: Fragment
fragment
auto grid_gizmo_fragment_main( FragmentIn frag [[ stage_in ]]) -> float4
{
    // UVs within the cell & subcell [-1,1]
    const auto cell_UVs     = fmod( frag.UVs * grid_size, cell_size ) / cell_size;
    const auto subcell_UVs  = fmod( frag.UVs * grid_size, subcell_size ) / subcell_size;

    if (  any( abs(cell_UVs)    < 0.01 )
       || any( abs(subcell_UVs) < 0.0333 ) )
    {
        return grid_color;
    }
    return{0};
}
