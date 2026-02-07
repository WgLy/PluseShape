extends CharacterBody2D

signal hp_changed(new_hp)
signal recover_hp_changed(new_recover_hp)
signal player_died

# --- 核心屬性 ---
@export var speed: float = 150.0
@export var friction: float = 0.1
@export var acceleration: float = 0.1
@export var max_hp: int = 200

var current_hp = 200
var recover_hp = 200

# --- 【新增】能力解鎖系統 (Ability Unlocks) ---
# 預設為 false (未取得)，你可以依照需求在 Inspector 裡手動打勾測試
@export_group("Abilities")
@export var can_dash_ability: bool = true   # 衝刺能力 (石頭瞬移)
@export var can_attack_ability: bool = true # 攻擊能力 (丟石頭)
@export var can_sonar_ability: bool = true   # 聲納能力 (預設開啟，否則一開始全黑很難玩)

# --- 預載資源 ---
var sonar_scene = preload("res://sonar_pulse.tscn")
var hitEffect = preload("res://hit_effect.tscn")
var rock_scene = preload("res://rock.tscn")

# --- 石頭系統 ---
@export var max_stones: int = 10
var current_stones = 10
var is_holding_f = false       # 是否正在按住 F
var throw_charge_time = 0.0    # 按住 F 多久了
var current_held_rock = null   # 目前手上拿的那顆石頭
var active_rocks: Array[Node2D] = []

# --- 衝刺系統 ---
var is_dashing = false
var dashing_speed = 800

# --- 狀態控制 ---
var can_move = true  # 用於對話/過場時鎖定操作
var is_bound: bool = false # 蜘蛛束縛
var is_dead: bool = false

# --- 長按顯示可互動物體 ---
signal detect_interactable # 定義長按觸發的訊號
var press_duration: float = 0.0 # 紀錄按下的時間
var has_emitted_charge: bool = false # 紀錄這次按壓是否已經觸發過訊號
const CHARGE_THRESHOLD: float = 1.0 # 長按需要幾秒 (這裡設定 1 秒)

var is_trembling: bool = false # 是否處於抖動(暈眩/受到驚嚇)狀態
@onready var fall_rock = $"../objects/fall_rock"

func _ready():
	current_hp = max_hp
	recover_hp = max_hp
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	# StoryManager.play_new_game_sequence() # start story 
	# fall_rock.spawn_fall_rock(self, 1.0, 2.0, 1.0, 10)
	
	StoryManager.update_checkpoint(global_position)
	

func _physics_process(delta: float) -> void:
	# 0. 更新那該死的為什麼我要寫分開的weapon
	# 略
	
	# 1. 聲納能力檢查
	# 【修改】加入 !is_trembling 判斷
	if not is_trembling and Input.is_action_just_pressed("ui_accept"):
		if can_sonar_ability: 
			fire_sonar()
		else:
			print("尚未取得聲納模組！") 

	# --- 長按偵測邏輯 ---
	# 【修改】加入 !is_trembling 判斷
	if not is_trembling and Input.is_action_pressed("ui_accept"):
		if can_sonar_ability:
			press_duration += delta 
			if press_duration >= CHARGE_THRESHOLD and not has_emitted_charge:
				emit_signal("detect_interactable")
				print("長按聲納觸發！")
				has_emitted_charge = true
	else:
		press_duration = 0.0
		has_emitted_charge = false

	# 2. 攻擊與衝刺輸入處理 (內部已經加了防呆)
	handle_throw_input(delta)
	
	# 3. 移動邏輯
	if not is_bound:
		if not can_move:
			velocity = Vector2.ZERO
			move_and_slide()
			return
		
		# 【修改】移動控制邏輯
		var direction = Vector2.ZERO
		
		# 只有在「沒有抖動」時才讀取玩家輸入
		if not is_trembling:
			direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		
		# 物理計算
		if direction:
			velocity = velocity.lerp(direction * speed, acceleration)
		else:
			# 如果正在抖動(direction為0)，會執行這裡，利用 friction 慢慢停下來
			# 同時因為還有執行 move_and_slide()，所以被怪撞飛的 velocity 依然會運作
			velocity = velocity.lerp(Vector2.ZERO, friction)
			
		move_and_slide()

# --- 聲納 ---
func fire_sonar():
	var pulse = sonar_scene.instantiate()
	pulse.global_position = global_position
	get_tree().root.add_child(pulse)
	
	current_hp -= 1
	emit_signal("hp_changed", current_hp)
	
	# 假設你有 sonar_sound.wav，如果沒有先填 null
	# logic_range 設為 600，這就是你聲納能引怪的距離
	GameEvent.create_noise(global_position, null, 600.0, "sonar")
	SoundManager.play_spatial_sfx("sonar_pluse", global_position, 0.0, 0.1)

# --- 輸入處理 (整合攻擊與衝刺) ---
func handle_throw_input(delta):
	if is_bound or is_trembling: 
		return
	
	# --- A. 蓄力丟石頭 (攻擊能力) ---
	if can_attack_ability: # 【檢查能力】
		if Input.is_action_pressed("ui_f"):
			is_holding_f = true
			throw_charge_time += delta
			
			if throw_charge_time > 0.2 and current_held_rock == null and current_stones > 0:
				spawn_rock_in_hand()
		
		# 左鍵發射
		if Input.is_action_just_pressed("ui_mouse_left"):
			if current_held_rock != null:
				throw_rock()
				return 
	
	# --- B. 放開 F 的判定 (衝刺或取消) ---
	if Input.is_action_just_released("ui_f"):
		is_holding_f = false
		
		if throw_charge_time <= 0.2:
			# 短按：觸發衝刺
			if can_dash_ability: # 【檢查能力】只有解鎖後才能衝刺
				start_dash_recall()
				current_hp -= 5
				emit_signal("hp_changed", current_hp)
			else:
				print("尚未學會瞬移衝刺！") # 這裡可以加個 "無法使用" 的音效
		else:
			# 長按放開：取消投擲
			if current_held_rock != null:
				cancel_throw()
		
		throw_charge_time = 0.0

# --- 石頭生成與投擲 ---
func spawn_rock_in_hand():
	current_held_rock = rock_scene.instantiate()
	add_child(current_held_rock)
	if scale.x != 0:
		current_held_rock.scale = Vector2(1.0 / scale.x, 1.0 / scale.y)
	else:
		current_held_rock.scale = Vector2.ONE
	current_held_rock.position = Vector2.ZERO

func throw_rock():
	if current_held_rock == null: return
	
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - global_position).normalized()
	var power = clamp(throw_charge_time, 0.5, 1.5)
	
	current_held_rock.launch(direction, power)
	active_rocks.append(current_held_rock)
	
	if !current_held_rock.is_connected("tree_exiting", _on_rock_removed):
		current_held_rock.tree_exiting.connect(_on_rock_removed.bind(current_held_rock))

	current_stones -= 1
	current_held_rock = null

func cancel_throw():
	current_held_rock.queue_free()
	current_held_rock = null

func add_stone():
	if current_stones < max_stones:
		current_stones += 1
		# print("石頭回收！彈藥：", current_stones)

func _on_rock_removed(rock_instance):
	if rock_instance in active_rocks:
		active_rocks.erase(rock_instance)

# --- 衝刺邏輯 ---
func start_dash_recall():
	if active_rocks.is_empty(): 
		print("沒有石頭可以飛！") # 這是機制限制，不是能力鎖
		return
	if is_dashing: return
	
	is_dashing = true
	
	# 無敵與穿牆設定
	collision_mask = 0 
	$DashHitbox.monitoring = true
	$GhostTimer.start()
	
	var targets = active_rocks.duplicate()
	targets.reverse()
	
	for rock in targets:
		if not is_instance_valid(rock): continue
		
		var start_pos = global_position
		var target_pos = rock.global_position
		var distance = start_pos.distance_to(target_pos)
		var duration = distance / dashing_speed
		if duration < 0.1: duration = 0.1
		SoundManager.play_spatial_sfx("player_dash", global_position, 0.0, 0.1)
		
		look_at(target_pos)
		
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "global_position", target_pos, duration)
		tween.parallel().tween_property($Sprite2D, "scale", Vector2(1.3, 0.7), duration)
		
		await tween.finished
		$Sprite2D.scale = Vector2(1, 1)
		
		if is_instance_valid(rock):
			rock.queue_free()
			current_stones += 1
	
	# 結束衝刺
	is_dashing = false
	rotation = 0
	$DashHitbox.monitoring = false
	$Sprite2D.scale = Vector2(1, 1)
	$GhostTimer.stop()
	
	# 恢復碰撞層 (記得檢查這是否符合你的專案設定)
	set_collision_mask_value(1, true) # World
	set_collision_mask_value(4, true) # Enemies
	
	print("衝刺結束，彈藥全滿：", current_stones)

func _on_dash_hitbox_body_entered(body):
	if body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(50, global_position)
			play_hitEffect(global_position)

# --- 殘影效果 ---
func _on_ghost_timer_timeout():
	add_ghost()

func add_ghost():
	var ghost = Sprite2D.new()
	ghost.texture = $Sprite2D.texture
	ghost.global_position = global_position
	ghost.rotation = rotation
	ghost.scale = $Sprite2D.global_scale
	ghost.modulate = Color(1.0, 1.0, 1.0, 0.5)
	ghost.z_index = z_index - 1
	get_tree().root.add_child(ghost)
	
	var tween = create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.3)
	tween.tween_callback(ghost.queue_free)

# --- 受傷與死亡 ---
func take_damage(amount, source_position, level: int = 100):
	print("call take_damage")
	current_hp -= amount
	recover_hp -= amount
	emit_signal("hp_changed", current_hp)
	emit_signal("recover_hp_changed", recover_hp)
	
	print("結束：current_hp: " , current_hp , " recover_hp: " , recover_hp)
	var knockback_dir = (global_position - source_position).normalized()
	velocity = knockback_dir * level
	move_and_slide()

func hp_change(val: int, type: String = "normal"):
	if current_hp < max_hp and type == "recover":
		recover_hp += val
		emit_signal("recover_hp_changed", recover_hp)
	if current_hp < max_hp and current_hp < recover_hp and type == "normal":
		current_hp += val
		emit_signal("hp_changed", current_hp)

func die():
	if is_dead:
		return
	is_dead = true
	emit_signal("player_died")
	
	# 這裡放置死亡動畫呼叫
	await play_implosion_death_animation()
	
	StoryManager.play_death_sequence()

func _on_natural_recover_timer_timeout() -> void:
	if current_hp < min(max_hp, recover_hp):
		current_hp += 1
		emit_signal("hp_changed", current_hp)

# --- 狀態與對話控制 ---
func _on_dialogue_started():
	can_move = false
	velocity = Vector2.ZERO

func _on_dialogue_finished():
	can_move = true

func set_bound(state: bool):
	is_bound = state

# --- 存檔與解鎖 ---

# 【新增】能力解鎖函式 (給寶箱或劇情呼叫)
func unlock_ability(ability_name: String):
	match ability_name:
		"dash":
			can_dash_ability = true
			# DialogueManager.start_dialogue(["獲得能力：瞬移衝刺！", "投擲石頭後，短按 F 即可瞬間移動收回石頭。"])
		"attack":
			can_attack_ability = true
			# DialogueManager.start_dialogue(["獲得能力：投擲石頭！", "按住 F 蓄力，左鍵發射。"])
		"sonar":
			can_sonar_ability = true
			# DialogueManager.start_dialogue(["獲得能力：聲納探測！", "按下空白鍵發出聲波，照亮周圍。"])

# 存檔擴充：記得把能力狀態也存起來
func save() -> Dictionary:
	return {
		"pos_x": global_position.x,
		"pos_y": global_position.y,
		"hp": current_hp,
		"stones": current_stones,
		# 存入能力狀態
		"unlock_dash": can_dash_ability,
		"unlock_attack": can_attack_ability,
		"unlock_sonar": can_sonar_ability
	}

func load_data(data: Dictionary):
	global_position = Vector2(data["pos_x"], data["pos_y"])
	current_hp = data["hp"]
	current_stones = data["stones"]
	
	# 還原能力狀態 (使用 get 避免舊存檔報錯)
	can_dash_ability = data.get("unlock_dash", false)
	can_attack_ability = data.get("unlock_attack", false)
	can_sonar_ability = data.get("unlock_sonar", true)
	
	emit_signal("hp_changed", current_hp, false)
	active_rocks.clear()
	if current_held_rock:
		current_held_rock.queue_free()
		current_held_rock = null

func _input(event):
	if event.is_action_pressed("ui_save"):
		# SaveManager.save_game(1)
		pass
	if event.is_action_pressed("ui_load"):
		# SaveManager.load_game(1)
		pass

# --- 特效輔助 ---
func hit_stop(duration: float):
	Engine.time_scale = 0.001
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func play_hitEffect(pos: Vector2):
	var current_effect = hitEffect.instantiate()
	current_effect.global_position = pos
	get_tree().current_scene.add_child(current_effect)

func reset_hp(): 
	print("正在執行玩家復活程序...")
	
	# 1. 數值重置
	current_hp = max_hp
	recover_hp = max_hp
	emit_signal("hp_changed", max_hp)
	emit_signal("recover_hp_changed", max_hp)
	
	# 2. 狀態旗標重置
	is_dead = false
	is_trembling = false
	is_bound = false
	can_move = true
	
	# 3. 視覺重置 (這是對應死亡動畫的還原)
	$Sprite2D.visible = true
	$Sprite2D.scale = Vector2.ONE
	$Sprite2D.position = Vector2.ZERO # 確保抖動造成的位移歸零
	$Sprite2D.modulate = Color.WHITE # 如果有變色，還原
	
	# 4. 物理與碰撞重置
	velocity = Vector2.ZERO
	set_physics_process(true) # 重新啟用物理循環
	$CollisionShape2D.set_deferred("disabled", false) # 重新啟用碰撞
	
	# 5. 能力鎖還原 (依照解鎖狀態還原，而非全部打開)
	# 這裡很重要：我們不是設為 true，而是設為「目前應該有的狀態」
	# 假設死亡不會導致能力遺失，這裡其實可以不用動，
	# 但因為你在 die() 裡面把它們全設 false 了，所以這裡必須還原。
	# 為了避免邏輯錯誤，建議在 die() 裡面使用一個暫存變數，或是直接修改 die() 不要動這些開關
	
	# 修正方案 A：直接手動設回 true (如果你確定死前都已經解鎖了)
	# can_dash_ability = true
	# can_attack_ability = true
	# can_sonar_ability = true
	
	# 修正方案 B (推薦)：讀取 save() 的邏輯來還原
	# 由於你在 die() 把變數改掉了，最好的方式其實是不要在 die() 改這些永久變數，
	# 而是用一個 `is_dying` 旗標在 _physics_process 擋住操作。
	
	# 但為了配合你目前的架構，我們先暫時全部開啟 (或是你可以設計一個 temp 變數存起來)
	# 假設遊戲進度是線性的，復活時這些能力應該都要能用：
	can_dash_ability = true # 這裡依據你的遊戲設計決定是否要還原
	can_attack_ability = true
	can_sonar_ability = true
	
	print("玩家狀態已完全重置")

# --- 抖動控制函式 ---
# level: 抖動幅度 (像素偏移量)
# duration: 持續時間 (秒)
func start_tremble(level: float, duration: float, lock_player: bool = false):
	if is_trembling: return # 如果已經在抖動，避免重複觸發 (或是你可以設計成覆蓋)
	
	if lock_player:
		is_trembling = true
	
	# 強制中斷目前的動作
		is_holding_f = false
		throw_charge_time = 0.0
		if current_held_rock != null:
			cancel_throw()
	
	# 使用 Tween 或 Timer 來處理持續時間與抖動動畫
	# 這裡我們用一個簡單的迴圈配合 Timer 來做隨機位移
	var end_time = Time.get_ticks_msec() + (duration * 1000)
	
	while Time.get_ticks_msec() < end_time:
		# 產生隨機偏移 (只移動 Sprite，不移動物理碰撞體)
		var offset_x = randf_range(-level, level)
		var offset_y = randf_range(-level, level)
		$Sprite2D.position = Vector2(offset_x, offset_y)
		
		# 等待一幀 (這是必要的，否則迴圈會卡死遊戲)
		await get_tree().process_frame
		
		# 如果中途死亡或被強制取消，停止抖動
		if not is_trembling:
			break
	
	# 結束後復原
	is_trembling = false
	$Sprite2D.position = Vector2.ZERO

# --- 死亡動畫微調 ---
func play_implosion_death_animation() -> void:
	# 1. 鎖定玩家操作與物理
	set_physics_process(false)
	
	# 【建議修改】不要在這裡修改 can_..._ability 這些永久屬性
	# 因為這些屬性代表「玩家是否學會了這招」，而不是「現在能不能用」
	# 你已經把 set_physics_process 關了，玩家根本動不了，所以不用動這些變數。
	# can_dash_ability = false  <-- 建議移除
	# can_attack_ability = false <-- 建議移除
	# can_sonar_ability = false  <-- 建議移除
	
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true) 
	
	var tween = create_tween()
	
	# --- 階段 A: 內爆 ---
	tween.tween_property($Sprite2D, "scale", Vector2(0.0, 0.0), 0.5)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	# --- 階段 B: 碎裂 ---
	tween.tween_callback(func():
		$Sprite2D.visible = false
		if has_node("DeathParticles"):
			$DeathParticles.emitting = true
	)
	
	# --- 階段 C: 等待 ---
	await tween.finished
	await get_tree().create_timer(1.2).timeout
