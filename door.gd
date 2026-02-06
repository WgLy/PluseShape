extends Node2D

var is_open: bool = false
var is_automatically_open: bool = true
var is_locked: bool = false
@export var left : CharacterBody2D
@export var right : CharacterBody2D
@export var duration: float = 0.2 # 開關門需要的時間 (秒)

var current_tween: Tween # 用來儲存當前的動畫，防止衝突

func _ready() -> void:
	is_open = false
	# 確保初始狀態是關閉的
	reset_door()

func _on_detect_area_body_entered(body: Node2D) -> void:
	if body.name == "Player" and not is_locked and is_automatically_open:
		is_open = true
		open_door()

func _on_detect_area_body_exited(body: Node2D) -> void:
	if body.name == "Player" and is_automatically_open:
		is_open = false
		close_door()

# --- 開門邏輯 ---
func open_door():
	# 1. 如果有正在執行的動畫，先殺掉它，避免動作打架
	if current_tween:
		current_tween.kill()
	
	# 2. 建立新的 Tween
	current_tween = create_tween()
	
	# 3. 設定為平行執行 (set_parallel)，讓左右門、移動與縮放「同時」發生
	current_tween.set_parallel(true)
	
	# 4. 設定為線性 (Linear) 轉場 (雖然 Godot 預設就是線性，但寫出來比較明確)
	current_tween.set_trans(Tween.TRANS_LINEAR)
	
	# 5. 設定動畫目標值
	# Right Door: Pos -> (32, 0), Scale -> (0, 1)
	current_tween.tween_property(right, "position", Vector2(35, 0), duration)
	current_tween.tween_property(right, "scale", Vector2(0, 1), duration)
	
	# Left Door: Pos -> (-32, 0), Scale -> (0, 1)
	current_tween.tween_property(left, "position", Vector2(-35, 0), duration)
	current_tween.tween_property(left, "scale", Vector2(0, 1), duration)

# --- 關門邏輯 ---
func close_door():
	if current_tween:
		current_tween.kill()
	
	current_tween = create_tween()
	current_tween.set_parallel(true)
	current_tween.set_trans(Tween.TRANS_LINEAR)
	
	# 還原到初始狀態
	# Right Door: Pos -> (0, 0), Scale -> (1, 1)
	current_tween.tween_property(right, "position", Vector2(0, 0), duration)
	current_tween.tween_property(right, "scale", Vector2(1, 1), duration)
	
	# Left Door: Pos -> (0, 0), Scale -> (1, 1)
	current_tween.tween_property(left, "position", Vector2(0, 0), duration)
	current_tween.tween_property(left, "scale", Vector2(1, 1), duration)

# 瞬間重置 (用於 _ready)
func reset_door():
	if right:
		right.position = Vector2(0, 0)
		right.scale = Vector2(1, 1)
	if left:
		left.position = Vector2(0, 0)
		left.scale = Vector2(1, 1)
