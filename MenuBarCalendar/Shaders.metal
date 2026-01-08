#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float time;
    float2 resolution;
    int weatherCode; // 0:Sunny, 1:Cloudy, 2:Overcast, 3:Storm, 4:Sunset, 5:Night
};

// MARK: - Noise Functions
float hash(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// 2D Noise
float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + float2(0.0, 0.0)), hash(i + float2(1.0, 0.0)), u.x),
               mix(hash(i + float2(0.0, 1.0)), hash(i + float2(1.0, 1.0)), u.x), u.y);
}

// FBM (Fractal Brownian Motion) for clouds
float fbm(float2 p) {
    float f = 0.0;
    float2x2 m = float2x2(1.6,  1.2, -1.2,  1.6);
    f  = 0.5000 * noise(p); p = m * p;
    f += 0.2500 * noise(p); p = m * p;
    f += 0.1250 * noise(p); p = m * p;
    f += 0.0625 * noise(p); p = m * p;
    return f;
}

// MARK: - Weather Elements

// Rain/Snow Particles
float particles(float2 uv, float time, float speed, float size, float density) {
    float2 p = uv;
    p.y += time * speed;
    p.x += sin(p.y * 0.5 + time) * 0.1; // slight wind
    
    float2 grid = floor(p * density);
    float2 local = fract(p * density);
    
    float h = hash(grid);
    if (h > 0.9) { // random raindrop existence
        float d = length((local - 0.5) * float2(1.0, 1.0/size));
        return smoothstep(0.1, 0.0, d) * h;
    }
    return 0.0;
}

// Sun/Moon
float sun(float2 uv, float aspect, float radius, float blur) {
    float d = length(uv);
    return smoothstep(radius + blur, radius, d);
}

// Clouds Rendering
float3 renderClouds(float2 uv, float time, float3 skyColor, float cloudDensity, float3 sunDir) {
    float2 q = uv;
    q.x += time * 0.05; // cloud movement
    
    // Multi-layer FBM
    float f = fbm(q * 3.0);
    
    // Fake 3D Lighting
    // Calculate normal from noise derivative
    float2 eps = float2(0.01, 0.0);
    float nx = fbm((q + eps.xy) * 3.0) - f;
    float ny = fbm((q + eps.yx) * 3.0) - f;
    float3 normal = normalize(float3(nx, ny, 1.0));
    
    // Light calculation
    float diffuse = max(0.0, dot(normal, sunDir));
    float rim = pow(1.0 - normal.z, 3.0); // Silver lining
    
    // Cloud Shape Mask
    float cover = smoothstep(0.4, 0.8, f + cloudDensity);
    
    // Color composition
    float3 cloudBase = float3(0.9, 0.95, 1.0); // white/greyish
    float3 cloudShadow = float3(0.7, 0.75, 0.85); // shadow color
    
    float3 col = mix(cloudShadow, cloudBase, diffuse * 0.8 + 0.2);
    col += vector_float3(1.0) * rim * 0.5; // add rim light
    
    return mix(skyColor, col, cover);
}

// Lightning
float lightning(float2 uv, float time) {
    float t = time * 2.0;
    float flash = sin(t) * sin(t * 3.7) * sin(t * 11.3); // chaotic flash
    return smoothstep(0.95, 1.0, flash);
}

// MARK: - Main Fragment Shader
fragment float4 weatherFragment(
    float4 position [[position]],
    constant Uniforms &uniforms [[buffer(0)]]
) {
    // Coordinate Setup
    float2 uv = position.xy / uniforms.resolution.xy;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    float2 st = uv * 2.0 - 1.0;
    st.x *= aspect; // Aspect correction
    
    float time = uniforms.time;
    int code = uniforms.weatherCode;
    
    float3 col = float3(0.0);
    float3 sunDir = normalize(float3(0.5, 0.5, 1.0)); // Fake 3D Light Direction
    
    // Background Gradients
    if (code == 0) { // Sunny
        col = mix(float3(0.4, 0.7, 1.0), float3(0.1, 0.5, 0.9), uv.y); // Blue Sky
        
        // Sun
        float2 sunPos = st - float2(0.6, 0.5);
        float sunCore = sun(sunPos, aspect, 0.15, 0.05);
        float sunGlow = sun(sunPos, aspect, 0.4, 0.4);
        
        col += float3(1.0, 0.9, 0.6) * sunGlow * 0.5;
        col += float3(1.0, 1.0, 0.8) * sunCore;
        
        // Sparse Clouds
        col = renderClouds(st, time, col, 0.0, sunDir);
        
    } else if (code == 1) { // Cloudy
        col = mix(float3(0.3, 0.4, 0.6), float3(0.5, 0.6, 0.7), uv.y); // Greyish Blue
        col = renderClouds(st, time, col, 0.2, sunDir);
        
    } else if (code == 2) { // Overcast/Fog
        col = mix(float3(0.4, 0.45, 0.5), float3(0.6, 0.62, 0.65), uv.y); // Grey
        col = renderClouds(st, time, col, 0.5, sunDir);
        
    } else if (code == 3) { // Storm
        col = mix(float3(0.1, 0.12, 0.2), float3(0.15, 0.18, 0.25), uv.y); // Dark Stormy
        
        // Lightning Flash
        float flash = lightning(uv, time);
        col += float3(0.8, 0.9, 1.0) * flash * 0.3;
        
        // Heavy Dark Clouds
        col = renderClouds(st, time * 2.0, col, 0.4, float3(0.2, 0.8, 0.5));
        
        // Rain
        float rain = particles(st * float2(1.0, 0.1), time, 5.0, 20.0, 40.0);
        col += float3(0.7, 0.8, 1.0) * rain * 0.5;
        
    } else if (code == 4) { // Sunset
        col = mix(float3(0.2, 0.1, 0.4), float3(1.0, 0.5, 0.2), uv.y); // Purple to Orange
        
        // Sun on horizon
        float2 sunPos = st - float2(0.0, -0.3);
        float sunCore = sun(sunPos, aspect, 0.2, 0.1);
        col += float3(1.0, 0.6, 0.2) * sunCore;
        
        // Golden Clouds
        // Tint light source yellow/orange
        col = renderClouds(st, time * 0.5, col, 0.1, normalize(float3(-0.5, 0.2, 1.0)));
        
    } else if (code == 5) { // Night
        col = mix(float3(0.02, 0.02, 0.1), float3(0.05, 0.08, 0.2), uv.y); // Deep Blue
        
        // Stars
        float starField = particles(st, time * 0.05, 0.0, 1.0, 50.0);
        
        // Twinkle
        starField *= (0.5 + 0.5 * sin(time * 5.0 + st.x * 10.0));
        col += float3(1.0) * starField;
        
        // Moon
        float2 moonPos = st - float2(0.5, 0.4);
        float moon = sun(moonPos, aspect, 0.12, 0.01);
        // Moon Crater (simplified)
        float crater = fbm(moonPos * 10.0);
        moon *= (0.8 + 0.2 * crater);
        
        col += float3(0.95, 0.95, 1.0) * moon;
        
        // Thin Clouds
        col = renderClouds(st, time * 0.5, col, -0.1, sunDir);
    }
    
    // Rain/Snow Overlay for any rainy codes if mixed (simplified here to just Storm, but can be expanded)
    // You can add checking for specific rainy codes (like 51-65) here if passed separately or handled in `code`.
    
    // Tone Mapping (ACES-like)
    // col = col / (col + 0.15); // Simple reinhard-ish
    col = smoothstep(0.0, 1.0, col); // Contrast boost
    
    // Vignette
    float vig = 1.0 - length(uv - 0.5) * 0.5;
    col *= vig;
    
    return float4(col, 1.0);
}
