#include <metal_stdlib>
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

struct DirectionalLight
{
    packed_float3 direction;
    float  intensity;
    packed_float4 color;
};

struct VertexIn
{
    float3 position [[ attribute(0) ]];
    float3 color    [[ attribute(1) ]];
    float3 normal   [[ attribute(2) ]];
    float2 texcoord [[ attribute(3) ]];
};

struct VertexOut
{
    float4 position [[ position ]];
    float3 color;
    float3 normal;
    float2 texcoord;
};

vertex
VertexOut vertex_main(VertexIn vert [[ stage_in ]],
                      constant SceneMatrices& scene [[ buffer(1) ]],
                      constant ObjectMatrices& obj [[ buffer(2) ]])
{
    VertexOut out;
    out.position = scene.proj * scene.view * obj.model * float4(vert.position, 1.0f);
    out.color    = vert.color;
    out.normal   = (scene.view * obj.normal * float4(vert.normal, 0)).xyz;
    out.texcoord = vert.texcoord;
    return out;
}

fragment
float4 fragment_main(VertexOut        frag [[ stage_in   ]],
                     texture2d<float> tex  [[ texture(0) ]],
                     constant SceneMatrices& scene  [[ buffer(1) ]],
                     constant DirectionalLight& light [[ buffer(3) ]])
{
    constexpr sampler smp(min_filter::nearest,
                          mag_filter::linear,
                          s_address::mirrored_repeat,
                          t_address::mirrored_repeat);
    
    frag.normal = normalize(frag.normal);
    auto lightDirTransformed = normalize(scene.view * float4(-light.direction, 0)).xyz;

    auto albedo = tex.sample(smp, frag.texcoord.xy);

    auto lambertian = saturate(dot(frag.normal, lightDirTransformed.xyz));

    auto diffuse = light.color * light.intensity * lambertian;

    auto ambient = float3(0.1f);

    // TODO: Specular

    auto o = float4(0);
    o.rgb += albedo.rgb * diffuse.rgb +
             ambient;

    // Debug normals
//    o.xyz = (frag.normal + 1.f) * 0.5f;

    o.a = 1.f;
    //return sqrt(o);
    return o;
}
