extends CharacterBody2D

# --- 狀態定義 ---
enum State { IDLE, CREEP, FLEE, DEAD }

# --- 參數設定 ---
@export_group("Stats")
@export var hp: int = 30
@export var damage: int = 20

@export_group("Movement")
@export var creep_speed: float = 60.0  # 移動慢
@export var flee_speed: float = 250.0  # 逃跑快
@export var alert_radius: float = 400.0 # 警戒半徑
@export var flee_duration: float = 2.0  # 逃跑持續時間

# --- 節點參照 ---
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $BodySprite # 假設你有分開或合併
@onready var flee_timer: Timer = $FleeTimer

# --- 內部變數 ---
var current_state: State = State.IDLE
var target_player: Node2D = null

func _ready() -> void:
	target_player = get_tree().get_first_node_in_group("player")
	
	# 導航設定
	nav_agent.path_desired_distance = 20.0
	nav_agent.target_desired_distance = 10.0
	
	# 連接 Timer
	flee_timer.wait_time = flee_duration
	flee_timer.timeout.connect(_on_flee_timeout)
	
	call_deferred("_actor_setup")

func _actor_setup():
	await get_tree().physics_frame
	await get_tree().physics_frame

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD: return
	if not is_instance_valid(target_player): return

	# --- 核心行為：始終面向玩家 ---
	# 這是「隱匿者」的特色，拿著板子擋光
	# 即使在逃跑，通常也是舉著盾倒退(比較有防禦感)，或者你可以選擇轉身逃
	var dir_to_player = global_position.direction_to(target_player.global_position)
	
	# 使用 lerp 讓轉向稍微平滑一點，看起來更有生物感
	rotation = lerp_angle(rotation, dir_to_player.angle(), 10.0 * delta)

	# --- 狀態機邏輯 ---
	match current_state:
		State.IDLE:
			_process_idle()
		State.CREEP:
			_process_creep(delta)
		State.FLEE:
			_process_flee(delta)

	# --- 碰撞傷害偵測 ---
	_check_collision_damage()

# ==========================================================
#       狀態邏輯
# ==========================================================

func _process_idle():
	velocity = Vector2.ZERO
	
	# 檢查距離，進入警戒範圍就開始潛伏移動
	var dist = global_position.distance_to(target_player.global_position)
	if dist <= alert_radius:
		current_state = State.CREEP

func _process_creep(_delta):
	# 1. 持續追蹤玩家
	nav_agent.target_position = target_player.global_position
	
	# 2. 緩慢移動
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
	else:
		# 使用智能導航 (如果已經設定好 Server)
		var next = nav_agent.get_next_path_position()
		var dir = global_position.direction_to(next)
		velocity = dir * creep_speed
		
	move_and_slide()

func _process_flee(_delta):
	# 逃跑邏輯：不需要導航，直接往反方向衝
	# 簡單的反向向量
	var flee_dir = (global_position - target_player.global_position).normalized()
	
	# 檢查身後是不是牆壁 (可選：使用 RayCast 或 move_and_slide 自動處理)
	velocity = flee_dir * flee_speed
	
	move_and_slide()

func _on_flee_timeout():
	# 逃跑時間結束，恢復待機或潛伏
	# 如果玩家還在附近，直接切回 CREEP，否則 IDLE
	var dist = global_position.distance_to(target_player.global_position)
	if dist <= alert_radius:
		current_state = State.CREEP
	else:
		current_state = State.IDLE

# ==========================================================
#       攻擊與受傷
# ==========================================================

func _check_collision_damage():
	# 使用 move_and_slide 的碰撞資訊來判定攻擊
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider == target_player and collider.has_method("take_damage"):
			# 造成傷害
			collider.take_damage(damage, global_position, 300)
			
			# 【關鍵】攻擊成功後，觸發逃跑
			print("隱匿者：偷襲成功！快逃！")
			start_flee()
			break

func take_damage(amount, source_pos, _knockback = 0):
	if current_state == State.DEAD: return
	
	hp -= amount
	
	# 受傷特效
	var t = create_tween()
	t.tween_property(self, "modulate", Color(10, 0, 0), 0.05)
	t.tween_property(self, "modulate", Color.WHITE, 0.1)
	
	# 擊退
	velocity = (global_position - source_pos).normalized() * 150
	move_and_slide()
	
	if hp <= 0:
		die()
	else:
		# 【關鍵】受傷後，觸發逃跑 (膽小的特性)
		if current_state != State.FLEE:
			print("隱匿者：被打到了！快逃！")
			start_flee()

func start_flee():
	current_state = State.FLEE
	flee_timer.start(flee_duration)

func die():
	current_state = State.DEAD
	flee_timer.stop()
	
	# 死亡動畫
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2(0.1, 0.1), 0.3)
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	
	await t.finished
	queue_free()
