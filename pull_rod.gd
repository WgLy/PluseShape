extends Node2D

# --- 1. 參數設定 ---
@export var initial_state: bool = false  # true = 開(135度), false = 關(45度)
@export var target_door: Node2D          # 請在 Inspector 中把要控制的 Door 節點拖進來

# --- 內部變數 ---
var is_active: bool = false      # 目前拉桿狀態
var can_interact: bool = false   # 玩家是否在範圍內
@onready var rod: Node2D = $rod  # 取得轉動的拉桿部分

func _ready() -> void:
	# 初始化狀態
	is_active = initial_state
	
	# 1. 設定拉桿初始角度 (瞬間設定，不播動畫)
	if is_active:
		rod.rotation_degrees = 135
	else:
		rod.rotation_degrees = 45
	
	# 2. 接管並設定門的狀態
	if target_door:
		# 強制覆蓋 Door 的設定，符合你的需求
		target_door.is_automatically_open = false
		target_door.is_locked = false
		
		# 同步門的開關狀態
		# 雖然 Door 的 _ready 會先執行 reset，但這裡呼叫會覆蓋它
		if is_active:
			target_door.open_door()
		else:
			target_door.close_door()

func _input(event: InputEvent) -> void:
	# 偵測輸入：按下空白鍵 且 玩家在範圍內
	if event.is_action_pressed("ui_accept") and can_interact:
		toggle_state()

func toggle_state() -> void:
	# 切換狀態
	is_active = not is_active
	
	# --- A. 播放拉桿動畫 ---
	var tween = create_tween()
	var target_angle = 135.0 if is_active else 45.0
	
	# 使用 TRANS_BACK 或 TRANS_ELASTIC 可以做出機械的回彈感
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(rod, "rotation_degrees", target_angle, 0.3)
	
	# --- B. 控制門 ---
	if target_door:
		if is_active:
			target_door.open_door()
		else:
			target_door.close_door()

# --- 訊號連接 (請記得在編輯器連接 DetectArea 的訊號到這裡) ---

func _on_detect_area_body_entered(body: Node2D) -> void:
	if body.name == "Player": # 或是 body.is_in_group("player")
		can_interact = true
		# 這裡可以加入顯示 "按下空白鍵" UI 的邏輯

func _on_detect_area_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		can_interact = false
		# 這裡可以加入隱藏 UI 的邏輯
