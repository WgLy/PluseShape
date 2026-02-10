extends Node2D

@onready var logo = $LogoSprite

# --- 基礎設定 ---
# 設定一個看起來像「貼在左牆」的角度
# Y 軸轉 -45 度通常就像貼在左邊
var base_y_rot = -45.0 
var base_x_rot = 0.0

# 互動強度
var mouse_sensitivity = 15.0 # 滑鼠移動會造成多少度數的額外旋轉
var smooth_speed = 5.0

func _process(delta):
	# 1. 取得滑鼠偏移 (-0.5 ~ 0.5)
	var viewport_size = get_viewport_rect().size
	var mouse_pos = get_viewport().get_mouse_position()
	var offset = (mouse_pos / viewport_size) - Vector2(0.5, 0.5)
	
	# 2. 計算目標角度
	# 當滑鼠往右 (offset.x > 0)，我們希望 Logo 轉回來一點面對玩家 (角度變小)
	var target_y = base_y_rot + (offset.x * mouse_sensitivity)
	
	# 當滑鼠上下移動，做一點點 X 軸傾斜，增加立體感
	var target_x = base_x_rot + (-offset.y * mouse_sensitivity)
	
	# 3. 獲取當前 Shader 參數值
	var mat = logo.material as ShaderMaterial
	var current_y = mat.get_shader_parameter("y_rot")
	var current_x = mat.get_shader_parameter("x_rot")
	
	# 4. 平滑移動 (Lerp)
	var new_y = lerp(current_y, target_y, delta * smooth_speed)
	var new_x = lerp(current_x, target_x, delta * smooth_speed)
	
	# 5. 寫回 Shader
	mat.set_shader_parameter("y_rot", new_y)
	mat.set_shader_parameter("x_rot", new_x)

# 額外功能：如果你想要用 Tween 做入場動畫
func play_intro_animation():
	var mat = logo.material as ShaderMaterial
	
	# 從完全側面 (-90度，看不見) 轉到貼牆角度 (-45度)
	mat.set_shader_parameter("y_rot", -90.0)
	
	var tween = create_tween()
	tween.tween_method(
		func(val): mat.set_shader_parameter("y_rot", val), # 設定函式
		-90.0,        # 起始值
		base_y_rot,   # 結束值
		1.5           # 時間
	).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
