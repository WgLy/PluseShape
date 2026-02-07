extends CharacterBody2D

signal picked_up(rock_instance) # 發出被撿起的訊號

enum State { IN_HAND, AIRBORNE, GROUNDED }
var current_state = State.IN_HAND

# 物理參數
var fly_speed = 0.0
var fly_direction = Vector2.ZERO
var friction = 2.0      # 摩擦力
var bounce_factor = 0.6 # 撞牆反彈係數
var stop_threshold = 10.0

# 偽 3D 高度參數 (只用於手持動畫)
var z_height = 0.0
var z_velocity = 0.0
var gravity = 980.0

# 撿拾相關變數
var player_in_area = null # 記錄玩家是否在撿拾範圍內
var can_interact

var sonar_scene = preload("res://sonar_pulse.tscn")

@onready var sprite = $Sprite2D
@onready var pickup_area = $PickupArea

# 落地撿拾系統
var is_grounded: bool = false
var grounded_time: float = 0.0

func _ready():
	pickup_area.monitoring = false
	z_index = 5 
	
	if current_state == State.IN_HAND:
		$CollisionShape2D.disabled = true
	
	can_interact = true

func _physics_process(delta):
	match current_state:
		State.IN_HAND:
			# 【手持動畫】原地垂直上拋 (保留這段，因為你想要手持時有鉛直上拋效果)
			z_velocity -= gravity * delta
			z_height += z_velocity * delta
			
			if z_height <= 0:
				z_height = 0
				z_velocity = 250.0 # 再次往上拋
			
			sprite.position.y = -z_height

		State.AIRBORNE:
			# 【修正點 2】直線飛行：這裡完全不再計算 z_height 與 gravity
			# 讓石頭緊貼地面滑行 (Ice Hockey Puck)
			
			velocity = fly_direction * fly_speed
			
			if move_and_slide():
				var collision_info = get_slide_collision(0)
				if collision_info:
					var normal = collision_info.get_normal()
					fly_direction = fly_direction.bounce(normal)
					fly_speed *= bounce_factor
					# 聽聲辨位系統
					GameEvent.create_noise(global_position, null, 300.0, "impact")
			
			fly_speed = lerp(fly_speed, 0.0, delta * friction)
			
			if fly_speed < stop_threshold:
				become_grounded()
				

		State.GROUNDED:
			velocity = Vector2.ZERO
			# 【修正點 1】撿拾邏輯
			### 測試對話使用
			if player_in_area and Input.is_action_just_pressed("ui_accept") and can_interact:
				can_interact = false
				# 1. 檢查對話管理器是否閒置 (避免重複觸發)
				if not DialogueManager.is_active:
					print("【DEBUG】條件成立，嘗試呼叫對話...")
					# 2. 開始對話
					DialogueManager.set_name_label("blingbling rock")
					DialogueManager.start_dialogue([
						"這是一顆普通的石頭...",
						"等等！它好像在發光？",
						"獲得了 [color=yellow]發光石[/color]！"
					])
					
					# 3. 【關鍵】等待對話結束訊號
					# 程式會暫停在這行，直到 DialogueManager 發出 dialogue_finished 訊號
					await DialogueManager.dialogue_finished
					
					# 4. 對話結束後，執行原本的撿起邏輯
					pick_up_stone()
		
		# 偵測落地：如果速度極低，視為落地
		# (假設你的石頭有重力或摩擦力會讓它停下來)
	if velocity.length() < 10.0:
		is_grounded = true
		grounded_time += delta
	else:
		is_grounded = false
		grounded_time = 0.0

# 發射函式
func launch(direction, power):
	current_state = State.AIRBORNE
	fly_direction = direction
	fly_speed = power * 150.0   
	
	# 強制歸零高度
	z_height = 0.0
	z_velocity = 0.0
	sprite.position.y = 0 
	
	# 開啟碰撞
	$CollisionShape2D.disabled = false
	
	# 【新增】記錄當前「看起來」的大小 (Global Scale)
	# 這樣可以確保不管父節點是誰，它看起來都一樣大
	var final_scale = global_scale
	
	# 脫離父節點
	var world = get_tree().root
	var global_pos = global_position
	if get_parent():
		get_parent().remove_child(self)
	world.add_child(self)
	
	global_position = global_pos
	
	# 【新增】應用剛才記錄的大小 (或是直接設為 Vector2.ONE)
	# 由於現在父節點是 World (Scale 1,1)，我們直接把 scale 設回 1 也可以
	# scale = final_scale # 這是最保險的寫法
	scale = Vector2.ONE # 如果你希望石頭飛出去永遠是標準大小，用這一行

func become_grounded():
	current_state = State.GROUNDED
	pickup_area.monitoring = true
	fly_speed = 0.0

func pick_up_stone():
	# 呼叫玩家的函式加石頭 (確保你的 player.gd 有 add_stone 這個函式)
	if player_in_area.has_method("add_stone"):
		player_in_area.add_stone()
		queue_free() # 銷毀地上的石頭

# --- 訊號連接區 (請確認這兩個訊號有連上) ---

func _on_pickup_area_body_entered(body):
	if body.name == "Player":
		player_in_area = body

func _on_pickup_area_body_exited(body):
	if body.name == "Player":
		player_in_area = null
		can_interact = true

# --- 聲納邏輯 ---
func _on_sonar_timer_timeout():
	if current_state != State.IN_HAND:
		emit_sonar()

func emit_sonar():
	var pulse = sonar_scene.instantiate()
	get_tree().root.add_child(pulse)
	pulse.global_position = global_position
	pulse.max_scale = 40.0 
	pulse.color = Color(1.0, 1.0, 1.0, 1.0)
	pulse.energy = 3

func save():
	return {
		"filename" : get_scene_file_path(),
		"parent" : get_parent().get_path(),
		"pos_x" : global_position.x,
		"pos_y" : global_position.y,
		# 石頭可能不需要存 HP，但如果它有特殊狀態(例如顏色)也要存
	}

# 給怪物呼叫的介面：石頭被怪物撿走了
func be_picked_up_by_enemy():
	# 可以在這裡播被吃掉的特效
	queue_free()
