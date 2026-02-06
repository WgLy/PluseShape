extends CharacterBody2D

# --- 狀態定義 ---
enum State { ROAM, MOVING_TO_ROCK, PICKING_UP, FLEE, DEAD }

# --- 參數設定 ---
@export_group("Stats")
@export var hp: int = 40
@export var move_speed: float = 120.0
@export var flee_speed: float = 180.0
@export var pickup_range: float = 10.0

@export_group("AI")
@export var detect_radius: float = 800.0
@export var rock_min_ground_time: float = 2.0
@export var pick_up_duration: float = 1.5
@export var flee_duration: float = 2.0

# --- 節點參照 ---
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var digging_particles: CPUParticles2D = $DiggingParticles

# --- 內部變數 ---
var current_state: State = State.ROAM
var target_rock: Node2D = null
var target_player: Node2D = null
var state_timer: float = 0.0
var _tween: Tween


func _ready() -> void:
	target_player = get_tree().get_first_node_in_group("player")
	
	# 設定導航精度
	nav_agent.path_desired_distance = 20.0
	nav_agent.target_desired_distance = pickup_range
	
	# 初始化粒子
	digging_particles.emitting = false
	
	# 【關鍵】等待導航地圖同步
	# 即使 Layer 設對了，第一幀的地圖資料可能還是空的，必須等待
	call_deferred("_actor_setup")

func _actor_setup():
	# 等待第一個物理幀
	await get_tree().physics_frame
	# 再等一幀確保 NavigationServer 同步完畢
	await get_tree().physics_frame 
	
	_pick_new_roam_target()

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD: return
	
	match current_state:
		State.ROAM:
			_process_roam(delta)
			_scan_for_rocks()
		State.MOVING_TO_ROCK:
			_process_moving_to_rock()
		State.PICKING_UP:
			_process_picking_up(delta)
		State.FLEE:
			_process_flee(delta)

# ==========================================================
#       智能導航與移動核心
# ==========================================================

func _pick_new_roam_target():
	# 1. 以自己為圓心，隨機找一個「原始點」 (這個點可能會在牆壁裡)
	var random_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	var random_dist = randf_range(100, 300)
	var raw_target = global_position + (random_dir * random_dist)
	
	# 2. 【智能修正】詢問導航伺服器：離這個原始點最近的「合法位置」在哪？
	# 既然你修好了 Layer，這裡現在會回傳正確的座標，而不是 (0,0)
	var map_rid = get_world_2d().get_navigation_map()
	var safe_target = NavigationServer2D.map_get_closest_point(map_rid, raw_target)
	
	# 3. 設定目標
	nav_agent.target_position = safe_target

func _process_roam(delta):
	# 因為我們已經確保選點是合法的，所以不需要 retry 邏輯，直接走
	if nav_agent.is_navigation_finished():
		if state_timer <= 0:
			state_timer = 1.0 # 休息 1 秒
		else:
			state_timer -= delta
			if state_timer <= 0:
				_pick_new_roam_target()
		return

	_move_via_nav(move_speed)

func _process_moving_to_rock():
	if not is_instance_valid(target_rock):
		current_state = State.ROAM
		return
	
	# 持續追蹤石頭位置
	nav_agent.target_position = target_rock.global_position
	
	# 距離判定
	var dist = global_position.distance_to(target_rock.global_position)
	if dist < pickup_range:
		_start_picking_up()
	else:
		_move_via_nav(move_speed)

func _move_via_nav(speed: float):
	# 如果導航結束，停止移動
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		return
		
	var next_pos = nav_agent.get_next_path_position()
	var current_pos = global_position
	
	var dir = current_pos.direction_to(next_pos)
	velocity = dir * speed
	
	if dir.x != 0: sprite.flip_h = dir.x < 0
	move_and_slide()

# ==========================================================
#       其他邏輯 (不變)
# ==========================================================

func _scan_for_rocks():
	# 降低掃描頻率優化效能
	if Engine.get_physics_frames() % 20 != 0: return
	
	var rocks = get_tree().get_nodes_in_group("rocks")
	if rocks.size() == 0: return

	var best_rock = null
	var min_dist = detect_radius
	
	for rock in rocks:
		# 檢查石頭屬性
		if rock.get("grounded_time") == null: continue
		if rock.grounded_time < rock_min_ground_time: continue
			
		var dist = global_position.distance_to(rock.global_position)
		if dist < min_dist:
			# 可選：這裡也可以加上 map_get_closest_point 檢查石頭是否真的走得到
			# 但為了效能通常直接判斷距離即可
			min_dist = dist
			best_rock = rock
	
	if best_rock:
		print("【AI】發現好石頭！前往撿拾")
		target_rock = best_rock
		current_state = State.MOVING_TO_ROCK

func _start_picking_up():
	current_state = State.PICKING_UP
	state_timer = pick_up_duration
	velocity = Vector2.ZERO
	digging_particles.emitting = true
	
	if _tween: _tween.kill()
	_tween = create_tween().set_loops()
	_tween.tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.2)
	_tween.tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.2)

func _process_picking_up(delta):
	if not is_instance_valid(target_rock):
		current_state = State.ROAM
		digging_particles.emitting = false
		return
	state_timer -= delta
	if state_timer <= 0:
		_finish_picking_up()

func _finish_picking_up():
	if _tween: _tween.kill()
	sprite.scale = Vector2.ONE
	digging_particles.emitting = false
	
	if is_instance_valid(target_rock):
		if is_instance_valid(target_player) and target_player.has_method("add_stone"):
			target_player.add_stone()
			print("【AI】撿到石頭！已歸還玩家")
		
		if target_rock.has_method("be_picked_up_by_enemy"):
			target_rock.be_picked_up_by_enemy()
		else:
			target_rock.queue_free()
	
	current_state = State.ROAM

func _process_flee(delta):
	state_timer -= delta
	if state_timer <= 0:
		current_state = State.ROAM
		return
		
	if is_instance_valid(target_player):
		var dir = (global_position - target_player.global_position).normalized()
		velocity = dir * flee_speed
		
		if dir.x != 0: sprite.flip_h = dir.x < 0
		move_and_slide()

func take_damage(amount, source_pos, _knockback = 0):
	if current_state == State.DEAD: return
	
	hp -= amount
	
	var t = create_tween()
	t.tween_property(sprite, "modulate", Color(10, 10, 10), 0.05)
	t.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	
	velocity = (global_position - source_pos).normalized() * 200
	move_and_slide()
	
	if hp <= 0:
		die()
	else:
		if current_state in [State.PICKING_UP, State.MOVING_TO_ROCK, State.ROAM]:
			current_state = State.FLEE
			state_timer = flee_duration
			if _tween: _tween.kill()
			sprite.scale = Vector2.ONE
			digging_particles.emitting = false

func die():
	current_state = State.DEAD
	if _tween: _tween.kill()
	digging_particles.emitting = false
	
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(sprite, "rotation_degrees", 180.0, 0.5)
	t.tween_property(sprite, "modulate:a", 0.0, 0.5)
	await t.finished
	queue_free()
