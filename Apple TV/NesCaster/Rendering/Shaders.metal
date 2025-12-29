//
//  Shaders.metal
//  NesCaster
//
//  Metal shaders for high-quality NES rendering
//  - Integer scaling for pixel-perfect output
//  - 120fps frame interpolation
//  - Optional scanline/CRT effects
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Structures

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {
    float2 inputSize;   // NES resolution (256x240)
    float2 outputSize;  // Display resolution (e.g., 3840x2160)
    float time;
    float interpolationFactor;
};

// MARK: - Vertex Shader

vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                               constant float4 *vertices [[buffer(0)]]) {
    // Quad vertices: position (xy) and texcoord (zw) packed
    float4 vertex = vertices[vertexID];
    
    VertexOut out;
    out.position = float4(vertex.xy, 0.0, 1.0);
    out.texCoord = vertex.zw;
    
    return out;
}

// MARK: - Fragment Shader (Pixel Perfect)

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                                constant Uniforms &uniforms [[buffer(0)]],
                                texture2d<float> nesTexture [[texture(0)]]) {
    
    constexpr sampler nearestSampler(mag_filter::nearest,
                                      min_filter::nearest,
                                      address::clamp_to_edge);
    
    // Calculate integer scaling factor
    float scaleX = uniforms.outputSize.x / uniforms.inputSize.x;
    float scaleY = uniforms.outputSize.y / uniforms.inputSize.y;
    float scale = min(floor(scaleX), floor(scaleY));
    
    // Calculate centered viewport
    float2 scaledSize = uniforms.inputSize * scale;
    float2 offset = (uniforms.outputSize - scaledSize) * 0.5;
    
    // Map screen coordinates to NES texture coordinates
    float2 screenPos = in.texCoord * uniforms.outputSize;
    float2 nesPos = (screenPos - offset) / scale;
    float2 nesUV = nesPos / uniforms.inputSize;
    
    // Check if we're within the NES viewport
    if (nesUV.x < 0.0 || nesUV.x > 1.0 || nesUV.y < 0.0 || nesUV.y > 1.0) {
        // Outside viewport - render black bars
        return float4(0.02, 0.02, 0.04, 1.0);
    }
    
    // Sample NES texture with nearest neighbor (pixel perfect)
    float4 color = nesTexture.sample(nearestSampler, nesUV);
    
    return color;
}

// MARK: - Fragment Shader (with Scanlines)

fragment float4 fragmentShaderScanlines(VertexOut in [[stage_in]],
                                         constant Uniforms &uniforms [[buffer(0)]],
                                         texture2d<float> nesTexture [[texture(0)]]) {
    
    constexpr sampler nearestSampler(mag_filter::nearest,
                                      min_filter::nearest,
                                      address::clamp_to_edge);
    
    // Integer scaling
    float scaleX = uniforms.outputSize.x / uniforms.inputSize.x;
    float scaleY = uniforms.outputSize.y / uniforms.inputSize.y;
    float scale = min(floor(scaleX), floor(scaleY));
    
    float2 scaledSize = uniforms.inputSize * scale;
    float2 offset = (uniforms.outputSize - scaledSize) * 0.5;
    
    float2 screenPos = in.texCoord * uniforms.outputSize;
    float2 nesPos = (screenPos - offset) / scale;
    float2 nesUV = nesPos / uniforms.inputSize;
    
    if (nesUV.x < 0.0 || nesUV.x > 1.0 || nesUV.y < 0.0 || nesUV.y > 1.0) {
        return float4(0.02, 0.02, 0.04, 1.0);
    }
    
    float4 color = nesTexture.sample(nearestSampler, nesUV);
    
    // Subtle scanline effect
    float scanline = sin(nesPos.y * 3.14159) * 0.5 + 0.5;
    scanline = mix(0.85, 1.0, scanline);
    
    color.rgb *= scanline;
    
    return color;
}

// MARK: - Upscale Compute Kernel

kernel void upscaleKernel(texture2d<float, access::read> input [[texture(0)]],
                          texture2d<float, access::write> output [[texture(1)]],
                          constant Uniforms &uniforms [[buffer(0)]],
                          uint2 gid [[thread_position_in_grid]]) {
    
    // Calculate source coordinates
    float2 outputSize = float2(output.get_width(), output.get_height());
    float2 inputSize = float2(input.get_width(), input.get_height());
    
    // Integer scaling
    float scale = min(floor(outputSize.x / inputSize.x),
                      floor(outputSize.y / inputSize.y));
    
    float2 scaledSize = inputSize * scale;
    float2 offset = (outputSize - scaledSize) * 0.5;
    
    float2 pos = float2(gid) - offset;
    float2 srcPos = pos / scale;
    
    // Bounds check
    if (srcPos.x < 0 || srcPos.x >= inputSize.x ||
        srcPos.y < 0 || srcPos.y >= inputSize.y) {
        output.write(float4(0.02, 0.02, 0.04, 1.0), gid);
        return;
    }
    
    // Read source pixel (integer coordinates for pixel-perfect)
    uint2 srcCoord = uint2(floor(srcPos));
    float4 color = input.read(srcCoord);
    
    output.write(color, gid);
}

// MARK: - Frame Interpolation Kernel

kernel void interpolateKernel(texture2d<float, access::read> currentFrame [[texture(0)]],
                               texture2d<float, access::read> previousFrame [[texture(1)]],
                               texture2d<float, access::write> output [[texture(2)]],
                               constant Uniforms &uniforms [[buffer(0)]],
                               uint2 gid [[thread_position_in_grid]]) {
    
    float4 current = currentFrame.read(gid);
    float4 previous = previousFrame.read(gid);
    
    // Simple linear interpolation
    // For better quality, implement motion estimation
    float t = uniforms.interpolationFactor;
    float4 interpolated = mix(previous, current, t);
    
    output.write(interpolated, gid);
}

// MARK: - CRT Effect Shader (Optional)

fragment float4 fragmentShaderCRT(VertexOut in [[stage_in]],
                                   constant Uniforms &uniforms [[buffer(0)]],
                                   texture2d<float> nesTexture [[texture(0)]]) {
    
    constexpr sampler linearSampler(mag_filter::linear,
                                     min_filter::linear,
                                     address::clamp_to_edge);
    
    float2 uv = in.texCoord;
    float2 screenPos = uv * uniforms.outputSize;
    
    // Barrel distortion (subtle CRT curve)
    float2 centered = uv - 0.5;
    float dist = length(centered);
    float distortion = 1.0 + dist * dist * 0.03;
    float2 distortedUV = centered * distortion + 0.5;
    
    // Check bounds
    if (distortedUV.x < 0.0 || distortedUV.x > 1.0 ||
        distortedUV.y < 0.0 || distortedUV.y > 1.0) {
        return float4(0.0, 0.0, 0.0, 1.0);
    }
    
    // Sample with slight chromatic aberration
    float aberration = 0.001;
    float r = nesTexture.sample(linearSampler, distortedUV + float2(aberration, 0)).r;
    float g = nesTexture.sample(linearSampler, distortedUV).g;
    float b = nesTexture.sample(linearSampler, distortedUV - float2(aberration, 0)).b;
    
    float4 color = float4(r, g, b, 1.0);
    
    // Scanlines
    float scanline = sin(screenPos.y * 3.14159 * 2.0) * 0.5 + 0.5;
    scanline = mix(0.8, 1.0, scanline);
    color.rgb *= scanline;
    
    // Vignette
    float vignette = 1.0 - dist * 0.5;
    color.rgb *= vignette;
    
    return color;
}

