import SwiftUI
import MetalKit
import simd

// MARK: - Metal Types
struct WeatherUniforms {
    var time: Float              // Offset 0
    var _pad1: Float = 0         // Offset 4
    var resolution: SIMD2<Float> // Offset 8
    var weatherCode: Int32       // Offset 16
    var timeOfDay: Int32         // Offset 20
    var style: Int32             // Offset 24 (0: Realistic, 1: Glassmorphic)
    var variant: Int32           // Offset 28 (0: Cinematic, 1: Soft)
}

// MARK: - Metal Weather View Representable
struct MetalWeatherView: NSViewRepresentable {
    let weatherCode: Int
    let timeOfDay: Int // Pass logic from parent
    let style: WeatherStyle
    let variant: Int 
    
    // Default int for generic usage, but parent should ideally control this
    init(weatherCode: Int, timeOfDay: Int = 0, style: WeatherStyle = .realistic, variant: Int = 0) {
        self.weatherCode = weatherCode
        self.timeOfDay = timeOfDay
        self.style = style
        self.variant = variant
    }
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.framebufferOnly = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.preferredFramesPerSecond = 60
        mtkView.layer?.isOpaque = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        if let device = mtkView.device {
            context.coordinator.setup(device: device)
        }
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.updateState(weatherCode: weatherCode, timeOfDay: timeOfDay, style: style, variant: variant)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator (Renderer)
    class Coordinator: NSObject, MTKViewDelegate {
        var parent: MetalWeatherView
        var device: MTLDevice!
        var commandQueue: MTLCommandQueue!
        var pipelineState: MTLRenderPipelineState!
        var startTime: Date = Date()
        var currentWeatherCode: Int = 0
        var currentTimeOfDay: Int = 0
        var currentStyle: WeatherStyle = .realistic
        var currentVariant: Int = 0
        
        let vertexData: [Float] = [
            -1.0, -1.0, 0.0, 1.0,
             1.0, -1.0, 0.0, 1.0,
            -1.0,  1.0, 0.0, 1.0,
             1.0,  1.0, 0.0, 1.0
        ]
        var vertexBuffer: MTLBuffer!
        
        init(_ parent: MetalWeatherView) {
            self.parent = parent
            self.currentWeatherCode = parent.weatherCode
            self.currentTimeOfDay = parent.timeOfDay
            self.currentStyle = parent.style
            self.currentVariant = parent.variant
        }
        
        func setup(device: MTLDevice) {
            self.device = device
            self.commandQueue = device.makeCommandQueue()
            
            do {
                let library = try device.makeLibrary(source: mslShaderSource, options: nil)
                let vertexFunction = library.makeFunction(name: "vertex_main")
                let fragmentFunction = library.makeFunction(name: "weatherFragment")
                
                let pipelineDescriptor = MTLRenderPipelineDescriptor()
                pipelineDescriptor.vertexFunction = vertexFunction
                pipelineDescriptor.fragmentFunction = fragmentFunction
                pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
                
                pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
                pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
                pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
                pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
                pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
                pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
                pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
                
                pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
                
            } catch {
                print("Failed to compile Metal shaders: \(error)")
            }
            vertexBuffer = device.makeBuffer(bytes: vertexData, length: vertexData.count * 4, options: [])
        }
        
        func updateState(weatherCode: Int, timeOfDay: Int, style: WeatherStyle, variant: Int) {
            self.currentWeatherCode = weatherCode
            self.currentTimeOfDay = timeOfDay
            self.currentStyle = style
            self.currentVariant = variant
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let descriptor = view.currentRenderPassDescriptor,
                  let pipelineState = pipelineState else { return }
            
            let time = Float(Date().timeIntervalSince(startTime))
            let width = Float(view.drawableSize.width)
            let height = Float(view.drawableSize.height)
            
            var shaderCode: Int32 = 1
            switch currentWeatherCode {
            case 0: shaderCode = 0 // Sunny
            case 1...3: shaderCode = 1 // Cloudy
            case 45, 48: shaderCode = 2 // Fog
            case 51...65, 80...82, 95...99: shaderCode = 3 // Storm/Rain
            case 71...86: shaderCode = 1 // Snow (use cloudy)
            default: shaderCode = 1
            }
            
            var uniforms = WeatherUniforms(
                time: time,
                resolution: SIMD2<Float>(width, height),
                weatherCode: shaderCode,
                timeOfDay: Int32(currentTimeOfDay),
                style: Int32(currentStyle == .realistic ? 0 : 1),
                variant: Int32(currentVariant)
            )
            
            let commandBuffer = commandQueue.makeCommandBuffer()
            let encoder = commandBuffer?.makeRenderCommandEncoder(descriptor: descriptor)
            
            encoder?.setRenderPipelineState(pipelineState)
            encoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder?.setFragmentBytes(&uniforms, length: MemoryLayout<WeatherUniforms>.size, index: 0)
            encoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            
            encoder?.endEncoding()
            commandBuffer?.present(drawable)
            commandBuffer?.commit()
        }
    }
}

// MARK: - Embedded Metal Shader Source
let mslShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float time;
    float2 resolution;
    int weatherCode; // 0:Sunny, 1:Cloudy, 2:Overcast, 3:Storm
    int timeOfDay;   // 0:Day, 1:Sunset, 2:Night
    int style;       // 0:Realistic, 1:Glassmorphic
    int variant;     // 0:Cinematic, 1:Soft
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// MARK: - Vertex
vertex VertexOut vertex_main(const device float4 *vertices [[buffer(0)]], uint vertexID [[vertex_id]]) {
    VertexOut out;
    out.position = vertices[vertexID];
    out.uv = out.position.xy * 0.5 + 0.5;
    out.uv.y = 1.0 - out.uv.y; 
    return out;
}

// MARK: - Noise
float hash(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + float2(0.0, 0.0)), hash(i + float2(1.0, 0.0)), u.x),
               mix(hash(i + float2(0.0, 1.0)), hash(i + float2(1.0, 1.0)), u.x), u.y);
}
float fbm(float2 p) {
    float f = 0.0;
    float2x2 m = float2x2(1.6,  1.2, -1.2,  1.6);
    f  = 0.5000 * noise(p); p = m * p;
    f += 0.2500 * noise(p); p = m * p;
    f += 0.1250 * noise(p); p = m * p;
    f += 0.0625 * noise(p); p = m * p;
    return f;
}

// MARK: - Elements
float sun(float2 uv, float aspect, float radius, float blur) {
    float d = length(uv);
    return smoothstep(radius + blur, radius, d);
}

// Enhanced Volumetric-like cloud rendering with cinematic shading
float3 renderClouds(float2 uv, float time, float3 skyColor, float cloudDensity, float3 sunDir, float3 cloudColor, float3 shadowColor) {
    float2 q = uv;
    q.x += time * 0.02; 
    
    // Multi-layered complex noise for volumetric effect
    float f = fbm(q * 2.5);
    f += fbm(q * 5.0 + time * 0.01) * 0.5;
    float density = fbm(q * 1.5 - time * 0.005);
    f *= density * 1.2;
    
    // Calculate pseudo-normals for detail shading
    float2 eps = float2(0.02, 0.0);
    float f_x = fbm((q + eps.xy) * 2.5) - f;
    float f_y = fbm((q + eps.yx) * 2.5) - f;
    float3 normal = normalize(float3(f_x, f_y, 0.1));
    
    // Lighting model: Diffuse + Scattering + Silver Lining
    float diffuse = clamp(dot(normal, sunDir), 0.0, 1.0);
    // Silver lining effect near the sun
    float scattering = pow(max(0.0, dot(normalize(float3(uv, 1.0)), sunDir)), 12.0);
    
    float cover = smoothstep(0.35, 0.85, f + cloudDensity);
    
    // Ambient + Diffuse
    float3 col = mix(shadowColor, cloudColor, diffuse * 0.7 + 0.3);
    // Add rim lighting / scattering
    col += cloudColor * scattering * 1.2;
    
    // Micro-detail layer
    float detail = fbm(q * 12.0 + time * 0.06);
    col = mix(col, col * 1.15, detail * 0.4);
    
    return mix(skyColor, col, cover);
}

// Light scattering (God Rays)
float3 godRays(float2 uv, float2 sunPos, float time, float3 color) {
    float d = length(uv - sunPos);
    float angle = atan2(uv.y - sunPos.y, uv.x - sunPos.x);
    float rays = 0.0;
    rays += sin(angle * 12.0 + time * 0.45) * 0.5 + 0.5;
    rays *= sin(angle * 8.5 - time * 0.25) * 0.5 + 0.5;
    rays *= pow(max(0.0, 1.0 - d * 0.6), 5.0);
    return color * rays * 0.35;
}

float particles(float2 uv, float time, float speed, float size, float density) {
    float2 p = uv;
    p.y += time * speed;
    p.x += sin(p.y * 0.5 + time) * 0.1; 
    float2 grid = floor(p * density);
    float2 local = fract(p * density);
    float h = hash(grid);
    if (h > 0.9) {
        float d = length((local - 0.5) * float2(1.0, 1.0/size));
        return smoothstep(0.1, 0.0, d) * h;
    }
    return 0.0;
}

float lightning(float2 uv, float time) {
    float t = time * 2.1;
    float flash = sin(t) * sin(t * 3.7) * sin(t * 11.3);
    return smoothstep(0.985, 1.0, flash);
}

// Premium Heat Haze / Thermal Distortion
float2 applyHeatHaze(float2 uv, float time, float intensity) {
    float distortion = fbm(uv * 4.0 + time * 0.8);
    distortion += fbm(uv * 8.0 - time * 1.2) * 0.5;
    return uv + (distortion - 0.5) * intensity;
}

// Extra cinematic lens flare for direct sun (MEGA BOOST)
float3 lensFlare(float2 uv, float2 sunPos, float3 color) {
    float3 flare = float3(0.0);
    float2 mainDir = uv - sunPos;
    
    // Main Ghost 1 (Brighter)
    float d1 = length(uv - (sunPos - mainDir * 0.5));
    flare += color * smoothstep(0.25, 0.0, d1) * 0.4;
    
    // Main Ghost 2 (Larger)
    float d2 = length(uv - (sunPos + mainDir * 1.2));
    flare += color * 0.6 * smoothstep(0.15, 0.0, d2) * 0.3;
    
    // Rainbow ring effect
    float ring = smoothstep(0.5, 0.48, length(mainDir)) * smoothstep(0.45, 0.47, length(mainDir));
    flare += float3(0.1, 0.2, 0.5) * ring * 0.3;
    
    // Tiny bright specs (Sharper)
    float spec = pow(max(0.0, 1.0 - length(mainDir * 3.0)), 30.0);
    flare += color * spec * 1.5;
    
    return flare;
}

// MARK: - Fragment
fragment float4 weatherFragment(VertexOut in [[stage_in]], constant Uniforms &uniforms [[buffer(0)]]) {
    float2 rawUV = in.uv;
    float time = uniforms.time;
    int code = uniforms.weatherCode;
    int style = uniforms.style;
    int variant = uniforms.variant;
    
    // Apply Heat Haze distortion to UVs if it's Sunny/Clear
    float2 uv = (code == 0 && style == 0) ? applyHeatHaze(rawUV, time, 0.015) : rawUV;
    
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    float2 st = uv * 2.0 - 1.0;
    st.x *= aspect; st.y = -st.y;
    
    int timeOfDay = uniforms.timeOfDay;

    float3 col = float3(0.0);
    float3 sunDir = normalize(float3(0.5, 0.5, 1.0));
    
    // Refined High-End Palettes
    float3 skyTop, skyBot;
    float3 cloudBase, cloudShadow;
    
    if (timeOfDay == 2) { // Night
        skyTop = float3(0.01, 0.02, 0.08); 
        skyBot = float3(0.04, 0.08, 0.2);
        cloudBase = float3(0.4, 0.45, 0.6);
        cloudShadow = float3(0.04, 0.06, 0.12);
    } else if (timeOfDay == 1) { // Sunset
        skyTop = float3(0.1, 0.08, 0.25);
        skyBot = float3(1.0, 0.4, 0.2);
        cloudBase = float3(1.0, 0.7, 0.55); 
        cloudShadow = float3(0.3, 0.1, 0.2);
    } else { // Day
        skyTop = float3(0.05, 0.5, 1.0); // Deeper top
        skyBot = float3(0.6, 0.85, 1.0); // Brighter bottom
        cloudBase = float3(1.0, 1.0, 1.0);
        cloudShadow = float3(0.7, 0.8, 0.95);
    }

    if (style == 1) { // Glassmorphic Style (RESTORED DETAIL)
        col = mix(skyTop, skyBot, uv.y);
        
        if (code == 0) { // Sunny/Clear: Vibrant & Glowing
             float2 sunPos = st - float2(0.6 * aspect, 0.45);
             float sunGlow = smoothstep(1.3, 0.0, length(sunPos));
             col += float3(1.0, 0.8, 0.2) * sunGlow * 0.5;
             
             // Bokeh light leaks
             float2 p1 = st - float2(-0.4 + sin(time*0.2)*0.1, 0.2);
             float2 p2 = st - float2(0.3, -0.4 + cos(time*0.15)*0.2);
             col += float3(1.0, 0.9, 0.6) * smoothstep(1.0, 0.0, length(p1)) * 0.15;
             col += float3(1.0, 0.8, 0.7) * smoothstep(0.8, 0.0, length(p2)) * 0.12;
             
        } else if (code == 1) { // Cloudy: Multi-layered soft drift
             float2 p1 = st - float2(sin(time*0.3)*0.4 - 0.3, 0.4);
             float2 p2 = st - float2(cos(time*0.2)*0.3 + 0.4, 0.2);
             float2 p3 = st - float2(sin(time*0.1)*0.2, 0.6);
             col = mix(col, float3(1.0), smoothstep(1.2, 0.2, length(p1)) * 0.25);
             col = mix(col, float3(0.9, 0.95, 1.0), smoothstep(0.9, 0.0, length(p2)) * 0.2);
             col = mix(col, float3(0.95, 0.98, 1.0), smoothstep(0.7, 0.0, length(p3)) * 0.15);
             
        } else if (code == 2) { // Overcast/Fog: Heavy blur
             col *= 0.8;
             float2 p1 = st - float2(0.0, 0.3 + sin(time*0.1)*0.1);
             float f = fbm(st * 1.5 + time * 0.05);
             col = mix(col, float3(0.7, 0.75, 0.8), (smoothstep(1.8, 0.0, length(p1)) + f * 0.5) * 0.5);
             
        } else if (code == 3) { // Storm: Moody & Dynamic streaks
             col = mix(float3(0.05, 0.05, 0.15), float3(0.15, 0.1, 0.3), uv.y);
             float flash = lightning(uv, time);
             col += float3(0.7, 0.85, 1.0) * flash * 0.5;
             
             // Abstract Rain Streaks
             float rain = particles(st * float2(2.0, 0.05), time * 1.5, 4.0, 40.0, 30.0);
             col += float3(0.5, 0.7, 1.0) * rain * 0.25;
             
             float2 p1 = st - float2(0.0, 0.4);
             col = mix(col, float3(0.2, 0.2, 0.45), smoothstep(1.5, 0.0, length(p1)) * 0.4);
        }
        float grain = hash(uv + time) * 0.05;
        col += grain;
        
    } else { // Realistic Style (UPGRADED TO CINEMATIC)
        if (code == 0) { // Clear
            col = mix(skyTop, skyBot, uv.y);
            if (timeOfDay == 0) { // Sunny Day
                if (variant == 0) { // Variant A: ULTRA BLINDING CINEMATIC
                    float2 sunPos = float2(0.6 * aspect, 0.5);
                    float2 sunUV = st - sunPos;
                    
                    // 1. Intense Blinding Sun Core (MEGA BOOST)
                    float sunCore = sun(sunUV, aspect, 0.08, 0.01);
                    float sunSpike = pow(max(0.0, 1.0 - length(sunUV * 2.2)), 80.0) * 4.0;
                    float sunGlow = sun(sunUV, aspect, 1.2, 0.6);
                    
                    col += float3(1.0, 0.95, 0.7) * sunGlow * 1.0;
                    col += float3(1.0, 1.0, 1.0) * (sunCore * 2.0 + sunSpike);
                    
                    // 2. Extra Cinematic Lens Flare (NEW)
                    col += lensFlare(st, sunPos, float3(1.0, 0.9, 0.8));
                    
                    // 3. Sharper God Rays (BOOSTED)
                    col += godRays(st, sunPos, time, float3(1.0, 1.0, 0.9)) * 1.8;
                    
                    // 4. Atmospheric Glare
                    col = renderClouds(st, time, col, -0.45, sunDir, cloudBase, cloudShadow);
                    col += float3(0.2, 0.1, 0.0) * sunGlow * 0.5; // Direct glare tint
                } else if (variant == 1) { // Variant B: SOFT PEACEFUL DAY
                    float2 sunPos = float2(0.7 * aspect, 0.65);
                    float2 sunUV = st - sunPos;
                    
                    // 1. Softer Sun
                    float sunCore = sun(sunUV, aspect, 0.12, 0.05); // Larger, softer core
                    float sunGlow = sun(sunUV, aspect, 1.5, 0.8); // Wider, gentle glow
                    
                    col = mix(float3(0.1, 0.6, 1.0), float3(0.5, 0.8, 1.0), uv.y); // Fresher Blue Sky
                    col += float3(1.0, 0.98, 0.9) * sunGlow * 0.6;
                    col += float3(1.0, 1.0, 0.95) * sunCore * 1.2;
                    
                    // 2. No heavy lens flare, just gentle rays
                    col += godRays(st, sunPos, time * 0.5, float3(1.0, 1.0, 1.0)) * 0.8;
                    
                    // 3. Floating Dust/Pollen Particles (Peaceful)
                    float dust = particles(st, time * 0.2, 0.5, 0.8, 20.0);
                    col += float3(1.0, 1.0, 1.0) * dust * 0.3;
                    
                    // 4. Light wispy clouds
                    col = renderClouds(st, time * 0.5, col, -0.3, sunDir, float3(1.0), float3(0.9));
                    
                } else if (variant == 2) { // Variant C: GOLDEN WARMTH (New)
                    float2 sunPos = float2(0.4 * aspect, 0.55);
                    float2 sunUV = st - sunPos;
                    
                    // Warm Gradient
                    col = mix(float3(0.0, 0.4, 0.8), float3(0.8, 0.7, 0.5), uv.y); 
                    
                    // Golden Sun
                    float sunCore = sun(sunUV, aspect, 0.09, 0.02);
                    float sunGlow = sun(sunUV, aspect, 0.8, 0.4);
                    col += float3(1.0, 0.8, 0.4) * sunGlow * 0.8;
                    col += float3(1.0, 0.9, 0.6) * sunCore * 2.5; // Bright Gold
                    
                    // Golden Rays
                    col += godRays(st, sunPos, time * 0.8, float3(1.0, 0.8, 0.2)) * 1.5;
                    
                    // Warm Clouds
                    col = renderClouds(st, time * 0.7, col, -0.2, sunDir, float3(1.0, 0.95, 0.9), float3(0.8, 0.6, 0.5));
                    
                } else { // Variant D: CRISP HIGH NOON (New)
                    // High Center Sun
                    float2 sunPos = float2(0.5 * aspect, 0.8); 
                    float2 sunUV = st - sunPos;
                    
                    // Deep Azure Sky (High Contrast)
                    col = mix(float3(0.0, 0.3, 0.9), float3(0.4, 0.7, 1.0), uv.y);
                    
                    // Pure White Sharp Sun
                    float sunCore = sun(sunUV, aspect, 0.06, 0.005); // Sharp
                    float sunHalo = sun(sunUV, aspect, 0.4, 0.2);
                    
                    col += float3(1.0, 1.0, 1.0) * sunHalo * 0.4;
                    col += float3(1.0, 1.0, 1.0) * sunCore * 3.0; // Intense White
                    
                    // Minimal Rays, just clear air
                    col += godRays(st, sunPos, time * 0.3, float3(0.8, 0.9, 1.0)) * 0.5;
                    
                    // Minimal Clouds (Clear Day)
                    col = renderClouds(st, time * 0.3, col, -0.5, sunDir, float3(1.0), float3(0.9));
                }
                
            } else if (timeOfDay == 1) { // Sunset
                float2 sunPos = float2(0.0, -0.4);
                float2 sunUV = st - sunPos;
                float sunCore = sun(sunUV, aspect, 0.25, 0.1);
                col += float3(1.0, 0.5, 0.15) * sunCore;
                col += godRays(st, sunPos, time, float3(1.0, 0.35, 0.1));
                
                col = renderClouds(st, time, col, -0.15, sunDir, cloudBase, cloudShadow);
            } else { // Night
                float starField = particles(st, time * 0.04, 0.0, 0.7, 65.0);
                starField *= (0.4 + 0.6 * sin(time * 3.5 + hash(st * 100.0) * 6.28));
                col += float3(0.9, 0.95, 1.0) * starField;
                
                float2 moonPos = float2(0.5, 0.45);
                float moon = sun(st - moonPos, aspect, 0.09, 0.015);
                col += float3(0.85, 0.9, 1.0) * moon;
                col += godRays(st, moonPos, time * 0.2, float3(0.4, 0.5, 0.75)) * 0.25;
                
                col = renderClouds(st, time, col, -0.25, sunDir, cloudBase, cloudShadow);
            }
        } else if (code == 1) { // Cloudy
            if (variant == 0) { // Variant A: Balanced (Original)
                col = mix(skyTop * 0.85, skyBot * 0.85, uv.y);
                col = renderClouds(st, time, col, 0.2, sunDir, cloudBase, cloudShadow);
            } else if (variant == 1) { // Variant B: Rolling Cumulus (Thicker, Lower)
                col = mix(skyTop * 0.75, skyBot * 0.9, uv.y); // More contrast in sky
                // Higher density (0.4), faster time (time * 1.2)
                col = renderClouds(st, time * 1.2, col, 0.45, sunDir, cloudBase * 0.95, cloudShadow * 0.9);
            } else { // Variant C: Wispy Cirrus (Light, High)
                col = mix(skyTop * 0.95, skyBot * 1.05, uv.y); // Brighter, airier sky
                // Negative density for wispy strings, slow time (time * 0.6)
                col = renderClouds(st, time * 0.6, col, -0.1, sunDir, cloudBase * 1.1, cloudShadow * 1.05);
            }
        } else if (code == 2) { // Overcast/Fog
            col = mix(skyTop * 0.6, skyBot * 0.6, uv.y);
            col = renderClouds(st, time, col, 0.5, sunDir, cloudBase * 0.85, cloudShadow * 0.9);
        } else if (code == 3) { // Storm/Rain
             if (variant == 0) { // Variant A: Thunderstorm (Original)
                 col = mix(float3(0.05, 0.05, 0.15), float3(0.15, 0.1, 0.3), uv.y); 
                 float flash = lightning(uv, time);
                 col += float3(0.85, 0.9, 1.0) * flash * 0.5;
                 col = renderClouds(st, time * 1.6, col, 0.4, sunDir, cloudBase * 0.45, cloudShadow * 0.4);
                 float rain = particles(st * float2(1.0, 0.1), time, 6.0, 15.0, 50.0);
                 col += float3(0.6, 0.75, 1.0) * rain * 0.45;
                 
             } else if (variant == 1) { // Variant B: Light Drizzle (New)
                 col = mix(float3(0.3, 0.35, 0.45), float3(0.5, 0.55, 0.65), uv.y); // Brighter Gloom
                 // Soft clouds
                 col = renderClouds(st, time * 0.8, col, 0.3, sunDir, float3(0.6), float3(0.5));
                 // Gentle rain: slower, smaller
                 float rain = particles(st * float2(1.5, 0.08), time, 4.0, 25.0, 20.0);
                 col += float3(0.7, 0.8, 0.9) * rain * 0.3;
                 
             } else { // Variant C: Heavy Monsoon (New)
                 col = mix(float3(0.02, 0.03, 0.05), float3(0.1, 0.12, 0.15), uv.y); // Deep Dark
                 // Fast turbulent clouds
                 col = renderClouds(st, time * 2.5, col, 0.5, sunDir, float3(0.2), float3(0.1));
                 
                 // Heavy Rain with Wind Slant
                 float2 windUV = st;
                 windUV.x += windUV.y * 0.2; // Slant
                 float rain = particles(windUV * float2(0.8, 0.05), time, 9.0, 10.0, 80.0); // Fast, Dense
                 col += float3(0.5, 0.6, 0.7) * rain * 0.5;
             }
        }
    }

    col = smoothstep(0.0, 1.0, col);
    float vig = 1.0 - length(in.uv - 0.5) * 0.35;
    col *= vig;
    
    return float4(col, 1.0);
}
"""
