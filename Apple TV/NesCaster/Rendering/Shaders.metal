//
//  Shaders.metal
//  NesCaster
//
//  High-performance shaders for NES emulation:
//  - Integer scaling (pixel-perfect)
//  - 120fps frame interpolation
//  - Optional CRT effects
//  - Sub-pixel accurate rendering
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Structures

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {
    float2 inputSize;      // NES resolution (256x240)
    float2 outputSize;     // Display resolution
    float time;            // For animation effects
    float interpolationFactor;  // 0-1 between frames
    
    // Scaling options
    int scalingMode;       // 0=integer, 1=smooth, 2=crt
    int useOverscan;       // Crop overscan area
    float4 overscan;       // top, bottom, left, right
    
    // CRT effect parameters
    float scanlineIntensity;
    float curvature;
    float vignetteStrength;
    float bloomStrength;
};

// MARK: - Vertex Shader

vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                               constant float4 *vertices [[buffer(0)]]) {
    float4 v = vertices[vertexID];
    VertexOut out;
    out.position = float4(v.x, v.y, 0.0, 1.0);
    out.texCoord = float2(v.z, v.w);
    return out;
}

// MARK: - Integer Scaling (Pixel Perfect)

float4 sampleIntegerScaled(texture2d<float> tex, 
                           float2 texCoord,
                           float2 inputSize,
                           float2 outputSize) {
    constexpr sampler nearestSampler(filter::nearest, address::clamp_to_edge);
    
    // Calculate integer scale factor
    float scaleX = floor(outputSize.x / inputSize.x);
    float scaleY = floor(outputSize.y / inputSize.y);
    float scale = min(scaleX, scaleY);
    
    // Calculate scaled image size
    float2 scaledSize = inputSize * scale;
    
    // Center the image
    float2 offset = (outputSize - scaledSize) / 2.0;
    
    // Transform texture coordinates
    float2 pixelPos = texCoord * outputSize;
    float2 sourcePos = (pixelPos - offset) / scale;
    
    // Check bounds
    if (sourcePos.x < 0.0 || sourcePos.x >= inputSize.x ||
        sourcePos.y < 0.0 || sourcePos.y >= inputSize.y) {
        return float4(0.0, 0.0, 0.0, 1.0); // Black borders
    }
    
    // Sample with nearest neighbor for sharp pixels
    float2 normalizedCoord = sourcePos / inputSize;
    return tex.sample(nearestSampler, normalizedCoord);
}

// MARK: - Smooth Bilinear Scaling

float4 sampleBilinear(texture2d<float> tex, float2 texCoord) {
    constexpr sampler linearSampler(filter::linear, address::clamp_to_edge);
    return tex.sample(linearSampler, texCoord);
}

// MARK: - Frame Interpolation

float4 interpolateFrames(texture2d<float> currentFrame,
                         texture2d<float> previousFrame,
                         float2 texCoord,
                         float factor) {
    constexpr sampler s(filter::nearest, address::clamp_to_edge);
    
    float4 current = currentFrame.sample(s, texCoord);
    float4 previous = previousFrame.sample(s, texCoord);
    
    // Motion-compensated interpolation
    // Simple linear blend (can be enhanced with motion vectors)
    return mix(previous, current, factor);
}

// MARK: - CRT Effects

// Barrel distortion for CRT curvature
float2 applyCurvature(float2 uv, float curvature) {
    float2 centered = uv * 2.0 - 1.0;
    float2 offset = centered * dot(centered, centered) * curvature;
    return (centered + offset) * 0.5 + 0.5;
}

// Scanline effect
float applyScanlines(float2 uv, float2 outputSize, float intensity) {
    float scanline = sin(uv.y * outputSize.y * 3.14159) * 0.5 + 0.5;
    return 1.0 - (1.0 - scanline) * intensity;
}

// Vignette (darkening at edges)
float applyVignette(float2 uv, float strength) {
    float2 centered = uv * 2.0 - 1.0;
    float dist = dot(centered, centered);
    return 1.0 - dist * strength;
}

// Phosphor glow/bloom approximation
float4 applyBloom(texture2d<float> tex, float2 uv, float2 texelSize, float strength) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    
    float4 color = tex.sample(s, uv);
    
    // Simple 5-tap blur for bloom
    float4 bloom = float4(0.0);
    bloom += tex.sample(s, uv + float2(-texelSize.x, 0)) * 0.2;
    bloom += tex.sample(s, uv + float2(texelSize.x, 0)) * 0.2;
    bloom += tex.sample(s, uv + float2(0, -texelSize.y)) * 0.2;
    bloom += tex.sample(s, uv + float2(0, texelSize.y)) * 0.2;
    bloom += color * 0.2;
    
    return color + (bloom - color) * strength;
}

// Full CRT shader
float4 sampleCRT(texture2d<float> tex,
                 float2 texCoord,
                 float2 inputSize,
                 float2 outputSize,
                 float scanlineIntensity,
                 float curvature,
                 float vignetteStrength,
                 float bloomStrength) {
    // Apply curvature
    float2 curvedUV = applyCurvature(texCoord, curvature);
    
    // Check if outside screen
    if (curvedUV.x < 0.0 || curvedUV.x > 1.0 || 
        curvedUV.y < 0.0 || curvedUV.y > 1.0) {
        return float4(0.0, 0.0, 0.0, 1.0);
    }
    
    // Sample with integer scaling
    float4 color = sampleIntegerScaled(tex, curvedUV, inputSize, outputSize);
    
    // Apply bloom
    if (bloomStrength > 0.0) {
        float2 texelSize = 1.0 / outputSize;
        color = applyBloom(tex, curvedUV, texelSize, bloomStrength);
    }
    
    // Apply scanlines
    float scanline = applyScanlines(curvedUV, outputSize, scanlineIntensity);
    color.rgb *= scanline;
    
    // Apply vignette
    float vignette = applyVignette(curvedUV, vignetteStrength);
    color.rgb *= vignette;
    
    return color;
}

// MARK: - Main Fragment Shader

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                               constant Uniforms &uniforms [[buffer(0)]],
                               texture2d<float> tex [[texture(0)]],
                               texture2d<float> prevTex [[texture(1)]]) {
    float2 texCoord = in.texCoord;
    float4 color;
    
    // Apply overscan cropping
    if (uniforms.useOverscan > 0) {
        float2 overscanOffset = float2(uniforms.overscan.z, uniforms.overscan.x);
        float2 overscanScale = float2(
            uniforms.inputSize.x - uniforms.overscan.z - uniforms.overscan.w,
            uniforms.inputSize.y - uniforms.overscan.x - uniforms.overscan.y
        );
        texCoord = texCoord * (overscanScale / uniforms.inputSize) + 
                   (overscanOffset / uniforms.inputSize);
    }
    
    // Select scaling mode
    switch (uniforms.scalingMode) {
        case 0: // Integer scaling (pixel perfect)
            color = sampleIntegerScaled(tex, texCoord, 
                                        uniforms.inputSize, uniforms.outputSize);
            break;
            
        case 1: // Smooth bilinear
            color = sampleBilinear(tex, texCoord);
            break;
            
        case 2: // CRT effect
            color = sampleCRT(tex, texCoord,
                             uniforms.inputSize, uniforms.outputSize,
                             uniforms.scanlineIntensity,
                             uniforms.curvature,
                             uniforms.vignetteStrength,
                             uniforms.bloomStrength);
            break;
            
        default:
            color = sampleIntegerScaled(tex, texCoord,
                                        uniforms.inputSize, uniforms.outputSize);
    }
    
    return color;
}

// MARK: - Frame Interpolation Fragment Shader

fragment float4 interpolationFragmentShader(VertexOut in [[stage_in]],
                                            constant Uniforms &uniforms [[buffer(0)]],
                                            texture2d<float> currentTex [[texture(0)]],
                                            texture2d<float> previousTex [[texture(1)]]) {
    return interpolateFrames(currentTex, previousTex, 
                            in.texCoord, uniforms.interpolationFactor);
}

// MARK: - Compute Kernel for Upscaling

kernel void upscaleKernel(texture2d<float, access::read> input [[texture(0)]],
                          texture2d<float, access::write> output [[texture(1)]],
                          constant Uniforms &uniforms [[buffer(0)]],
                          uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= uint(uniforms.outputSize.x) || 
        gid.y >= uint(uniforms.outputSize.y)) {
        return;
    }
    
    // Calculate source position with integer scaling
    float scaleX = floor(uniforms.outputSize.x / uniforms.inputSize.x);
    float scaleY = floor(uniforms.outputSize.y / uniforms.inputSize.y);
    float scale = min(scaleX, scaleY);
    
    float2 scaledSize = uniforms.inputSize * scale;
    float2 offset = (uniforms.outputSize - scaledSize) / 2.0;
    
    float2 sourcePos = (float2(gid) - offset) / scale;
    
    // Check bounds
    if (sourcePos.x < 0.0 || sourcePos.x >= uniforms.inputSize.x ||
        sourcePos.y < 0.0 || sourcePos.y >= uniforms.inputSize.y) {
        output.write(float4(0.0, 0.0, 0.0, 1.0), gid);
        return;
    }
    
    // Read from input with nearest neighbor
    uint2 inputPos = uint2(sourcePos);
    float4 color = input.read(inputPos);
    
    output.write(color, gid);
}

// MARK: - Scanline Compute Kernel (for post-processing)

kernel void scanlineKernel(texture2d<float, access::read> input [[texture(0)]],
                           texture2d<float, access::write> output [[texture(1)]],
                               constant Uniforms &uniforms [[buffer(0)]],
                               uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= uint(uniforms.outputSize.x) || 
        gid.y >= uint(uniforms.outputSize.y)) {
        return;
    }
    
    float4 color = input.read(gid);
    
    // Apply scanline
    float scanline = sin(float(gid.y) * 3.14159) * 0.5 + 0.5;
    scanline = 1.0 - (1.0 - scanline) * uniforms.scanlineIntensity;
    
    color.rgb *= scanline;
    
    output.write(color, gid);
}
