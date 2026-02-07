extends CharacterBody2D

# --- 狀態定義 ---
enum State { CHASE, STUNNED, DEAD }

# --- 參數設定 ---
@export_group("Stats")
@export var hp: int = 30
@export var move_speed: float = 60.0

@export_group("Combat")
@export var bullet_scene: PackedScene # 記得拖入 BossBullet.tscn
@export var max_detect_range: float = 600.0
@export var min_safe_range: float = 150.0

@export_group("Fire Rate")
@export var slow_shoot_interval: float = 10.0 
@export var fast_shoot_interval: float = 1.0

@export_group("AI Adjustment")
@export var reposition_interval: float = 2.0 # 每幾秒換一次位置
@export var reposition_distance: float = 100.0 # 換位移動的距離

# --- 節點參照 ---
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle: Marker2D = $Muzzle
@onready var shoot_timer: Timer = $ShootTimer
@onready var los_ray: RayCast2D = $LineOfSightRay

# --- 內部變數 ---
var current_state: State = State.CHASE
var target_player: Node2D = null
var recoil_velocity: Vector2 = Vector2.ZERO # 【新增】專門用來計算後座力的速度
var reposition_timer: float = 0.0
var reposition_target: Vector2 = Vector2.ZERO
var is_repositioning: bool = false


func _ready() -> void:
	target_player = get_tree().get_first_node_in_group("player")
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	
	nav_agent.path_desired_distance = 20.0
	nav_agent.target_desired_distance = 50.0
	
	call_deferred("_actor_setup")

func _actor_setup():
	await get_tree().physics_frame
	await get_tree().physics_frame
	shoot_timer.start(slow_shoot_interval)

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD: return
	
	# 【修正 1】後座力衰減 (模擬摩擦力)
	# 讓後座力速度隨時間歸零，數值 5.0 代表摩擦力大小
	recoil_velocity = recoil_velocity.lerp(Vector2.ZERO, 5.0 * delta)
	
	match current_state:
		State.CHASE:
			_process_chase(delta)
		State.STUNNED:
			# 暈眩時雖然不能主動移動，但後座力依然有效
			velocity = recoil_velocity
			move_and_slide()

# ==========================================================
#       移動邏輯
# ==========================================================

func _process_chase(delta):
	if not is_instance_valid(target_player): return
	
	# 1. 旋轉面向玩家
	var dir_to_player = global_position.direction_to(target_player.global_position)
	rotation = dir_to_player.angle()
	
	# 2. 視線檢查 (由 RayCast 負責)
	var can_see_player = _check_line_of_sight()
	var dist = global_position.distance_to(target_player.global_position)
	
	# 3. 決定目標位置
	var final_move_velocity = Vector2.ZERO
	
	# --- 情況 A: 正在強制換位中 (為了走出牆角) ---
	if is_repositioning:
		nav_agent.target_position = reposition_target
		
		# 如果到了或者導航走完了
		if nav_agent.is_navigation_finished() or global_position.distance_to(reposition_target) < 20.0:
			is_repositioning = false # 結束換位
		else:
			var next = nav_agent.get_next_path_position()
			final_move_velocity = global_position.direction_to(next) * move_speed
	
	# --- 情況 B: 看不到玩家 (被牆擋住) ---
	# 即使距離夠近，但如果看不到玩家，依然要移動！
	elif not can_see_player:
		# 當看不到玩家時，直接往玩家位置移動，通常能繞過牆角
		nav_agent.target_position = target_player.global_position
		
		if not nav_agent.is_navigation_finished():
			var next = nav_agent.get_next_path_position()
			final_move_velocity = global_position.direction_to(next) * move_speed

	# --- 情況 C: 看得到玩家，且距離太遠 ---
	elif dist > min_safe_range:
		nav_agent.target_position = target_player.global_position
		
		if not nav_agent.is_navigation_finished():
			var next = nav_agent.get_next_path_position()
			final_move_velocity = global_position.direction_to(next) * move_speed

	# --- 情況 D: 看得到玩家，且距離夠近 (理想射擊位置) ---
	else:
		# 在這裡加入「定時換位」邏輯，避免它像個木頭人
		reposition_timer += delta
		if reposition_timer > reposition_interval:
			reposition_timer = 0.0
			_start_repositioning()
	
	# 4. 應用移動 + 後座力
	velocity = final_move_velocity + recoil_velocity
	move_and_slide()

# ==========================================================
#       輔助函式
# ==========================================================

func _check_line_of_sight() -> bool:
	if not target_player: return false
	
	# 設定射線：從槍口射向玩家
	los_ray.target_position = to_local(target_player.global_position)
	los_ray.force_raycast_update() # 強制更新確保準確
	
	# 如果射線有撞到東西 (Mask 只有牆壁)，代表視線被擋住
	if los_ray.is_colliding():
		return false # 有牆壁
	else:
		return true # 沒牆壁，看得到

func _start_repositioning():
	# 隨機找一個側面的點移動，讓走位更靈活
	# 計算垂直向量 (側跳)
	var side_dir = Vector2.RIGHT.rotated(rotation + deg_to_rad(90))
	if randf() > 0.5: side_dir = -side_dir # 隨機左右
	
	# 稍微加一點前後隨機
	var random_offset = (side_dir * 0.8 + Vector2.RIGHT.rotated(rotation) * randf_range(-0.5, 0.5)).normalized()
	
	var raw_target = global_position + (random_offset * reposition_distance)
	
	# 確保點在導航網格上
	var map_rid = get_world_2d().get_navigation_map()
	reposition_target = NavigationServer2D.map_get_closest_point(map_rid, raw_target)
	
	is_repositioning = true

# ==========================================================
#       射擊邏輯 (隨機模式)
# ==========================================================

func _on_shoot_timer_timeout():
	# 基本檢查：如果不是追擊狀態或玩家消失，稍後再測
	if current_state != State.CHASE or not is_instance_valid(target_player):
		shoot_timer.start(1.0)
		return
	
	# 1. 計算距離
	var dist = global_position.distance_to(target_player.global_position)
	
	# 【關鍵優化】如果距離大於最大偵測範圍，直接跳出，不產生子彈！
	if dist > max_detect_range:
		# 設定一個較短的檢查間隔 (例如 0.5 ~ 1.0 秒)，持續監測玩家是否靠近
		shoot_timer.start(1.0) 
		return

	# 2. 距離夠近，執行隨機攻擊
	_fire_random_pattern()
	
	# 3. 計算下次射擊時間 (根據距離動態調整攻速)
	var next_wait_time = _calculate_cooldown(dist)
	shoot_timer.start(next_wait_time)

func _calculate_cooldown(distance: float) -> float:
	if distance > max_detect_range:
		return slow_shoot_interval
	var t = clamp((distance - min_safe_range) / (max_detect_range - min_safe_range), 0.0, 1.0)
	return lerp(fast_shoot_interval, slow_shoot_interval, t)

# 【修正 2】隨機彈幕模式
func _fire_random_pattern():
	if not bullet_scene: return
	
	# 定義權重：單發機率最高，其他隨機
	# 1-60: 單發, 61-80: 扇形, 81-95: 三連發, 96-100: 蛇行
	var roll = randi() % 100
	
	# 槍口發光特效
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(2, 2, 0), 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	
	# 基礎方向 (槍口朝向)
	var base_dir = Vector2.RIGHT.rotated(rotation)
	
	if roll < 60:
		# --- 模式 A: 單發 (Single) ---
		_spawn_bullet(base_dir, 50, 0, 0)
		_apply_recoil(150.0) # 單發後座力小
		
	elif roll < 80:
		# --- 模式 B: 散彈 (Shotgun 3發) ---
		# 中間一發，左右各偏 15 度
		_spawn_bullet(base_dir, 40, 0, 0)
		_spawn_bullet(base_dir.rotated(deg_to_rad(15)), 40, 0, 0)
		_spawn_bullet(base_dir.rotated(deg_to_rad(-15)), 40, 0, 0)
		_apply_recoil(300.0) # 散彈後座力大
		
	elif roll < 95:
		# --- 模式 C: 三連發 (Burst) ---
		# 使用 Tween 來做時間差射擊
		var burst_tween = create_tween()
		for i in range(3):
			burst_tween.tween_callback(func(): 
				_spawn_bullet(base_dir, 100, 0, 0) # 連發速度稍快
				_apply_recoil(50.0) # 每次小後座力
			)
			burst_tween.tween_interval(0.1) # 間隔 0.1 秒
			
	else:
		# --- 模式 D: 蛇行彈 (Snake / Wobble) ---
		# 使用 BossBullet 的 Mode 2 (WOBBLE)
		# 參數 200 是擺動幅度
		_spawn_bullet(base_dir, 80, 2, 40.0) 
		_apply_recoil(150.0)

# 輔助：生成子彈
func _spawn_bullet(dir: Vector2, speed: float, mode: int, extra: float):
	var bullet = bullet_scene.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = muzzle.global_position
	
	# 呼叫 BossBullet 的 setup (需支援 mode 參數)
	if bullet.has_method("setup"):
		bullet.setup(muzzle.global_position, dir, speed, 10, mode, extra)

# 輔助：施加後座力
func _apply_recoil(force: float):
	# 反方向推力
	var recoil_dir = -Vector2.RIGHT.rotated(rotation)
	# 將推力直接加到後座力變數上
	recoil_velocity += recoil_dir * force

# ==========================================================
#       受傷與死亡
# ==========================================================

func take_damage(amount, source_pos, _knockback = 0):
	if current_state == State.DEAD: return
	
	hp -= amount
	
	var t = create_tween()
	t.tween_property(sprite, "modulate", Color(10, 0, 0), 0.05)
	t.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	
	# 受傷擊退 (疊加到 recoil_velocity 讓物理運算處理)
	var knock_dir = (global_position - source_pos).normalized()
	recoil_velocity += knock_dir * 300
	
	if hp <= 0:
		die()

func die():
	current_state = State.DEAD
	shoot_timer.stop()
	
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.2)
	t.tween_property(sprite, "modulate:a", 0.0, 0.2)
	
	await t.finished
	queue_free()
