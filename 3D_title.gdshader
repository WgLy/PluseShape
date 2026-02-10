shader_type canvas_item;

// 這些參數就是我們要用 GDScript 控制的
uniform float fov : hint_range(1, 179) = 90;
uniform float y_rot : hint_range(-180, 180) = 0.0; // Y軸旋轉 (左右轉)
uniform float x_rot : hint_range(-180, 180) = 0.0; // X軸旋轉 (上下轉)
uniform float inset : hint_range(0, 1) = 0.0; // 內縮程度 (輔助透視)

// 這是 2D 模擬 3D 透視的核心數學
varying flat vec2 v_uv_offset;
varying flat vec2 v_uv_scale;

void vertex() {
	float sin_y = sin(y_rot * 3.14159 / 180.0);
	float cos_y = cos(y_rot * 3.14159 / 180.0);
	float sin_x = sin(x_rot * 3.14159 / 180.0);
	float cos_x = cos(x_rot * 3.14159 / 180.0);

	// 簡單的頂點變換矩陣
	mat3 m = mat3(
		vec3(cos_y, sin_x * sin_y, cos_x * sin_y),
		vec3(0.0,   cos_x,         -sin_x),
		vec3(-sin_y, sin_x * cos_y, cos_x * cos_y)
	);

	float t = tan(fov * 3.14159 / 360.0);
	vec2 uv = (UV - 0.5);
	vec3 p = m * vec3(uv, 0.0);
	float d = (0.5 - inset) / t;

	// 應用透視除法
	VERTEX = p.xy * d / (d - p.z);
	VERTEX += 0.5; // 回復中心點
	VERTEX *= (1.0 / TEXTURE_PIXEL_SIZE); // 轉回像素座標
}