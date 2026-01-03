#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {
    float2 inputSize;
    float2 outputSize;
    float time;
    float interpolationFactor;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                              constant float4 *vertices [[buffer(0)]]) {
    float4 v = vertices[vertexID];
    VertexOut out;
    out.position = float4(v.x, v.y, 0.0, 1.0);
    out.texCoord = float2(v.z, v.w);
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                               constant Uniforms &uniforms [[buffer(0)]],
                               texture2d<float> tex [[texture(0)]]) {
    constexpr sampler s(filter::nearest);
    return tex.sample(s, in.texCoord);
}
