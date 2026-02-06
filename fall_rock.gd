extends Node2D

@export var image1: Sprite2D
@export var image2: Sprite2D
@onready var detect_area: Area2D = $DetectArea
@export var des_obj_scene: PackedScene
var sonar_scene = preload("res://sonar_pulse.tscn")


# 內部變數 (僅供複製品使用)
var _target_player: Node2D = null
var _is_following: bool = false
var _damage: int = 0

var smoke_effect = preload("res://smoke_effect.tscn")

func _ready() -> void:
	# 初始狀態：如果這不是複製品（是模板本身），先隱藏起來
	# 透過檢查是否在場景樹中剛被生成來判斷，這裡簡單預設隱藏
	# 實際運作由 spawn 控制
	pass

func _process(delta: float) -> void:
	# 只有在「跟隨階段」且「目標有效」時才移動
	if _is_following and is_instance_valid(_target_player):
		global_position = _target_player.global_position

# --- [主要接口] 生成落石 ---
# 呼叫此函式來生成一個落石攻擊
# target: 目標玩家 (Node2D)
# size_scale: 大小倍率 (float)
# warning_time: 預警時間 (秒)
# fall_time: 下落時間 (秒)
# damage_amount: 傷害數值 (int)
func spawn_fall_rock(target: Node2D, size_scale: float, warning_time: float, fall_time: float, damage_amount: int = 10, add_des_object: bool = true):
	# 1. 複製自己 (Generate a duplicate)
	var new_rock = self.duplicate()
	
	# 2. 將複製品加入場景 (加到當前節點的父節點，通常是 World 或 Level)
	get_parent().add_child(new_rock)
	
	# 3. 初始化複製品的位置與狀態
	new_rock.global_position = target.global_position
	new_rock.visible = true # 確保複製品是看得到的
	
	# 4. 啟動落石生命週期 (呼叫複製品的函式)
	new_rock._start_lifecycle(target, size_scale, warning_time, fall_time, damage_amount, add_des_object)

# --- [內部邏輯] 落石生命週期 (由複製品執行) ---
func _start_lifecycle(target: Node2D, size_scale: float, warn_time: float, fall_time: float, dmg: int, add_des_object: bool):
	_target_player = target
	_damage = dmg
	
	# 設定大小
	scale = Vector2(size_scale, size_scale)
	
	# --- 階段 1: 預警 (Warning Phase) ---
	_is_following = true # 開始跟隨
	image1.visible = true
	image1.modulate.a = 0.0 # 重置透明度
	image2.visible = false # 石頭先隱藏
	
	# 動畫: Sprite2D (預警圈) 淡入
	var tween = create_tween()
	tween.tween_property(image1, "modulate:a", 1.0, warn_time)
	
	# 等待預警時間結束
	await get_tree().create_timer(warn_time).timeout
	
	# --- 階段 2: 下落 (Falling Phase) ---
	_is_following = false # 停止跟隨 (鎖定位置)
	
	image2.visible = true
	image2.scale = Vector2.ZERO # 從 0 開始
	
	# 動畫: Sprite2D2 (石頭) 放大至原本大小 (Vector2.ONE 因為父節點已經縮放過了)
	# 使用 Ease In 模擬重力加速感
	var tween_fall = create_tween()
	tween_fall.tween_property(image2, "scale", Vector2.ONE, fall_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# 等待下落時間結束
	await get_tree().create_timer(fall_time).timeout
	
	# --- 階段 3: 撞擊 (Impact Phase) ---
	_check_impact()
	fire_sonar()
	if add_des_object and des_obj_scene: # 多加一個檢查確保 scene 不是空的
		var new_des_obj = des_obj_scene.instantiate()
		get_parent().add_child(new_des_obj)
		new_des_obj.global_position = global_position
		new_des_obj.visible = true
		new_des_obj.scale = Vector2(0.5, 0.5)
	elif add_des_object and not des_obj_scene:
		print("警告: 嘗試生成 des_obj 但 des_obj_scene 未設定！")

# --- 撞擊檢測 ---
func _check_impact():
	# 播放震動與傷害邏輯
	var hit_player = false
	
	# 檢查 DetectArea 內是否有玩家
	var bodies = detect_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("player"): # 或是 body == _target_player
			hit_player = true
			break
	
	if hit_player:
		# 砸中玩家
		if _target_player.has_method("take_damage"):
			_target_player.take_damage(_damage, global_position, 100)
		if _target_player.has_method("start_tremble"):
			_target_player.start_tremble(10.0, 2.0, true) # 強震動 (強度參數請依你遊戲調整)
		print("落石命中玩家！造成傷害: ", _damage)
	else:
		# 沒砸中 (只震動)
		if is_instance_valid(_target_player) and _target_player.has_method("start_tremble"):
			_target_player.start_tremble(5.0, 1.0, false) # 弱震動
		print("落石未命中")

	# 任務完成，刪除這個複製品
	# 可以先播個爆炸特效再 queue_free
	if smoke_effect:
		var smoke = smoke_effect.instantiate()
		smoke.global_position = global_position # 設定在落石的位置
		
		# 重要：將煙霧加到父節點 (World)，而不是加給自己
		# 這樣落石消失後，煙霧還能留在場上播完動畫
		get_parent().add_child(smoke)
	
	queue_free()

func fire_sonar():
	var pulse = sonar_scene.instantiate()
	pulse.global_position = global_position
	get_tree().root.add_child(pulse)
