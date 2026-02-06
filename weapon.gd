extends Node2D

@onready var player = $".."
# 1. 載入聲納場景 (記得確認路徑對不對)
var sonar_scene = preload("res://sonar_pulse.tscn")
var hitEffect = preload("res://hit_effect.tscn")

func _process(delta):
	if not $AnimationPlayer.is_playing():
		look_at(get_global_mouse_position())
	
	# --- 新增這段檢查 ---
	# 取得父節點 (Player)
	var player = get_parent()
	
	# 如果父節點存在，且它手上有拿石頭 (current_held_rock 不為空)
	# "current_held_rock" 是我們剛剛在 player.gd 裡定義的變數
	if player and "current_held_rock" in player and player.current_held_rock != null:
		return # 直接結束，不執行下面的揮劍邏輯
	# ------------------
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not $AnimationPlayer.is_playing() and player.can_attack_ability:
			attack()

func attack():
	# 播放揮劍動畫
	$AnimationPlayer.play("attack")
	
	# 生成微弱聲納
	spawn_weak_pulse()
	player.current_hp -= 1
	player.emit_signal("hp_changed", player.current_hp)

func spawn_weak_pulse():
	var pulse = sonar_scene.instantiate()
	
	# 設定位置：在武器(玩家)的位置
	pulse.global_position = $SoundOrigin.global_position
	
	# --- 客製化這個聲納 ---
	# 1. 範圍小一點 (揮劍聲音傳不遠)
	pulse.max_scale = 2.5 
	# 2. 擴散快一點 (聲音短促)
	pulse.expand_speed = 5.0
	# 3. 顏色設定為「淺白色/灰色」 (區分於主動聲納的青色)
	pulse.color = Color(0.8, 0.8, 0.8, 0.9) 
	# 4. 能量(亮度)低一點
	pulse.energy = 0.8
	
	# 加到世界中
	get_tree().root.add_child(pulse)

func _on_area_2d_body_entered(body):
	if body.is_in_group("enemies") or body.is_in_group("DestructiableObjects"):
		if body.has_method("take_damage"):
			body.take_damage(10, global_position)
			play_hitEffect( (global_position+body.global_position)/2 )
			


func _on_area_2d_body_exited(body: Node2D) -> void:
	pass # Replace with function body.


func hit_stop(duration: float):
	# 1. 將時間流速變為極慢 (例如原本的 5%)
	# 為什麼不設為 0？因為設為 0 有時會導致 divide_by_zero 的物理錯誤，0.05 效果幾乎一樣
	Engine.time_scale = 0.05 
	
	# 2. 等待真實世界的 duration 秒數
	# 關鍵！這裡不能用普通的 await get_tree().create_timer(duration).timeout
	# 因為普通的 Timer 也會受 time_scale 影響而被變慢 20 倍！
	# 我們要告訴 Timer：「請忽略時間縮放，使用真實時間」
	await get_tree().create_timer(duration, true, false, true).timeout
	
	# 3. 恢復時間流速
	Engine.time_scale = 1.0

func play_hitEffect(pos: Vector2):
	var current_effect = hitEffect.instantiate()
	current_effect.global_position = pos
	get_tree().current_scene.add_child(current_effect)
