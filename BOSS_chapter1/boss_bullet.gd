extends Area2D

# --- 定義移動模式 ---
enum BulletMode {
	LINEAR,     # 等速直線
	ACCEL,      # 加速或減速 (速度會變)
	WOBBLE,     # 波動飛行 (S型軌跡)
	STOP_N_GO   # 飛一段停下來，再繼續飛
}

# --- 參數 ---
@export_group("Visuals")
@export var vanish_effect_scene: PackedScene # 【新增】請在這裡拖入爆炸/消失特效的 tscn

@export_group("Stats")
var speed: float = 200.0
var direction: Vector2 = Vector2.RIGHT
var damage: int = 10
var lifetime: float = 5.0

# --- 內部運算變數 ---
var current_mode: BulletMode = BulletMode.LINEAR
var acceleration: float = 0.0     # 用於 ACCEL 模式
var wobble_freq: float = 5.0      # 用於 WOBBLE 模式 (頻率)
var wobble_amp: float = 150.0     # 用於 WOBBLE 模式 (振幅)
var elapsed_time: float = 0.0     # 紀錄子彈存活時間

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	# 設定壽命倒數
	await get_tree().create_timer(lifetime).timeout
	# 時間到如果是自然消滅，也可以播特效，或直接消失
	spawn_hit_effect() 
	queue_free()

func _physics_process(delta: float) -> void:
	elapsed_time += delta
	
	# 計算這一步預計要移動的向量 (Velocity Vector)
	var velocity = Vector2.ZERO
	
	match current_mode:
		BulletMode.LINEAR:
			velocity = direction * speed * delta
		BulletMode.ACCEL:
			speed += acceleration * delta
			velocity = direction * speed * delta
		BulletMode.WOBBLE:
			var forward_move = direction * speed * delta
			var wave_offset = direction.orthogonal() * cos(elapsed_time * wobble_freq) * wobble_amp * delta
			# 注意：WOBBLE 的位移比較複雜，簡單做的話只檢測前進方向即可
			velocity = forward_move + wave_offset
			rotation = velocity.angle()
		BulletMode.STOP_N_GO:
			var current_speed = speed
			if elapsed_time > 0.5 and elapsed_time < 1.0: current_speed = 0
			elif elapsed_time >= 1.0: current_speed = speed * 1.5
			velocity = direction * current_speed * delta

	# --- 【關鍵修改】防穿牆檢測 (RayCast) ---
	# 建立一個物理空間查詢
	var space_state = get_world_2d().direct_space_state
	
	# 定義射線：從「現在位置」射向「預計抵達位置」
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + velocity)
	
	# 設定射線的過濾條件 (Mask)，確保它只會撞到牆壁或玩家
	# 注意：這裡的 collision_mask 是你自己 Area2D 設定的 Mask
	query.collision_mask = collision_mask 
	query.collide_with_areas = true # 如果你也想偵測其他 Area
	query.collide_with_bodies = true # 偵測牆壁 (TileMap/StaticBody)
	
	var result = space_state.intersect_ray(query)
	
	if result:
		# 如果射線撞到了東西
		var collider = result["collider"]
		
		# 執行原本的碰撞邏輯
		_on_body_entered(collider)
		
		# 強制移動到撞擊點 (選用，讓視覺更精準)
		global_position = result["position"]
		return # 停止移動，因為已經撞到了
		
	# --- 如果沒撞到，才真的移動 ---
	position += velocity

# --- 初始化函式 (更新版) ---
# mode: 移動模式 (0=Linear, 1=Accel, 2=Wobble)
# extra_param: 根據模式有不同用途
#   - ACCEL: 代表加速度 (正數變快，負數變慢)
#   - WOBBLE: 代表振幅 (波浪寬度)
func setup(pos: Vector2, dir: Vector2, _speed: float, _damage: int, mode: int = 0, extra_param: float = 0.0):
	global_position = pos
	direction = dir.normalized()
	speed = _speed
	damage = _damage
	current_mode = mode
	
	rotation = direction.angle()
	
	# 根據模式分配額外參數
	match current_mode:
		BulletMode.ACCEL:
			acceleration = extra_param # 傳入加速度
		BulletMode.WOBBLE:
			wobble_amp = extra_param if extra_param != 0 else 150.0 # 傳入振幅

# --- 碰撞處理 ---
func _on_body_entered(body: Node2D):
	# 1. 撞到玩家
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
		_impact_and_die()
		return # 撞到玩家就結束，不用往下跑
	
	# 2. 撞到任何「非玩家」的東西 (假設 Mask 設定正確，會撞到的只剩牆壁)
	# 只要不是 BOSS 自己發出的子彈或 BOSS 本體 (如果有的話)
	if not body.is_in_group("boss"): 
		_impact_and_die()

func _impact_and_die():
	spawn_hit_effect()
	queue_free()

func spawn_hit_effect():
	# 播放消失動畫
	if vanish_effect_scene:
		var vfx = vanish_effect_scene.instantiate()
		vfx.global_position = global_position
		vfx.rotation = rotation # 讓特效方向跟子彈一樣
		get_parent().add_child(vfx) # 加到世界場景中
