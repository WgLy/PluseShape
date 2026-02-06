shader_type canvas_item;

// --- 參數設定 ---

// 圖片色調：建議純白，保留亮度。
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// 【新增】彩度控制：0.0 為全黑白，1.0 為全彩，建議 0.1 ~ 0.3 之間
uniform float saturation : hint_range(0.0, 1.0) = 0.2;

// 掃描線顏色：Alpha 很低 (例如 0.05 ~ 0.1)
uniform vec4 scan_line_color : source_color = vec4(0.5, 0.5, 0.5, 0.05);

// 掃描線密度
uniform float line_count : hint_range(50.0, 500.0) = 100.0;
// 掃描線速度
uniform float line_speed : hint_range(-5.0, 5.0) = 3.0;

// 【新增】掃描線銳利度 (控制粗細)：數值越大，線條越細越清楚
uniform float line_sharpness : hint_range(1.0, 20.0) = 2.0;

// 數位閃爍強度
uniform float flicker_strength : hint_range(0.0, 0.1) = 0.01;

// 圖片邊緣柔和度
uniform float edge_softness : hint_range(0.0, 0.5) = 0.1;

void fragment() {
    // 1. 讀取原始圖片顏色
    vec4 tex_color = texture(TEXTURE, UV);
    
    // 2. 【修改】計算彩度 (降低彩度，而非直接黑白)
    // 計算灰階值 (亮度)
    float grayscale = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
    vec3 gray_rgb = vec3(grayscale);
    // 使用 mix 在 "灰階色" 和 "原始色" 之間混合，saturation 決定混合比例
    vec3 final_rgb = mix(gray_rgb, tex_color.rgb, saturation);
    
    // 3. 應用色調染料 (Tint)
    final_rgb *= tint_color.rgb;
    
    // 4. 【修改】製作更細的數位掃描線
    // 原始的正弦波 (-1 到 1)
    float raw_sine = sin(UV.y * line_count - TIME * line_speed);
    // 轉為 0 到 1 的範圍
    float normalized_sine = 0.5 + 0.5 * raw_sine;
    // 【關鍵】使用次方運算 (pow) 來讓波峰變窄，線條就會變細
    // line_sharpness 越大，線條越細
    float scan_pattern = pow(normalized_sine, line_sharpness);
    
    // 5. 製作微幅閃爍
    float flicker = sin(TIME * 20.0) * flicker_strength;
    
    // 6. 合成效果
    // 將掃描線疊加在圖片上 (只在圖片有不透明度的地方疊加)
    final_rgb += (scan_line_color.rgb * scan_pattern * tex_color.a);
    final_rgb += flicker * tex_color.a;
    
    // 7. 邊緣柔和處理
    float soft_alpha = smoothstep(0.0, edge_softness, tex_color.a);
    
    // 8. 輸出最終顏色
    COLOR = vec4(final_rgb, soft_alpha * tint_color.a);
}