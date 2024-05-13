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
    float3 camera_pos;
};


struct VertexOut
{
    float4 position [[ position ]] [[ invariant ]];
    float2 UVs;
    float2 fade_UVs;
};

using FragmentIn = VertexOut;


// - MARK: Constants
static constant auto grid_size = 100.0f;

static constant auto cell_size = 1.0f;
static constant auto cell_line_thickness = 2.0f;

static constant auto subcell_size = 0.1f;
static constant auto subcell_line_thickness = 1.0f;

static constant auto min_texels_between_cells = 2.0;

static constant auto grid_color = float4( 0.75, 0.75, 0.75, 0.5 );

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
    vpos.xz += scene.camera_pos.xz; // Make the quad follow the camera so it *looks* infinite

    // Fade the grid around the camera projection on the plane
    auto fade_UVs = positions[ id ].xz * 2.0;
    {
        // Reduce the fade radius as the camera closer than 1m to the plane
        auto t = 1.0 - saturate( abs(scene.camera_pos.y) );
        fade_UVs *= mix(3.5, 10., t);
    }

    return {
        .position = scene.proj * scene.view * vpos,
        .UVs = vpos.xz * 2.0 / grid_size,
        .fade_UVs = fade_UVs };
}


// - MARK: Fragment
fragment
auto grid_gizmo_fragment_main( FragmentIn frag [[ stage_in ]]) -> float4
{
    const auto dudv = float2(
        length( float2( dfdx(frag.UVs.x), dfdy(frag.UVs.x) ) ),
        length( float2( dfdx(frag.UVs.y), dfdy(frag.UVs.y) ) ) );

    float lod;
    {
        const auto uv_change_between_fragments = length(dudv);
        const auto cells_between_fragments = uv_change_between_fragments * grid_size / cell_size;

        lod = max(0.0, log10( cells_between_fragments * min_texels_between_cells + 1.0 ));
    }

    auto cell_size_lod = cell_size * pow(10.0, floor(lod));
    auto subcell_size_lod = subcell_size * pow(10.0, floor(lod));

    // Coordinates within the cell [-cell_size, cell_size] divided by how many texels a line
    // would cover in this fragment (dudv basically tell us how many texels this fragment covers).
    // The abs of that is the distance in texels to the line. Since we only want to draw the line
    // itself, we'll only write to the framebuffer when that distance is less than the line thickness.
    auto distance_to_cell_line = abs(
        fmod(frag.UVs * grid_size, cell_size_lod * 2.0)
        / (dudv * grid_size) );

    auto distance_to_subcell_line = abs(
        fmod(frag.UVs * grid_size, subcell_size_lod * 2.0)
        / (dudv * grid_size) );
    

    if ( all( distance_to_cell_line > cell_line_thickness )
        && all( distance_to_subcell_line > subcell_line_thickness ) )
    {
        discard_fragment();
    }

    const auto opacity_falloff = 1.0 - sqrt( length(frag.fade_UVs) );
    auto output = grid_color;
    output.a *= opacity_falloff;
    return output;
}
