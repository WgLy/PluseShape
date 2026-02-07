extends CharacterBody2D

# --- 設定區 ---
@export_category("NPC Settings")
@export var npc_name: String = "NPC"
@export_multiline var dialogue_lines: Array[String] = ["你好。", "今天天氣不錯。"]

@export_group("Bubble Settings")
@export var enable_bubble: bool = true # 是否啟用靠近時的氣泡
@export var bubble_text_on_enter: String = "嘿！你好啊！"

@export_group("Visuals")
@export var hint: Sprite2D
@export var hint_duration: float = 0.5

# --- 節點參照 ---
@onready var speech_bubble = $SpeechBubble

# --- 內部變數 ---
var is_finished: bool = false # [關鍵] 用於劇情判斷
var player_in_area: Node2D = null
var _tween: Tween
var can_interact: bool

func _ready() -> void:
	# 初始化 Hint
	if hint:
		hint.scale = Vector2.ZERO
		hint.modulate.a = 1
	
	can_interact = false

func _physics_process(delta: float) -> void:
	# 偵測互動：玩家在範圍內 + 按下空白鍵 + 對話框沒在運作
	if player_in_area and Input.is_action_just_pressed("ui_accept") and can_interact  :
		if not DialogueManager.is_active:
			trigger_interaction()

# ==========================================================
#       核心功能：觸發對話
# ==========================================================
func trigger_interaction():
	# 1. 隱藏氣泡與提示
	if speech_bubble: speech_bubble.visible = false
	if hint: hint.visible = false
	
	# 2. 設定名字與內容
	DialogueManager.set_name_label(npc_name)
	
	# 使用 duplicate() 確保資料安全
	DialogueManager.start_dialogue(dialogue_lines.duplicate(), "")
	
	# 3. 等待對話結束，標記完成
	await DialogueManager.dialogue_finished
	is_finished = true
	can_interact = false
	# print(npc_name + " 對話結束，is_finished = ", is_finished)
	
	# 4. 對話結束後，如果玩家還在範圍內，重新顯示 Hint
	if player_in_area:
		show_hint()

# ==========================================================
#       外部呼叫：更新對話內容 (StoryManager 用)
# ==========================================================
func set_new_dialogue(lines: Array, new_bubble_text: String = ""):
	
	# 2. 使用 assign 來賦值
	# 因為 dialogue_lines 是 Array[String]，不能直接用 = 賦值通用 Array
	# assign 會自動把裡面的東西複製過來並嘗試轉型
	dialogue_lines.assign(lines)
	
	is_finished = false 
	
	if new_bubble_text != "":
		bubble_text_on_enter = new_bubble_text
		
	print(name + " 對話已更新，is_finished 重置為 false") 

# ==========================================================
#       偵測範圍邏輯
# ==========================================================
func _on_detect_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"): # 建議用 Group 判斷比較保險
		player_in_area = body
		show_hint()
		
		# 氣泡邏輯：只有在啟用且沒在對話時才顯示
		if enable_bubble and not DialogueManager.is_active:
			speech_bubble.say(bubble_text_on_enter, 2.0)
	
	can_interact = true

func _on_detect_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = null
		
		# 離開時隱藏 Hint
		if hint:
			var t = create_tween()
			t.tween_property(hint, "scale", Vector2.ZERO, 0.2)
		
		# 強制關閉氣泡 (選用)
		if speech_bubble:
			speech_bubble.visible = false

# ==========================================================
#       其他輔助功能
# ==========================================================
func take_damage(amount):
	if speech_bubble:
		speech_bubble.say("好痛！！", 1.0)

func say(text: String, time: float):
	if speech_bubble:
		speech_bubble.say(text, time)

func show_hint():
	if not hint: return
	
	hint.scale = Vector2.ZERO
	hint.modulate.a = 1
	
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	
	# 彈出
	_tween.tween_property(hint, "scale", Vector2(0.5, 0.5), hint_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 停留 & 淡出
	_tween.chain().tween_interval(1.5)
	_tween.chain().tween_property(hint, "modulate:a", 0.0, hint_duration)
