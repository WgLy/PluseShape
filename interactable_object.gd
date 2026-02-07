extends Node2D

# --- 定義互動模式 ---
enum InteractionMode { DIALOGUE, BUBBLE, DOCUMENT }

# --- 匯出變數 (Inspector 設定) ---
@export_category("Interaction Settings")
@export var interaction_mode: InteractionMode = InteractionMode.DIALOGUE

@export_group("Mode 1: Dialogue")
@export_multiline var dialogue_lines: Array[String] = []
@export var dialogue_npc_name: String = "???"

@export_group("Mode 2: Bubble")
@export_multiline var bubble_text: String = "這裡好像有什麼..."
@export var bubble_duration: float = 2.0

@export_group("Mode 3: Document")
@export_multiline var document_content: String = "這是一份神秘的文件內容..."

@export_group("Visuals")
@export var hint: Sprite2D # 提示圖示 (例如 ?)
@export var hint_duration: float = 0.5

# --- 內部變數 ---
var can_be_hint: bool = true
var _tween: Tween
var player_in_area: bool = false # 追蹤玩家是否在範圍內

# 假設 SpeechBubble 是這個物件的子節點
@onready var speech_bubble = $SpeechBubble 

func _ready() -> void:
	# 初始化 Hint 狀態
	if hint:
		hint.scale = Vector2.ZERO
		hint.modulate.a = 1

func _process(delta: float) -> void:
	pass

func _input(event: InputEvent) -> void:
	# 只有在玩家進入範圍內，且按下空白鍵時才觸發互動
	if player_in_area and event.is_action_pressed("ui_accept"):
		match interaction_mode:
			InteractionMode.DIALOGUE:
				trigger_dialogue()
			InteractionMode.DOCUMENT:
				trigger_document()
			# BUBBLE 模式不需要按鍵，它是進入範圍自動觸發的

# ==========================================================
#       各模式邏輯
# ==========================================================

func trigger_dialogue():
	if dialogue_lines.is_empty():
		print("警告：對話內容為空")
		return
		
	# 設定名字
	DialogueManager.set_name_label(dialogue_npc_name)
	
	DialogueManager.start_dialogue(dialogue_lines.duplicate(), "")

func trigger_bubble():
	# 確保有 SpeechBubble 子節點
	if speech_bubble and speech_bubble.has_method("say"):
		speech_bubble.say(bubble_text, bubble_duration)
	else:
		print("錯誤：找不到 SpeechBubble 子節點或 say 方法")

func trigger_document():
	# 搜尋全域的文件 UI
	var doc = get_tree().get_first_node_in_group("document_ui")
	
	if doc and doc.has_method("open"):
		doc.open(document_content)
	else:
		print("錯誤：找不到群組為 'document_ui' 的物件，或該物件沒有 open() 函式")

# ==========================================================
#       區域偵測與提示
# ==========================================================

func _on_detect_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = true
		
		# 模式二：進入範圍自動觸發氣泡
		if interaction_mode == InteractionMode.BUBBLE:
			trigger_bubble()
		
		# (可選) 進入範圍時顯示互動提示，如果不是氣泡模式的話
		# if interaction_mode != InteractionMode.BUBBLE:
		#	show_hint()

func _on_detect_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = false
		
		# 離開時如果提示還在，將其縮小隱藏
		if hint:
			var t = create_tween()
			t.tween_property(hint, "scale", Vector2.ZERO, 0.2)

# ==========================================================
#       Hint 動畫邏輯
# ==========================================================

func show_hint():
	# initialize
	if hint:
		hint.scale = Vector2.ZERO
		hint.modulate.a = 1
	
	if _tween and _tween.is_running():
		_tween.kill()
		
	_tween = create_tween()
	_tween.set_parallel(true) 
	
	# --- 階段 1: 彈出 ---
	_tween.tween_property(hint, "scale", Vector2(0.5, 0.5), hint_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# --- 階段 2: 停留 ---
	_tween.chain().tween_interval(1.5) 
	
	# --- 階段 3: 淡出 ---
	_tween.chain().tween_property(hint, "modulate:a", 0.0, hint_duration)

# 聲納或外部訊號觸發
func _on_recieve_detect_signal():
	show_hint()
