extends CharacterBody2D

# --- 0. 資源預載 ---
const CRYSTAL_SCENE = preload("res://BOSS_chapter1/crystal.tscn")
const BULLET_SCENE = preload("res://BOSS_chapter1/boss_bullet.tscn")
# 如果有落石模板，請在場景中指定，或使用 export
@export var fall_rock_template: Node2D 

# --- 1. 屬性設定 ---
@export_group("Stats")
@export var max_hp: int = 500
@export var default_orbit_radius: float = 40.0 # 拳頭預設半徑
@export var default_orbit_speed: float = 2.0    # 平常公轉速度 (rad/s)

# --- 內部變數 ---
var current_hp: int
var is_invincible: bool = false
var is_dead: bool = false
var target_player: Node2D = null # 需在 _ready 或戰鬥開始時獲取

# 軌道控制
var current_orbit_speed: float = 2.0
var active_crystals: Array = [] # 追蹤場上的水晶

# --- 節點參照 ---
@onready var main_sprite = $MainSprite
@onready var orbital_pivot = $OrbitalPivot
@onready var fist_holder = $OrbitalPivot/FistHolder
@onready var fist_hitbox = $OrbitalPivot/FistHolder/FistHitbox
@onready var shield_visual = $ShieldVisual
@onready var entity_container = $EntityContainer
@onready var danmaku_spawn_point = $DanmakuSpawnPoint

# --- 初始化 ---
func _ready() -> void:
	current_hp = max_hp
	current_orbit_speed = default_orbit_speed
	
	# 初始化拳頭位置
	fist_holder.position = Vector2(default_orbit_radius, 0)
	fist_hitbox.monitoring = false # 平常拳頭不造成傷害
	shield_visual.visible = false
	
	# 尋找玩家 (假設玩家在 Group "player")
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target_player = players[0]

func _physics_process(delta: float) -> void:
	if is_dead: return
	
	# 1. 處理拳頭公轉
	orbital_pivot.rotation += current_orbit_speed * delta

	# 2. 處理本體移動 (如果有 velocity)
	move_and_slide()

# --- 受到傷害介面 ---
func take_damage(amount, _source_pos = Vector2.ZERO, _level = 0):
	if is_dead: return
	
	if is_invincible:
		# 這裡可以播放 "叮" 一聲的防禦音效
		flash_shield()
		return
	
	current_hp -= amount
	flash_body()
	print("BOSS HP:", current_hp)
	
	if current_hp <= 0:
		die()

# =========================================
#      技能實作 (API Functions)
# =========================================

# 1. 移動 (Move To)
func move_to(target_pos: Vector2, duration: float, mode: String = "Slide"):
	if is_dead: return
	
	var tween = create_tween()
	
	match mode:
		"Teleport":
			# 縮小 -> 瞬移 -> 放大
			tween.tween_property(self, "scale", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tween.tween_callback(func(): global_position = target_pos)
			tween.tween_interval(0.1)
			tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			
		"Slide":
			# 平滑移動
			tween.tween_property(self, "global_position", target_pos, duration).set_trans(Tween.TRANS_SINE)
		
		"Dash":
			# 蓄力後衝刺
			tween.tween_property(main_sprite, "scale", Vector2(0.8, 1.2), 0.2) # 擠壓
			tween.tween_property(self, "global_position", target_pos, duration * 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(main_sprite, "scale", Vector2.ONE, 0.2)

# 2. 召喚敵人 (Summon Enemy)
func summon_enemy(enemy_scene: PackedScene, spawn_pos: Vector2, anim_duration: float, health: int):
	if is_dead: return
	
	# 階段 A: 召喚特效 (魔法陣)
	# 這裡先用簡單的 ColorRect 模擬，實際上可以用 Sprite
	var indicator = Sprite2D.new()
	# indicator.texture = ... (設定你的魔法陣圖)
	indicator.global_position = spawn_pos
	indicator.scale = Vector2.ZERO
	entity_container.add_child(indicator)
	
	var tween = create_tween()
	tween.tween_property(indicator, "scale", Vector2(1, 1), anim_duration)
	tween.tween_property(indicator, "modulate:a", 0.0, 0.2) # 淡出
	
	await tween.finished
	indicator.queue_free()
	
	# 階段 B: 生成實體
	if enemy_scene:
		var enemy = enemy_scene.instantiate()
		enemy.global_position = spawn_pos
		# 假設敵人腳本有 max_hp 屬性
		if "max_hp" in enemy:
			enemy.max_hp = health
			enemy.current_hp = health # 如果有這個變數
		entity_container.add_child(enemy)

# 3. 落石攻擊 (Fall Rock)
func fall_rock_attack(target: Node2D, size: float, warn_time: float, fall_time: float, dmg: int):
	if is_dead: return
	if fall_rock_template and fall_rock_template.has_method("spawn_fall_rock"):
		fall_rock_template.spawn_fall_rock(target, size, warn_time, fall_time, dmg)
	else:
		print("錯誤：尚未指派 FallRockTemplate！")

# 4. 水晶無敵陣 (Crystal Set - Core Mechanic)
func crystal_set(pos_list: Array, regen_time: float, crystal_hp: int):
	if is_dead: return
	
	# 清除舊水晶 (如果有的話)
	clear_crystals_only()
	
	# 生成新水晶
	for pos in pos_list:
		var crystal = CRYSTAL_SCENE.instantiate()
		crystal.global_position = pos
		crystal.regenerate_time = regen_time
		crystal.max_hp = crystal_hp
		crystal.mode = 1 # Mode.BOSS_FIGHT
		
		# 連接狀態改變訊號
		crystal.state_changed.connect(_on_crystal_state_changed)
		
		entity_container.add_child(crystal)
		active_crystals.append(crystal)
	
	# 啟動無敵
	set_invincible(true)
	# 強制檢查一次狀態 (確保初始狀態正確)
	_on_crystal_state_changed(false)

# 訊號回調：檢查水晶狀態
func _on_crystal_state_changed(_dummy_bool):
	# 檢查場上所有水晶，只要有 "一個" 是 ACTIVE，護盾就存在
	# 如果 "全部" 都是 BROKEN，護盾消失
	
	var all_broken = true
	for crystal in active_crystals:
		# 假設水晶腳本有 current_state 屬性, State.BROKEN = 1
		if crystal.current_state == 0: # State.ACTIVE
			all_broken = false
			break
	
	if all_broken:
		set_invincible(false)
		# 可以在這裡加入 BOSS 暈眩動畫
		print("護盾破碎！BOSS 可被攻擊！")
	else:
		set_invincible(true)

# 5. 旋轉攻擊 (Rotate Attack - 大風車)
func rotate_attack(spin_speed: float, damage: int, final_pos: Vector2):
	if is_dead: return
	
	set_invincible(true)
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# A. 移動本體
	tween.tween_property(self, "global_position", final_pos, 1.0).set_trans(Tween.TRANS_QUAD)
	
	# B. 拳頭伸長 (擴大攻擊範圍)
	tween.tween_property(fist_holder, "position:x", default_orbit_radius * 1.5, 0.5)
	
	# C. 加速旋轉
	# 使用 tween_method 平滑改變數值
	tween.tween_method(func(val): current_orbit_speed = val, default_orbit_speed, spin_speed, 1.0)
	
	# D. 開啟傷害判定
	fist_hitbox.monitoring = true
	# 這裡假設 FistHitbox 有腳本負責造成傷害，或者我們在 _process 裡檢測
	# 為了簡單，我們可以用 Area2D 的 body_entered 訊號連接
	
	# 持續旋轉一段時間 (例如 3 秒)
	tween.chain().tween_interval(3.0)
	
	# E. 結束與恢復
	tween.chain().set_parallel(true)
	tween.tween_method(func(val): current_orbit_speed = val, spin_speed, default_orbit_speed, 1.0) # 減速
	tween.tween_property(fist_holder, "position:x", default_orbit_radius, 1.0) # 收拳
	
	tween.chain().tween_callback(func(): 
		set_invincible(false)
		fist_hitbox.monitoring = false
	)

# 6. 蓄力重拳 (Charge Up Slam)
func charge_up_slam(charge_time: float, damage: int, scale_factor: float):
	if is_dead or not target_player: return
	
	# 1. 鎖定目標角度
	var dir_to_player = global_position.direction_to(target_player.global_position)
	var target_angle = dir_to_player.angle()
	
	# 暫停公轉
	current_orbit_speed = 0.0
	
	var tween = create_tween()
	
	# 2. 轉動軸心對準玩家 (最短路徑旋轉)
	# 這裡簡單處理，直接轉過去
	tween.tween_property(orbital_pivot, "rotation", target_angle, 0.3)
	
	# 3. 蓄力 (拳頭後縮 + 變色)
	tween.parallel().tween_property(fist_holder, "position:x", default_orbit_radius * 0.5, charge_time).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(fist_holder, "modulate", Color(2, 0, 0), charge_time) # 變紅
	
	# 4. 揮拳 (瞬間伸長)
	tween.chain()
	tween.tween_callback(func(): fist_hitbox.monitoring = true) # 開啟判定
	tween.tween_property(fist_holder, "position:x", default_orbit_radius * 2.5, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# 加入震動 (Call Player's shake if defined)
	tween.tween_callback(func(): 
		if target_player.has_method("start_tremble"): target_player.start_tremble(5.0, 0.2)
	)
	
	# 5. 收招
	tween.chain().tween_interval(0.2)
	tween.chain().tween_callback(func(): fist_hitbox.monitoring = false) # 關閉判定
	tween.tween_property(fist_holder, "position:x", default_orbit_radius, 0.5)
	tween.parallel().tween_property(fist_holder, "modulate", Color.WHITE, 0.5)
	
	# 6. 恢復公轉
	tween.tween_callback(func(): current_orbit_speed = default_orbit_speed)

# 7. 彈幕射擊 (額外補充)
# 7. 彈幕射擊 (多模式版)
# mode: "Ring", "Shotgun", "Spiral", "Random", "Sniper"
# extra_param: 
#   - Shotgun: 扇形總角度 (例如 60度)
#   - Spiral: 旋轉增量 (每次轉幾度)
# 7. 彈幕射擊 (加入前搖版)
# charge_time: 前搖蓄力時間 (秒)
func shoot_danmaku(mode: String, count: int, speed: float, extra_param: float = 0.0, charge_time: float = 0.5):
	if is_dead: return
	
	# --- 1. 播放前搖動畫並等待 ---
	# 如果 charge_time > 0，就執行聚氣演出
	if charge_time > 0:
		await _play_charge_anim(charge_time)
	
	# 再次檢查是否死亡 (避免蓄力途中被打死，結果屍體還發射子彈)
	if is_dead: return

	# --- 2. 原本的發射邏輯 (保持不變) ---
	match mode:
		"Ring":
			# --- [環形] 同時向四周發射 ---
			for i in range(count):
				var angle = (TAU / count) * i
				var dir = Vector2(cos(angle), sin(angle))
				_spawn_single_bullet(dir, speed)
		
		"Shotgun":
			# --- [散彈] 朝向玩家發射扇形 ---
			if not target_player: return
			
			# 計算朝向玩家的中心角度
			var dir_to_player = danmaku_spawn_point.global_position.direction_to(target_player.global_position)
			var center_angle = dir_to_player.angle()
			
			# 計算扇形起始角度 (將度數轉為弧度)
			var spread_rad = deg_to_rad(extra_param if extra_param > 0 else 60.0)
			var start_angle = center_angle - (spread_rad / 2.0)
			var step_angle = spread_rad / (count - 1) if count > 1 else 0
			
			for i in range(count):
				var current_angle = start_angle + (step_angle * i)
				var dir = Vector2(cos(current_angle), sin(current_angle))
				_spawn_single_bullet(dir, speed)

		"Spiral":
			# --- [螺旋] 旋轉發射 (修正版) ---
			var tween = create_tween()
			var spin_step = deg_to_rad(extra_param if extra_param != 0 else 15.0)
			var start_angle = 0.0
			
			# 1. 決定起始角度
			if target_player:
				start_angle = danmaku_spawn_point.global_position.direction_to(target_player.global_position).angle()
			
			# 2. 使用 for 迴圈預先排程所有子彈
			for i in range(count):
				# 【關鍵】直接算好這一發子彈的固定角度
				var current_angle = start_angle + (spin_step * i)
				var dir = Vector2(cos(current_angle), sin(current_angle))
				
				# 3. 加入排程：發射 -> 等待
				# 使用 .bind() 將算好的 dir 數值直接綁定進去，確保數值正確
				tween.tween_callback(_spawn_single_bullet.bind(dir, speed))
				tween.tween_interval(0.05) # 發射間隔

		"Random":
			# --- [隨機] 朝四面八方亂射 ---
			# 也加一點時間間隔比較有感
			var tween = create_tween()
			tween.set_loops(count)
			tween.tween_callback(func():
				var random_angle = randf() * TAU
				var dir = Vector2(cos(random_angle), sin(random_angle))
				_spawn_single_bullet(dir, speed)
			)
			tween.tween_interval(0.02) # 射速極快
			
		"Sniper":
			# --- [狙擊] 快速單發或連發朝向玩家 ---
			if not target_player: return
			
			var tween = create_tween()
			tween.set_loops(count)
			tween.tween_callback(func():
				# 每次發射都重新瞄準 (追蹤效果)
				if target_player: 
					var dir = danmaku_spawn_point.global_position.direction_to(target_player.global_position)
					# 加一點點隨機偏移，才不會每一發都重疊
					var offset = randf_range(-0.05, 0.05)
					dir = dir.rotated(offset)
					_spawn_single_bullet(dir, speed * 1.5) # 狙擊通常比較快
			)
			tween.tween_interval(0.15)
		
func _spawn_single_bullet(direction: Vector2, speed: float, mode: int = 0, extra: float = 0.0):
	var bullet = BULLET_SCENE.instantiate()
	entity_container.add_child(bullet)
	
	var start_pos = danmaku_spawn_point.global_position if danmaku_spawn_point else global_position
	
	# 傳遞新的模式參數
	bullet.setup(start_pos, direction, speed, 10, mode, extra)

# =========================================
#      輔助與狀態管理
# =========================================

func set_invincible(state: bool):
	is_invincible = state
	shield_visual.visible = state
	# 可以在這裡改變盾牌的透明度或播放音效

func flash_body():
	var tween = create_tween()
	tween.tween_property(main_sprite, "modulate", Color(10, 10, 10), 0.05)
	tween.tween_property(main_sprite, "modulate", Color.WHITE, 0.1)

func flash_shield():
	var tween = create_tween()
	tween.tween_property(shield_visual, "modulate:a", 0.5, 0.05)
	tween.tween_property(shield_visual, "modulate:a", 1.0, 0.1)

func clear_all_entities():
	# 清除 EntityContainer 底下的所有東西 (水晶、子彈、小怪)
	for child in entity_container.get_children():
		child.queue_free()
	active_crystals.clear()
	set_invincible(false) # 強制關閉無敵

func clear_crystals_only():
	for crystal in active_crystals:
		if is_instance_valid(crystal):
			crystal.queue_free()
	active_crystals.clear()

# --- 內部輔助：播放蓄力特效 ---
func _play_charge_anim(duration: float):
	# 1. 建立一個臨時的 Sprite 來做特效
	# 我們可以直接借用子彈的圖片，或是用一個簡單的方塊/圓形
	var charge_vfx = Sprite2D.new()
	
	# 嘗試從 Bullet 場景中獲取圖片，如果沒有就用預設的
	# 這裡為了方便，你可以直接 assign 你專案裡的某個光球圖片
	# 如果沒有圖片，我們用 Modulate 把一個白色方塊染成紅色
	charge_vfx.texture = preload("res://BOSS_chapter1/boss_bullet.tscn::Gradient_fu2kp")
	
	# 暫時解法：如果沒有特效圖，我們用 Godot 內建的 PlaceholderTexture2D (白色小方塊)
	# var placeholder = PlaceholderTexture2D.new()
	# placeholder.size = Vector2(32, 32)
	# charge_vfx.texture = placeholder
	
	# 設定位置
	entity_container.add_child(charge_vfx)
	charge_vfx.global_position = danmaku_spawn_point.global_position
	
	# --- 2. 設定動畫 Tween ---
	var tween = create_tween()
	tween.set_parallel(true)
	
	# A. 視覺：從大變小 (匯聚感) + 旋轉
	charge_vfx.scale = Vector2(3.0, 3.0) # 起始很大
	charge_vfx.modulate = Color(2, 0.5, 0.5, 0) # 起始：亮紅色、透明
	
	tween.tween_property(charge_vfx, "scale", Vector2(0.5, 0.5), duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(charge_vfx, "rotation", deg_to_rad(180), duration)
	tween.tween_property(charge_vfx, "modulate:a", 1.0, duration * 0.5) # 淡入
	
	# B. 本體：稍微變色 (提示玩家 BOSS 要出招了)
	tween.tween_property(main_sprite, "modulate", Color(1.5, 0.8, 0.8), duration * 0.5) # 變紅亮
	
	# --- 3. 等待動畫結束 ---
	await tween.finished
	
	# --- 4. 清理 ---
	charge_vfx.queue_free()
	main_sprite.modulate = Color.WHITE # 恢復本體顏色
# =========================================
#      死亡邏輯
# =========================================

func die():
	is_dead = true
	set_invincible(true) # 防止鞭屍
	current_orbit_speed = 0 # 停止公轉
	
	# 1. 清除場上垃圾
	clear_all_entities()
	
	# 2. 死亡動畫 (內爆 -> 碎裂)
	var tween = create_tween()
	
	# 內爆
	tween.tween_property(main_sprite, "scale", Vector2(0.1, 0.1), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(fist_holder, "scale", Vector2.ZERO, 0.5) # 拳頭也消失
	
	# 爆炸 (這裡若有 DeathParticles 節點更好)
	tween.chain().tween_callback(func():
		main_sprite.visible = false
		fist_holder.visible = false
		# TODO: Play Particle Effect Here
		print("BOSS DEFEATED")
	)
	
	# 3. 可以在這裡呼叫 Game Manager 結束關卡

func _on_fist_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(20, global_position, 500) # 傷害 20, 擊退力 500


# =========================================
#      測試用輸入 (Debug Input)
# =========================================
func _input(event: InputEvent) -> void:
	# 建議加上這個檢查，確保只有在編輯器測試時有效，避免發布後玩家誤觸
	if not OS.is_debug_build(): return
	
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_G:
				print("【測試】G鍵：蓄力重拳 (Charge Slam)")
				# 蓄力 1秒，傷害 20，縮放 1.0
				charge_up_slam(1.0, 20, 1.0)
				
			KEY_H:
				print("【測試】H鍵：旋轉攻擊 (Rotate Attack)")
				# 轉速 15，傷害 15，移動到稍微偏左的位置測試位移
				var target_pos = global_position + Vector2(100, 0) 
				rotate_attack(15.0, 15, target_pos)
				
			KEY_J:
				print("【測試】J鍵：水晶無敵陣 (Crystal Set)")
				# 在 BOSS 周圍三角形排列生成 3 顆水晶
				var offset = 200.0
				var positions = [
					global_position + Vector2(0, -offset),         # 上
					global_position + Vector2(offset, offset),     # 右下
					global_position + Vector2(-offset, offset)     # 左下
				]
				# 重生時間 5秒，血量 3
				crystal_set(positions, 5.0, 3)
				
			KEY_K:
				print("【測試】K鍵：落石攻擊 (Fall Rock)")
				if target_player:
					# 針對玩家頭上丟石頭
					fall_rock_attack(target_player, 1.5, 1.0, 0.5, 20)
				else:
					print("錯誤：找不到 Target Player，無法測試落石")
					
			KEY_L:
				# 這裡我寫成隨機切換模式，讓你按 L 就能看到不同效果
				var modes = ["Ring", "Shotgun", "Spiral", "Random", "Sniper"]
				var pick = modes.pick_random()
				print("【測試】彈幕模式：", pick)
				
				match pick:
					"Ring":
						shoot_danmaku("Ring", 18, 50) # 18發環形
					"Shotgun":
						shoot_danmaku("Shotgun", 5, 150, 45) # 5發，扇形45度
					"Spiral":
						shoot_danmaku("Spiral", 30, 130, 20) # 30發，每次旋轉20度
					"Random":
						shoot_danmaku("Random", 10, 80) # 10發亂射
					"Sniper":
						shoot_danmaku("Sniper", 3, 150) # 3發高速狙擊

			KEY_SEMICOLON: # 分號鍵 (在 L 的右邊)
				print("【測試】重置：清除所有實體")
				clear_all_entities()
