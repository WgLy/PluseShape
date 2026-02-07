extends CharacterBody2D

# --- 狀態定義 ---
enum State { CHASE, PREPARE_ATTACK, ATTACKING, COOLDOWN, HURT, DEAD }

# --- 參數設定 ---
@export_group("Stats")
@export var hp: int = 50
@export var move_speed: float = 140.0
@export var damage: int = 15

@export_group("Combat AI")
@export var attack_trigger_range: float = 40.0 
@export var wind_up_time: float = 0.5        
@export var attack_duration: float = 0.2     
@export var cooldown_time: float = 1.0       

# --- 節點參照 ---
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var slash_visual: Node2D = $AttackArea/SlashVisual

# --- 內部變數 ---
var current_state: State = State.CHASE
var target_player: Node2D = null
var state_timer: float = 0.0
var attack_dir: Vector2 = Vector2.ZERO # 【新增】鎖定攻擊方向

func _ready() -> void:
	target_player = get_tree().get_first_node_in_group("player")
	
	attack_area.monitoring = false
	slash_visual.visible = false
	
	nav_agent.path_desired_distance = 20.0
	nav_agent.target_desired_distance = attack_trigger_range 
	
	call_deferred("_actor_setup")

func _actor_setup():
	await get_tree().physics_frame
	await get_tree().physics_frame

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD: return
	
	if state_timer > 0:
		state_timer -= delta
	
	match current_state:
		State.CHASE:
			_process_chase(delta)
		State.PREPARE_ATTACK:
			_process_prepare(delta) # 傳入 delta 以便處理轉向
		State.ATTACKING:
			_process_attacking()
		State.COOLDOWN:
			if state_timer <= 0:
				current_state = State.CHASE
		State.HURT:
			if state_timer <= 0:
				current_state = State.CHASE

# ==========================================================
#       AI 邏輯
# ==========================================================

func _process_chase(_delta):
	if not is_instance_valid(target_player): return
	
	var dist = global_position.distance_to(target_player.global_position)
	
	# 1. 檢查是否進入攻擊範圍
	if dist <= attack_trigger_range:
		_start_attack_sequence()
		return
	
	# 2. 追蹤與移動
	nav_agent.target_position = target_player.global_position
	
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
	else:
		var next = nav_agent.get_next_path_position()
		var dir = global_position.direction_to(next)
		velocity = dir * move_speed
		
		# 【修改 1】全向旋轉：直接讓身體轉向移動方向
		# 這會讓怪物和判定框都面對目標
		rotation = dir.angle()
		
		move_and_slide()

# ==========================================================
#       攻擊序列
# ==========================================================

func _start_attack_sequence():
	current_state = State.PREPARE_ATTACK
	state_timer = wind_up_time
	velocity = Vector2.ZERO 
	
	# 視覺提示：變紅
	var t = create_tween()
	t.tween_property(sprite, "modulate", Color(3, 0.5, 0.5), wind_up_time)

func _process_prepare(_delta):
	# 【修改 2】蓄力階段的追蹤邏輯
	# 選項 A：蓄力時「持續旋轉」追蹤玩家 (玩家比較難躲)
	# 選項 B：蓄力瞬間「鎖定方向」不動 (玩家比較好躲)
	# 這裡採用 A (持續追蹤)，直到攻擊前一刻才鎖定
	
	if is_instance_valid(target_player):
		var dir_to_player = global_position.direction_to(target_player.global_position)
		# 使用 lerp_angle 讓轉向稍微平滑一點，不要瞬間 180 度轉身
		rotation = lerp_angle(rotation, dir_to_player.angle(), 10.0 * _delta)
	
	if state_timer <= 0:
		_perform_slash()

func _perform_slash():
	current_state = State.ATTACKING
	state_timer = attack_duration
	
	attack_area.monitoring = true
	
	sprite.modulate = Color.WHITE
	slash_visual.visible = true
	slash_visual.modulate.a = 1.0
	
	# 【修改 3】衝刺方向計算
	# 因為我們使用了 rotation，所以怪物的「正前方」永遠是 Vector2.RIGHT 旋轉後的結果
	var dash_vector = Vector2.RIGHT.rotated(rotation)
	SoundManager.play_spatial_sfx("enemy_dash", global_position, 0.0, 0.1)
	
	# 往前踏步
	var t = create_tween()
	t.tween_property(self, "position", position + dash_vector * 40.0, 0.1).set_trans(Tween.TRANS_QUAD)
	t.parallel().tween_property(slash_visual, "modulate:a", 0.0, 0.2) 

func _process_attacking():
	if attack_area.monitoring:
		var bodies = attack_area.get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(damage, global_position, 300)
				attack_area.set_deferred("monitoring", false)
	
	if state_timer <= 0:
		_end_attack()

func _end_attack():
	current_state = State.COOLDOWN
	state_timer = cooldown_time
	attack_area.monitoring = false
	slash_visual.visible = false

# ==========================================================
#       受傷與死亡 (不變)
# ==========================================================

func take_damage(amount, source_pos, _knockback = 0):
	if current_state == State.DEAD: return
	
	hp -= amount
	SoundManager.play_spatial_sfx("enemy_hurt", global_position, 0.0, 0.1)
	if current_state == State.PREPARE_ATTACK:
		# 打斷攻擊
		attack_area.monitoring = false
		slash_visual.visible = false
		sprite.modulate = Color.WHITE
		current_state = State.HURT
		state_timer = 0.4
	
	var t = create_tween()
	t.tween_property(sprite, "modulate", Color(10, 10, 10), 0.05)
	t.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	
	velocity = (global_position - source_pos).normalized() * 200
	move_and_slide()
	
	if hp <= 0:
		die()

func die():
	current_state = State.DEAD
	attack_area.monitoring = false
	SoundManager.play_spatial_sfx("enemy_die", global_position, 0.0, 0.1)
	var t = create_tween()
	t.set_parallel(true)
	# 死亡時隨機旋轉，或是保持倒下的樣子
	t.tween_property(sprite, "scale", Vector2(1.2, 0.2), 0.3) # 被壓扁的效果
	t.tween_property(sprite, "modulate", Color(0.2, 0, 0, 0), 0.5)
	
	await t.finished
	queue_free()
