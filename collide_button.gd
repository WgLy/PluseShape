extends Node2D

# --- 1. 參數設定 ---
@export var target_door: Node2D  # 請在 Inspector 把要控制的門拖進來

# --- 內部變數 ---
var is_pressed: bool = false
var release_timer: Timer  # 用程式碼建立的計時器
var current_tween: Tween  # 動畫控制器

# 取得子節點
@onready var button_body: CharacterBody2D = $collidebutton
@onready var detect_area: Area2D = $DetectArea

func _ready() -> void:
	# 1. 初始化計時器 (用於延遲 1 秒釋放)
	release_timer = Timer.new()
	release_timer.wait_time = 1.0 # 延遲一秒
	release_timer.one_shot = true # 只執行一次
	release_timer.timeout.connect(_on_release_timeout)
	add_child(release_timer)
	
	if target_door:
		# 強制覆蓋 Door 的設定，符合你的需求
		target_door.is_automatically_open = false
		target_door.is_locked = false
		target_door.close_door()
	
	# 2. 確保按鈕初始狀態是正常的
	button_body.scale = Vector2(1, 1)

# --- 偵測邏輯 ---

func _on_detect_area_body_entered(body: Node2D) -> void:
	# 檢查是否為有效觸發物 (玩家 或 石頭)
	if is_valid_body(body):
		# 如果計時器正在倒數(準備彈起)，立刻取消，因為有東西又壓上來了
		if not release_timer.is_stopped():
			release_timer.stop()
		
		# 如果還沒按下，就執行按下動作
		if not is_pressed:
			press_button()

func _on_detect_area_body_exited(body: Node2D) -> void:
	if is_valid_body(body):
		# 離開時，必須檢查「範圍內是否還有其他有效物體」
		# 例如：玩家離開了，但石頭還壓在上面，那就不應該彈起
		if not has_any_valid_body_inside():
			# 範圍內空了，開始倒數 1 秒準備彈起
			release_timer.start()

# --- 動作邏輯 ---

func press_button():
	is_pressed = true
	
	# 1. 播放壓縮動畫 (Scale Y 變成 0.4)
	play_tween(Vector2(1, 0.4))
	
	# 2. 開門
	if target_door:
		target_door.open_door() # 假設門有這個函式

func _on_release_timeout():
	# 計時器時間到，確認真的要釋放
	is_pressed = false
	
	# 1. 播放回彈動畫 (Scale Y 變回 1.0)
	play_tween(Vector2(1, 1.0))
	
	# 2. 關門
	if target_door:
		target_door.close_door()

# --- 輔助函式 ---

# 統一管理縮放動畫
func play_tween(target_scale: Vector2):
	if current_tween:
		current_tween.kill()
	
	current_tween = create_tween()
	# 使用 Elastic 或 Bounce 增加按鈕的質感
	current_tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(button_body, "scale", target_scale, 0.2)

# 判斷什麼東西可以觸發按鈕
func is_valid_body(body: Node2D) -> bool:
	# 判斷邏輯：名字是 Player 或是處於 "pushable" 群組的物件 (石頭)
	# 建議把你的石頭場景加入一個叫 "pushable" 或 "rock" 的 Group
	return body.name == "Player" or body.is_in_group("pushable") or body.name.contains("Rock")

# 檢查 DetectArea 內是否還有剩餘的有效物體
func has_any_valid_body_inside() -> bool:
	var bodies = detect_area.get_overlapping_bodies()
	for b in bodies:
		if is_valid_body(b):
			return true
	return false
