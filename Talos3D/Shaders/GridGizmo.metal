//
//  GridGizmo.metal
//  Talos3D
//
//  Created by Javier Salcedo on 2/5/24.
//

// - MARK: Includes
#include <metal_stdlib>
#include "ShadersCommon.h"
#include "ShaderUtils.h"


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
    float3 camera_pos [[ flat ]];
    float2 coords;
};


// - MARK: Constants
static constant auto grid_size = 100.0f;

static constant auto cell_size = 1.0f;
static constant auto half_cell_size = cell_size * 0.5;
static constant auto cell_line_thickness = 0.01f;

static constant auto subcell_size = 0.1f;
static constant auto half_subcell_size = subcell_size * 0.5;
static constant auto subcell_line_thickness = 0.001f;

static constant auto cell_color    = float4( 0.75, 0.75, 0.75, 0.5 );
static constant auto subcell_color = float4( 0.5, 0.5, 0.5, 0.5 );

static constant auto height_to_fade_distance_ratio = 25.0f;
static constant auto min_fade_distance = grid_size * 0.05f;
static constant auto max_fade_distance = grid_size * 0.5f;

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
    auto world_pos = positions[ id ];
    world_pos.xyz *= grid_size;
    world_pos.xz += scene.camera_pos.xz; // Make the quad follow the camera so it *looks* infinite

    return {
        .position   = scene.proj * scene.view * world_pos,
        .camera_pos = scene.camera_pos,
        .coords     = world_pos.xz };
}


// - MARK: Fragment
using FragmentIn = VertexOut;

fragment
auto grid_gizmo_fragment_main( FragmentIn frag [[ stage_in ]]) -> float4
{
    // First, displace the plane coordinates so the origin is in a corner rather than in the middle
    // of the (sub)cell.
    // Then get the coordinates inside the (sub)cell, in the range [0, (sub)cell_size]
    const auto cell_coords    = mod(frag.coords + half_cell_size,    cell_size   );
    const auto subcell_coords = mod(frag.coords + half_subcell_size, subcell_size);

    // Move the (sub)cell coordinates so their origin is now in the middle of the (sub)cell.
    // The absolute value of that is the distance in X and Y to the edge of the (sub)cell.
    const auto distance_to_cell    = abs(cell_coords    - half_cell_size   );
    const auto distance_to_subcell = abs(subcell_coords - half_subcell_size);

    // Increase the line thickness by how much the plane coordinates vary in this fragment.
    // This prevents the lines disappearing/getting gaps when they're far from the camera.
    // Half it because only half the line is within a single cell.
    const auto d = fwidth(frag.coords);
    const auto adjusted_cell_line_thickness    = 0.5 * (cell_line_thickness    + d);
    const auto adjusted_subcell_line_thickness = 0.5 * (subcell_line_thickness + d);

    auto color = float4(0);
    if ( any(distance_to_subcell < adjusted_subcell_line_thickness) )
    {
        color = subcell_color;
    }
    if ( any(distance_to_cell < adjusted_cell_line_thickness) )
    {
        color = cell_color;
    }

    // Fade out around the camera to hide visual artifacts
    float opacity_falloff;
    {
        auto distance_to_camera = length(frag.coords - frag.camera_pos.xz);
        // Adjust the fade distance relative to the camera height
        auto fade_distance = abs(frag.camera_pos.y) * height_to_fade_distance_ratio;
        {
            fade_distance = max(fade_distance, min_fade_distance);
            fade_distance = min(fade_distance, max_fade_distance);
        }
        opacity_falloff = smoothstep(1.0, 0.0, distance_to_camera / fade_distance);
    }

    return color * opacity_falloff;
}
