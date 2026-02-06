shader_type canvas_item;

// --- 參數設定 ---

// 背景色：建議純黑，Alpha 值調低 (0.6 ~ 0.8) 以保持通透感
uniform vec4 base_color : source_color = vec4(0.0, 0.0, 0.0, 0.7);

// 掃描線顏色：建議微亮的灰白色，Alpha 很低 (0.05 ~ 0.1) 避免喧賓奪主
uniform vec4 scan_line_color : source_color = vec4(1.0, 1.0, 1.0, 0.1);

// 邊緣淡出強度：數值越大，兩側消失得越快
uniform float fade_power : hint_range(1.0, 10.0) = 3.0;

// 掃描線密度：數值越大，線條越密
uniform float line_count : hint_range(50.0, 500.0) = 200.0;

// 掃描線速度：正數向下，負數向上
uniform float line_speed : hint_range(-5.0, 5.0) = 0.5;

// 數位閃爍強度：模擬老舊顯示器的微幅閃爍 (0.0 為關閉)
uniform float flicker_strength : hint_range(0.0, 0.1) = 0.02;

void fragment() {
    // 1. 計算水平漸層遮罩 (讓左右兩側消失)
    float dist_x = abs(UV.x - 0.5);
    float mask = 1.0 - (dist_x * 2.0);
    mask = pow(max(mask, 0.0), fade_power);

    // 2. 製作移動的數位掃描線 (Sine Wave)
    // 使用 UV.y 產生橫條紋，加上 TIME 讓它移動
    float scan_pattern = sin(UV.y * line_count - TIME * line_speed);
    // 將 Sine 波轉為較銳利的線條感，並限制範圍 (0~1)
    scan_pattern = 0.5 + 0.5 * scan_pattern;

    // 3. 製作微幅閃爍 (Flicker)
    float flicker = sin(TIME * 20.0) * flicker_strength;

    // 4. 合成顏色
    // 基底顏色 + 掃描線顏色 (掃描線只在 mask 強度高的地方顯示)
    vec3 final_rgb = base_color.rgb + (scan_line_color.rgb * scan_pattern * 0.5);
    // 加上閃爍
    final_rgb += flicker;

    // 5. 輸出
    vec4 final_color = vec4(final_rgb, base_color.a);

    // 將漸層遮罩應用到透明度
    final_color.a *= mask;

    COLOR = final_color;
}