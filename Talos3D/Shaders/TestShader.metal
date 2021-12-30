#include <metal_stdlib>
using namespace metal;

struct UniformBufferObject
{
    float4x4 model;
    float4x4 view;
    float4x4 proj;
};

struct VertexIn
{
    float3 position [[ attribute(0) ]];
    float3 color    [[ attribute(1) ]];
    float3 normal   [[ attribute(2) ]]; // Unused for now
    float2 texcoord [[ attribute(3) ]];
};

struct VertexOut
{
    float4 position [[ position ]];
    float3 color;
    float3 normal; // Unused for  now
    float2 texcoord;
};

vertex
VertexOut vertex_main(VertexIn vert [[ stage_in ]],
                      constant UniformBufferObject& ubo [[ buffer(1) ]])
{
    VertexOut out;
    out.position = ubo.proj * ubo.view * ubo.model * float4(vert.position, 1.0f);
    out.color    = vert.color;
    out.normal   = vert.normal;
    out.texcoord = vert.texcoord;
    return out;
}

fragment
float4 fragment_main(VertexOut        frag [[ stage_in   ]],
                     texture2d<float> tex  [[ texture(0) ]],
                     sampler          smp  [[ sampler(0) ]])
{
    return sqrt( tex.sample(smp, frag.texcoord.xy) );
}
