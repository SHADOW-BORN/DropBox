shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, depth_test_disabled, shadows_disabled, ambient_light_disabled;
render_mode blend_mix, alpha_to_coverage;

// Shader uniforms - you can adjust these in the Godot editor
uniform float glow_intensity: hint_range(0.1, 5.0) = 2.0;
uniform float edge_thickness: hint_range(0.1, 2.0) = 0.8;
uniform float wave_speed: hint_range(0.1, 5.0) = 2.0;
uniform float wave_amplitude: hint_range(0.0, 1.0) = 0.3;
uniform float wave_frequency: hint_range(1.0, 20.0) = 8.0;
uniform float surface_distortion: hint_range(0.0, 2.0) = 1.0;
uniform vec4 glow_color : source_color = vec4(0.0, 1.0, 0.5, 1.0);
uniform float transparency: hint_range(0.0, 1.0) = 0.8;

varying vec3 world_pos;

void vertex() {
    world_pos = VERTEX;
    
    // Multiple wave layers for water-like effect
    float time = TIME * wave_speed;
    
    // Primary wave
    float wave1 = sin(time + VERTEX.x * wave_frequency) * wave_amplitude;
    wave1 += cos(time * 0.8 + VERTEX.z * wave_frequency * 0.7) * wave_amplitude * 0.7;
    
    // Secondary wave (different direction)
    float wave2 = sin(time * 1.3 + (VERTEX.x + VERTEX.z) * wave_frequency * 0.5) * wave_amplitude * 0.5;
    wave2 += cos(time * 0.6 + (VERTEX.x - VERTEX.z) * wave_frequency * 0.8) * wave_amplitude * 0.3;
    
    // Tertiary wave (high frequency ripples)
    float wave3 = sin(time * 2.1 + VERTEX.x * wave_frequency * 2.0) * wave_amplitude * 0.2;
    wave3 += cos(time * 1.7 + VERTEX.z * wave_frequency * 1.5) * wave_amplitude * 0.15;
    
    // Apply waves to all axes for more organic movement
    VERTEX.x += wave1 * 0.3 + wave2 * 0.2;
    VERTEX.y += wave1 + wave2 + wave3;
    VERTEX.z += wave1 * 0.2 + wave2 * 0.4;
    
    // Calculate moving normal for surface distortion
    vec3 wave_normal = normalize(vec3(
        cos(time + world_pos.x * wave_frequency) * wave_frequency,
        1.0,
        cos(time + world_pos.z * wave_frequency) * wave_frequency
    ));
    NORMAL = mix(NORMAL, wave_normal, 0.3);
}

void fragment() {
    // Create animated surface distortion using UV coordinates
    float time = TIME * wave_speed;
    
    // Multiple layers of UV distortion for water-like surface
    vec2 distorted_uv = UV;
    distorted_uv.x += sin(time * 1.5 + UV.y * wave_frequency * 3.0) * surface_distortion * 0.05;
    distorted_uv.y += cos(time * 1.2 + UV.x * wave_frequency * 2.5) * surface_distortion * 0.05;
    
    distorted_uv.x += sin(time * 2.3 + UV.y * wave_frequency * 5.0) * surface_distortion * 0.02;
    distorted_uv.y += cos(time * 1.8 + UV.x * wave_frequency * 4.0) * surface_distortion * 0.02;
    
    // Enhanced fresnel effect with surface distortion
    vec3 normal = normalize(NORMAL);
    vec3 view = normalize(VIEW);
    float base_fresnel = 1.0 - abs(dot(normal, view));
    
    // Add animated fresnel variation
    float animated_fresnel = base_fresnel;
    animated_fresnel += sin(time + world_pos.x * 3.0) * 0.1;
    animated_fresnel += cos(time * 1.3 + world_pos.z * 2.5) * 0.08;
    
    // Dynamic edge detection with distorted UV
    vec2 edge_uv = abs(distorted_uv - 0.5) * 2.0;
    float edge_factor = max(edge_uv.x, edge_uv.y);
    
    // Combine effects for watery edge glow
    float edge_alpha = max(animated_fresnel, 1.0 - smoothstep(0.6, 1.0, edge_factor));
    edge_alpha = pow(edge_alpha, edge_thickness);
    
    // Multiple layers of animated noise for water-like disturbance
    float noise = sin(time * 2.0 + world_pos.x * 4.0 + world_pos.z * 3.0) * 0.15;
    noise += cos(time * 1.5 + world_pos.x * 6.0 - world_pos.z * 2.0) * 0.1;
    noise += sin(time * 3.0 + world_pos.y * 8.0) * 0.05;
    
    edge_alpha += noise * 0.3;
    edge_alpha = clamp(edge_alpha, 0.0, 1.0);
    
    // Enhanced glow with pulsing effect
    float pulse = sin(time * 1.5) * 0.3 + 0.7;
    float glow = edge_alpha * glow_intensity * pulse;
    
    vec3 final_color = glow_color.rgb * glow;
    float final_alpha = edge_alpha * transparency;
    
    // Add some internal shimmer
    float shimmer = sin(time * 4.0 + distorted_uv.x * 10.0) * 0.1;
    shimmer += cos(time * 3.2 + distorted_uv.y * 8.0) * 0.05;
    final_color += glow_color.rgb * shimmer * 0.2;
    
    ALBEDO = final_color;
    ALPHA = final_alpha;
    EMISSION = final_color * glow_intensity * pulse;
}