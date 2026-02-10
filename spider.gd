extends CharacterBody2D

# --- 狀態定義 ---
enum State { IDLE, CHASE, PREPARE, FIRE, QTE_WINDOW, COOLDOWN }
var current_state = State.IDLE

# --- 參數設定 ---
@export_group("Attributes")
@export var movement_speed: float = 50.0
@export var max_hp: int = 100  # 【修正 3】新增最大血量
var current_hp: int = 100      # 【修正 3】當前血量

@export_group("Attack Settings")
@export var projectile_scene: PackedScene = preload("res://WebProjectile.tscn")
@export var flight_duration: float = 1.0
@export var qte_tolerance_ms: int = 100
@export var bind_damage: int = 10
@export var reflect_damage: int = 30 

# --- 內部變數 ---
var target_player: CharacterBody2D = null
var impact_time_msec: int = 0
var active_bullet: Node2D = null
var player_in_attack_range: bool = false # 【修正 2】新增變數記錄玩家是否在攻擊範圍內

# --- 節點參照 ---
@onready var nav_agent = $NavigationAgent2D
@onready var line_2d = $Line2D
@onready var mouth_pos = $MouthPosition
@onready var detect_area = $DetectArea
@onready var attack_area = $AttackArea
@onready var ray_cast = $RayCast2D # 【修正 1】參照射線節點

var hitEffect = preload("res://hit_effect.tscn")

func _ready():
	current_hp = max_hp # 初始化血量
	line_2d.visible = false
	
	detect_area.body_entered.connect(_on_detect_area_entered)
	detect_area.body_exited.connect(_on_detect_area_exited)
	
	# 【修正 2】攻擊範圍改為只負責切換 "在範圍內" 的狀態
	attack_area.body_entered.connect(_on_attack_area_entered)
	attack_area.body_exited.connect(_on_attack_area_exited)
	
	nav_agent.path_desired_distance = 20.0
	nav_agent.target_desired_distance = 10.0
	await get_tree().physics_frame 

func _physics_process(delta):
	match current_state:
		State.CHASE:
			_process_chase(delta)
		State.PREPARE:
			_process_prepare_visuals()
		State.FIRE, State.QTE_WINDOW:
			_process_prepare_visuals()

# --- 偵測邏輯 ---

func _on_detect_area_entered(body):
	if body.is_in_group("player"):
		target_player = body
		if current_state == State.IDLE:
			current_state = State.CHASE

func _on_detect_area_exited(body):
	if body == target_player:
		target_player = null
		if current_state == State.CHASE:
			current_state = State.IDLE
			velocity = Vector2.ZERO

# --- 【修正 2】攻擊範圍狀態管理 ---
func _on_attack_area_entered(body):
	if body.is_in_group("player"):
		player_in_attack_range = true

func _on_attack_area_exited(body):
	if body.is_in_group("player"):
		player_in_attack_range = false

# --- 追擊與攻擊觸發邏輯 ---

func _process_chase(_delta):
	if not target_player:
		current_state = State.IDLE
		return

	# 1. 檢查是否滿足攻擊條件 (在範圍內 + 有視線)
	if player_in_attack_range:
		if check_line_of_sight(): # 【修正 1】檢查牆壁
			start_bind_sequence()
			return # 進入攻擊流程，跳過移動
		
	# 2. 如果不滿足攻擊條件，繼續移動
	nav_agent.target_position = target_player.global_position
	
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		return

	var next_pos = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_pos)
	
	velocity = direction * movement_speed
	move_and_slide()
	look_at(target_player.global_position)

# --- 【修正 1】視線檢查函式 ---
func check_line_of_sight() -> bool:
	if not target_player: return false
	
	# 讓射線指向玩家
	ray_cast.target_position = to_local(target_player.global_position)
	ray_cast.force_raycast_update() # 強制更新一次，確保數據最新
	
	# 判斷邏輯：
	# 1. 如果沒撞到任何東西 (通常不會發生，因為玩家就在那)
	# 2. 或者撞到的東西是玩家 (代表中間沒有牆壁擋住)
	if ray_cast.is_colliding():
		var collider = ray_cast.get_collider()
		if collider == target_player:
			return true # 看到了！
		else:
			return false # 撞到牆壁了
	return false

# --- 攻擊序列 ---

func start_bind_sequence():
	current_state = State.PREPARE
	velocity = Vector2.ZERO 
	line_2d.visible = true
	
	if target_player.has_method("set_bound"):
		target_player.set_bound(true)
	
	print("蜘蛛：鎖定目標...")
	
	await get_tree().create_timer(1.0).timeout
	
	if target_player and current_state == State.PREPARE: # 加強檢查狀態，防止被打斷後繼續執行
		fire_projectile()
	else:
		reset_spider()

func _process_prepare_visuals():
	if target_player:
		line_2d.points = [mouth_pos.position, to_local(target_player.global_position)]

func fire_projectile():
	current_state = State.FIRE
	var bullet = projectile_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = mouth_pos.global_position
	active_bullet = bullet 
	
	var now = Time.get_ticks_msec()
	impact_time_msec = now + (flight_duration * 1000)
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD) 
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(bullet, "global_position", target_player.global_position, flight_duration)
	tween.tween_callback(_on_qte_missed)
	
	current_state = State.QTE_WINDOW

# --- QTE 判定 ---

func _input(event):
	if current_state == State.QTE_WINDOW and event.is_action_pressed("ui_accept"):
		check_qte_timing()

func check_qte_timing():
	var now = Time.get_ticks_msec()
	var diff = abs(now - impact_time_msec)
	
	if diff <= qte_tolerance_ms:
		_handle_qte_result(true)
	else:
		_handle_qte_result(false)

func _on_qte_missed():
	if current_state == State.QTE_WINDOW:
		_handle_qte_result(false)

func _handle_qte_result(is_success: bool):
	current_state = State.COOLDOWN
	if is_instance_valid(active_bullet):
		active_bullet.queue_free()
	
	if is_success:
		print("QTE 成功！反傷！")
		if target_player.has_method("set_bound"):
			target_player.set_bound(false)
		
		take_damage(reflect_damage) # 【修正 3】呼叫受傷函式
		reset_spider()
		
		play_hitEffect(target_player.global_position)
	else:
		print("QTE 失敗！受傷！")
		if target_player and target_player.has_method("take_damage"):
			target_player.take_damage(bind_damage, self.global_position)
		
		await get_tree().create_timer(1.0).timeout
		if target_player and target_player.has_method("set_bound"):
			target_player.set_bound(false)
		reset_spider()

func reset_spider():
	line_2d.visible = false
	
	await get_tree().create_timer(2.0).timeout
	
	# 【修正 2】重置後，立刻檢查是否要繼續攻擊 (解決呆滯推人問題)
	if target_player and current_hp > 0: # 活著才繼續
		current_state = State.CHASE
	else:
		current_state = State.IDLE

# --- 【修正 3】血量與受傷系統 ---
func take_damage(amount, source_position = Vector2.ZERO):
	current_hp -= amount
	print("怪物受傷！剩餘血量：", current_hp)
	
	# 受傷視覺反饋：閃爍一下
	var tween = create_tween()
	tween.tween_property($Sprite2D, "modulate", Color(10, 10, 10, 1), 0.05) # 變超亮
	tween.tween_property($Sprite2D, "modulate", Color.WHITE, 0.2) # 變回原色
	
	SoundManager.play_spatial_sfx("spider_damage", global_position, 0.0, 0.1)
	
	# hit_stop(0.1)
	# 【新增】擊退效果 (Knockback)
	# 如果傳入的來源位置不是零向量，就計算擊退
	if source_position != Vector2.ZERO:
		var knockback_dir = (global_position - source_position).normalized()
		velocity = knockback_dir * 800 # 擊退力道
		move_and_slide() # 立即執行一次移動以免卡住
	
	if current_hp <= 0:
		die()

func die():
	print("蜘蛛死亡")
	if target_player and target_player.has_method("set_bound"):
		target_player.set_bound(false) # 死前確保玩家解鎖
	SoundManager.play_spatial_sfx("spider_death", global_position, 0.0, 0.1)
	
	# 播放死亡動畫或粒子特效
	queue_free()

func play_hitEffect(pos: Vector2):
	var current_effect = hitEffect.instantiate()
	current_effect.global_position = pos
	get_tree().current_scene.add_child(current_effect)
