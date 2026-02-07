extends CharacterBody2D

# --- 狀態定義 ---
enum State { IDLE, CHASE, RETURN_HOME, PREPARE_DASH, DASHING, IMPACT, STUNNED, DEAD }

# --- 參數設定 ---
@export_group("Movement")
@export var normal_speed: float = 80.0
@export var return_speed: float = 80.0      # 回家速度較慢
@export var dash_speed: float = 900.0       # 衝刺速度
@export var dash_duration: float = 0.4      # 衝刺最大時間

@export_group("AI Logic")
@export var hearing_range: float = 1000.0   # 怪物最大聽力 (超過這距離的聲音不理會)
@export var chase_radius: float = 600.0     # 追擊半徑 (離家多遠會放棄)
@export var aggro_vision_range: float = 400.0 # 視覺/感知範圍 (靠近自動追)

@export_group("Combat")
@export var hp: int = 40
@export var impact_damage: int = 25
@export var contact_damage: int = 10

# --- 節點參照 ---
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var shockwave_area: Area2D = $ShockwaveArea
@onready var shockwave_visual: Sprite2D = $ShockwaveVisual

# --- 內部變數 ---
var current_state: State = State.IDLE
var home_position: Vector2
var target_player: Node2D = null
var current_target_sound_pos: Vector2 # 紀錄當前鎖定的聲音來源
var _tween: Tween

var return_cooldown: float = 0.0

func _ready() -> void:
	# 1. 記錄出生點 (家)
	home_position = global_position
	# print("【DEBUG】家 (Home) 的座標是: ", home_position) # 確認這不是 (0,0)
	
	# 2. 尋找玩家
	target_player = get_tree().get_first_node_in_group("player")
	
	# 3. 連接聽覺
	GameEvent.sound_emitted.connect(_on_sound_heard)
	
	# 4. 初始化視覺與導航
	shockwave_area.monitoring = false
	shockwave_visual.visible = false
	nav_agent.path_desired_distance = 20.0
	nav_agent.target_desired_distance = 20.0

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD: return
	
	match current_state:
		State.IDLE:
			_process_idle()
		State.CHASE:
			_process_chase(delta)
		State.RETURN_HOME:
			_process_return_home(delta)
		State.DASHING:
			move_and_slide() # 保留物理碰撞
			_check_contact_damage() # 衝刺中撞到人也要造成傷害
		State.STUNNED:
			# 暈眩中甚麼都不做
			velocity = Vector2.ZERO

# ==========================================================
#      AI 決策與移動邏輯 (修正版)
# ==========================================================

# 1. 閒置邏輯
func _process_idle():
	velocity = Vector2.ZERO
	
	if is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		
		# 這裡加入判斷：如果在感知範圍內，且沒有牆壁阻擋視線(選用)，切換狀態
		if dist < aggro_vision_range:
			# print("【AI】發現玩家！開始追擊 (CHASE)")
			current_state = State.CHASE

# 2. 追擊玩家邏輯 (A*)
func _process_chase(_delta):
	if not is_instance_valid(target_player): 
		current_state = State.RETURN_HOME
		return
		
	# A. 檢查是否離家太遠 (Leash Mechanic)
	if global_position.distance_to(home_position) > chase_radius:
		# print("【AI】離家太遠，回家 (RETURN_HOME)")
		current_state = State.RETURN_HOME
		return_cooldown = 2.0 # 【新增】設定 2 秒內不理會玩家
		return
	
	# B. 設定導航目標
	# 優化：不需要每一幀都設定 target_position，這很耗效能且容易造成路徑重算抖動
	# 我們用一個簡單的計數器或 Timer 來控制更新頻率，或者只在位置變動大時更新
	nav_agent.target_position = target_player.global_position
	
	# C. 檢查是否已經到達攻擊距離
	# 如果距離玩家夠近，就不用再走了，準備攻擊或停下
	# 這裡設定 30 像素作為「碰觸距離」
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		# 可以在這裡加入普通攻擊邏輯
	else:
		# 執行移動
		_move_via_nav(normal_speed)

# 3. 回家邏輯 (A*)
func _process_return_home(_delta):
	nav_agent.target_position = home_position
	
	# 印出剩餘距離
	var dist = global_position.distance_to(home_position)
	# print("【DEBUG】離家距離: ", dist) 
	
	# 這裡如果不使用 navigation_finished，改用手動距離判斷會更準確
	if dist < 10.0: # 如果距離小於 10 像素，視為到家
		if current_state != State.IDLE:
			# print("【AI】已回到家 (IDLE)")
			current_state = State.IDLE
			velocity = Vector2.ZERO
	else:
		_move_via_nav(return_speed)

# 輔助：通用導航移動 (關鍵修正)
func _move_via_nav(speed: float):
	# 如果導航還沒準備好，不要動 (避免報錯或原地抖動)
	if nav_agent.is_navigation_finished():
		return

	var next_pos = nav_agent.get_next_path_position()
	var current_pos = global_position
	
	# 計算方向
	var dir = current_pos.direction_to(next_pos)
	
	# 【新增】防卡死機制
	# 如果下一個導航點離自己太近 (例如小於 1 像素)，可能是導航網格的誤差
	# 強制給一個往家的方向，或者直接忽略這一幀
	if current_pos.distance_to(next_pos) < 1.0:
		# 如果卡住了，嘗試直接往 target_position (家/玩家) 走一步
		dir = current_pos.direction_to(nav_agent.target_position)
	
	velocity = dir * speed
	
	# 轉向與移動
	if dir.x != 0: sprite.flip_h = dir.x < 0
	move_and_slide()
	_check_contact_damage()


# ==========================================================
#      聽覺處理系統 (Hearing System)
# ==========================================================

func _on_sound_heard(source_pos: Vector2, sound_range: float, _type: String):
	if current_state == State.DEAD: return
	
	# 1. 檢查是否在衝刺鎖定或暈眩狀態 (無視聲音)
	if current_state == State.DASHING or current_state == State.IMPACT or current_state == State.STUNNED:
		return
		
	# 2. 檢查是否在怪物的聽力極限內
	var dist_to_monster = global_position.distance_to(source_pos)
	if dist_to_monster > hearing_range: 
		return # 太遠聽不到
		
	# 3. 檢查是否在聲音傳播範圍內
	if dist_to_monster > sound_range:
		return # 沒覆蓋到我

	# --- 決策：該不該切換目標？ ---
	
	# 情況 A: 正在蓄力前搖 (PREPARE_DASH)
	if current_state == State.PREPARE_DASH:
		# 比較新聲音與舊目標的距離，如果新聲音更近，切換過去
		var dist_to_old_target = global_position.distance_to(current_target_sound_pos)
		if dist_to_monster < dist_to_old_target:
			# print("聽到更近的聲音！切換目標！")
			start_dash_sequence(source_pos) # 重新啟動序列 (會 kill 掉舊的 tween)
		return

	# 情況 B: 普通狀態 (IDLE, CHASE, RETURN) -> 直接觸發
	# print("聽到聲音，準備衝刺！")
	start_dash_sequence(source_pos)

# ==========================================================
#      攻擊序列 (Attack Sequence)
# ==========================================================

func start_dash_sequence(target_pos: Vector2):
	current_state = State.PREPARE_DASH
	current_target_sound_pos = target_pos # 記錄下來供比較用
	velocity = Vector2.ZERO
	
	if _tween: _tween.kill()
	_tween = create_tween()
	
	# 1. 轉向目標
	if target_pos.x < global_position.x: sprite.flip_h = true
	else: sprite.flip_h = false
	
	# 2. 蓄力前搖 (變扁變紅) - 0.4秒
	_tween.tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(sprite, "modulate", Color(2, 0.5, 0.5), 0.4)
	
	# 3. 計算實際衝刺終點 (RayCast 防穿牆)
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, target_pos)
	query.collision_mask = 1 # 設定為 World Layer
	var result = space_state.intersect_ray(query)
	var final_pos = result.position if result else target_pos
	
	# 計算衝刺時間
	var dist = global_position.distance_to(final_pos)
	var dash_time = min(dist / dash_speed, dash_duration)
	
	SoundManager.play_spatial_sfx("enemy_dash", global_position, 0.0, 0.1)
	
	# 4. 衝刺階段 (DASHING)
	_tween.chain().tween_callback(func(): current_state = State.DASHING)
	
	# 拉長身體
	_tween.parallel().tween_property(sprite, "scale", Vector2(1.6, 0.6), 0.1)
	# 移動
	_tween.parallel().tween_property(self, "global_position", final_pos, dash_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	# 5. 接續震盪
	_tween.chain().tween_callback(_perform_impact)

func _perform_impact():
	current_state = State.IMPACT
	
	# 視覺復原
	sprite.scale = Vector2.ONE
	sprite.modulate = Color.WHITE
	
	# 震盪波特效
	shockwave_visual.visible = true
	shockwave_visual.scale = Vector2.ZERO
	shockwave_visual.modulate.a = 1.0
	SoundManager.play_spatial_sfx("enemy_shock", global_position, 0.0, 0.1)
	
	var impact_tween = create_tween()
	impact_tween.set_parallel(true)
	impact_tween.tween_property(shockwave_visual, "scale", Vector2(3.5, 3.5), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	impact_tween.tween_property(shockwave_visual, "modulate:a", 0.0, 0.3)
	
	# 造成範圍傷害
	shockwave_area.monitoring = true
	await get_tree().create_timer(0.1).timeout
	
	var bodies = shockwave_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(impact_damage, global_position, 400) # 強擊退
	
	shockwave_area.monitoring = false
	
	# 6. 暈眩/硬直 (STUNNED)
	current_state = State.STUNNED
	await get_tree().create_timer(1.2).timeout
	
	# 恢復正常
	if current_state != State.DEAD:
		current_state = State.IDLE

# ==========================================================
#      通用功能 (Damage, Death)
# ==========================================================

func _check_contact_damage():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider.is_in_group("player") and collider.has_method("take_damage"):
			collider.take_damage(contact_damage, global_position, 150)

func take_damage(amount, source_pos, _knockback = 0):
	if current_state == State.DEAD: return
	
	hp -= amount
	
	# 受傷閃爍
	var t = create_tween()
	t.tween_property(sprite, "modulate", Color(10, 10, 10), 0.05)
	t.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	
	# 擊退 (衝刺中霸體)
	if current_state != State.DASHING and current_state != State.IMPACT:
		velocity = (global_position - source_pos).normalized() * 150
		move_and_slide()
	
	if current_state == State.RETURN_HOME:
		current_state = State.CHASE
	
	if hp <= 0:
		die()

func die():
	current_state = State.DEAD
	velocity = Vector2.ZERO
	if _tween: _tween.kill()
	
	# 死亡動畫
	var dt = create_tween()
	dt.set_parallel(true)
	dt.tween_property(sprite, "rotation_degrees", 720.0, 0.6)
	dt.tween_property(sprite, "scale", Vector2.ZERO, 0.6)
	dt.tween_property(sprite, "modulate", Color.BLACK, 0.6)
	dt.chain().tween_callback(queue_free)
