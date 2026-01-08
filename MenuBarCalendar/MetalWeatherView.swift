import SwiftUI
import MetalKit
import simd

// MARK: - Metal Types
struct WeatherUniforms {
    var time: Float              // Offset 0
    var _pad1: Float = 0         // Offset 4
    var resolution: SIMD2<Float> // Offset 8 (Align 8)
    var weatherCode: Int32       // Offset 16
    var timeOfDay: Int32         // Offset 20 (0:Day, 1:Sunset, 2:Night)
    // 24 bytes total
}

// MARK: - Metal Weather View Representable
struct MetalWeatherView: NSViewRepresentable {
    let weatherCode: Int
    let timeOfDay: Int // Pass logic from parent
    
    // Default int for generic usage, but parent should ideally control this
    init(weatherCode: Int, timeOfDay: Int = 0) {
        self.weatherCode = weatherCode
        self.timeOfDay = timeOfDay
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
        context.coordinator.updateState(weatherCode: weatherCode, timeOfDay: timeOfDay)
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
        
        func updateState(weatherCode: Int, timeOfDay: Int) {
            self.currentWeatherCode = weatherCode
            self.currentTimeOfDay = timeOfDay
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
                timeOfDay: Int32(currentTimeOfDay)
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
float sun(float2 uv, float aspect, float radius, float blur) {
    float d = length(uv);
    return smoothstep(radius + blur, radius, d);
}
float3 renderClouds(float2 uv, float time, float3 skyColor, float cloudDensity, float3 sunDir, float3 cloudColor, float3 shadowColor) {
    float2 q = uv;
    q.x += time * 0.03; 
    float f = fbm(q * 3.0);
    float2 eps = float2(0.01, 0.0);
    float nx = fbm((q + eps.xy) * 3.0) - f;
    float ny = fbm((q + eps.yx) * 3.0) - f;
    float3 normal = normalize(float3(nx, ny, 1.0));
    float diffuse = max(0.0, dot(normal, sunDir));
    float rim = pow(1.0 - normal.z, 3.0);
    float cover = smoothstep(0.4, 0.8, f + cloudDensity);
    
    float3 col = mix(shadowColor, cloudColor, diffuse * 0.8 + 0.2);
    // Add rim lighting
    col += vector_float3(0.8, 0.8, 1.0) * rim * 0.6; // Blueish rim for night clouds
    
    return mix(skyColor, col, cover);
}
float lightning(float2 uv, float time) {
    float t = time * 2.0;
    float flash = sin(t) * sin(t * 3.7) * sin(t * 11.3);
    return smoothstep(0.98, 1.0, flash);
}

// MARK: - Fragment
fragment float4 weatherFragment(VertexOut in [[stage_in]], constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.uv;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    float2 st = uv * 2.0 - 1.0;
    st.x *= aspect; st.y = -st.y;
    
    float time = uniforms.time;
    int code = uniforms.weatherCode;
    int timeOfDay = uniforms.timeOfDay;
    
    float3 col = float3(0.0);
    float3 sunDir = normalize(float3(0.5, 0.5, 1.0));
    
    // Define Palettes
    float3 skyTop, skyBot;
    float3 cloudBase, cloudShadow;
    
    if (timeOfDay == 2) { // Night
        skyTop = float3(0.02, 0.03, 0.1);  // Slightly lighter dark blue
        skyBot = float3(0.08, 0.12, 0.25); // Lighter gradient bottom
        
        // Fix: Make clouds lighter and more blue-greyish, not black
        cloudBase = float3(0.5, 0.55, 0.65); // Moonlit cloud distinct grey
        cloudShadow = float3(0.15, 0.18, 0.25); // Dark blue-ish shadow
        
    } else if (timeOfDay == 1) { // Sunset
        skyTop = float3(0.15, 0.1, 0.35);
        skyBot = float3(1.0, 0.5, 0.2);
        cloudBase = float3(1.0, 0.8, 0.7); 
        cloudShadow = float3(0.4, 0.25, 0.35);
    } else { // Day
        skyTop = float3(0.2, 0.5, 0.9);
        skyBot = float3(0.5, 0.7, 1.0);
        cloudBase = float3(0.98, 0.98, 1.0);
        cloudShadow = float3(0.65, 0.7, 0.8);
    }

    if (code == 0) { // Clear
        col = mix(skyTop, skyBot, uv.y);
        if (timeOfDay == 0) { // Sunny
            float2 sunPos = st - float2(0.6, 0.5);
            float sunCore = sun(sunPos, aspect, 0.15, 0.05);
            float sunGlow = sun(sunPos, aspect, 0.5, 0.5);
            col += float3(1.0, 0.9, 0.6) * sunGlow * 0.6;
            col += float3(1.0, 1.0, 0.9) * sunCore;
            col = renderClouds(st, time, col, -0.4, sunDir, cloudBase, cloudShadow);
        } else if (timeOfDay == 1) { // Sunset
            float2 sunPos = st - float2(0.0, -0.3);
            float sunCore = sun(sunPos, aspect, 0.2, 0.1);
            col += float3(1.0, 0.6, 0.2) * sunCore;
            col = renderClouds(st, time, col, -0.1, sunDir, cloudBase, cloudShadow);
        } else { // Night
            float starField = particles(st, time * 0.05, 0.0, 1.0, 50.0);
            starField *= (0.5 + 0.5 * sin(time * 5.0 + st.x * 10.0));
            col += float3(1.0) * starField;
            
            float2 moonPos = st - float2(0.5, 0.4);
            float moon = sun(moonPos, aspect, 0.12, 0.01);
            float crater = fbm(moonPos * 10.0);
            moon *= (0.9 + 0.1 * crater);
            col += float3(0.9, 0.95, 1.0) * moon;
            // Night Clouds
            col = renderClouds(st, time, col, -0.2, sunDir, cloudBase, cloudShadow);
        }
    } else if (code == 1) { // Cloudy
        col = mix(skyTop * 0.9, skyBot * 0.9, uv.y);
        col = renderClouds(st, time, col, 0.3, sunDir, cloudBase, cloudShadow);
        if (timeOfDay == 2) {
             float starField = particles(st, time * 0.05, 0.0, 1.0, 50.0);
             col += float3(1.0) * starField * 0.2; // Faint stars behind clouds
        }
    } else if (code == 2) { // Overcast/Fog
        col = mix(skyTop * 0.7, skyBot * 0.7, uv.y);
        col = renderClouds(st, time, col, 0.6, sunDir, cloudBase, cloudShadow);
    } else if (code == 3) { // Storm
         col = mix(float3(0.05), float3(0.1, 0.1, 0.15), uv.y); 
         float flash = lightning(uv, time);
         col += float3(0.8, 0.9, 1.0) * flash * 0.4;
         col = renderClouds(st, time * 2.0, col, 0.5, sunDir, cloudBase * 0.5, cloudShadow * 0.5);
         float rain = particles(st * float2(1.0, 0.1), time, 5.0, 20.0, 40.0);
         col += float3(0.7, 0.8, 1.0) * rain * 0.4;
    }

    col = smoothstep(0.0, 1.0, col);
    // Reduced vignette intensity for better visibility
    float vig = 1.0 - length(in.uv - 0.5) * 0.4;
    col *= vig;
    
    return float4(col, 1.0);
}
"""
