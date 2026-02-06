extends CanvasLayer

signal dialogue_started
signal dialogue_finished

@onready var box = $DialogueBox
@onready var text_label = $DialogueBox/Panel/HBoxContainer/VBoxContainer/RichTextLabel 
@onready var name_label = $DialogueBox/Panel/HBoxContainer/VBoxContainer/Label
@onready var face_rect = $DialogueBox/Panel/HBoxContainer/FaceRect

var portraits = {
	"spider": preload("res://icon.svg"), # 請確認路徑
	"player": preload("res://icon.svg"),
	"unknown": preload("res://icon.svg"),
	"test": preload("res://AttackEffect/PS剪影1.png")
}

var dialogue_queue: Array = []
var is_active = false
var is_typing = false
# ### 新增：記錄目前是否為自動播放模式
var is_auto_mode = false 

func _ready():
	box.visible = false

func _input(event):
	if not is_active: return
	
	# ### 修改：如果是自動模式，忽略玩家的空白鍵輸入，強制看完
	# (如果你希望玩家可以按空白鍵加速，可以把這行拿掉)
	if is_auto_mode: return

	if event.is_action_pressed("ui_accept"):
		if is_typing:
			complete_text()
		else:
			show_next_line()

# --- 原本的手動對話 (保持不變) ---
func start_dialogue(lines: Array, character_key: String = ""):
	if is_active: return
	
	# 初始化狀態
	is_auto_mode = false # 標記為手動模式
	dialogue_queue = lines
	_setup_dialogue_ui(character_key) # 抽離出的 UI 設定
	
	show_next_line()

# --- ### 新增：自動播放對話 ---
# 用法：lines 必須包含字典，例如 [{"text": "快跑！", "time": 1.0}, {"text": "別回頭！", "time": 2.5}]
func start_auto_dialogue(lines: Array, character_key: String = ""):
	if is_active: return
	
	# 初始化狀態
	is_auto_mode = true # 標記為自動模式
	dialogue_queue = lines
	_setup_dialogue_ui(character_key)
	
	show_next_line()

# (內部工具) 設定 UI 顯示
func _setup_dialogue_ui(character_key):
	is_active = true
	box.visible = true
	
	emit_signal("dialogue_started")
	
	if character_key != "" and portraits.has(character_key):
		face_rect.texture = portraits[character_key]
		face_rect.visible = true
	else:
		face_rect.visible = false

func set_name_label(string):
	name_label.text = string

# --- 核心邏輯 (大幅修改以支援自動模式) ---
func show_next_line():
	if dialogue_queue.is_empty():
		finish_dialogue()
		return
	
	var current_data = dialogue_queue.pop_front()
	var text_to_show = ""
	var wait_time = 2.0 # 預設停留秒數
	
	# ### 判斷資料型態
	# 如果是字典 (自動模式用)，就取出文字和時間
	if typeof(current_data) == TYPE_DICTIONARY:
		text_to_show = current_data.get("text", "...")
		wait_time = current_data.get("time", 2.0)
	# 如果是字串 (一般模式用)
	else:
		text_to_show = str(current_data)
	
	text_label.text = text_to_show
	
	# 打字機效果
	text_label.visible_ratio = 0.0
	is_typing = true
	
	var tween = create_tween()
	# 計算打字時間
	var typing_duration = text_to_show.length() / 20.0 
	
	# 1. 執行打字動畫
	tween.tween_property(text_label, "visible_ratio", 1.0, typing_duration)
	
	# 2. 打字結束後的行為
	if is_auto_mode:
		# ### 自動模式：打完字後 -> 標記打字結束 -> 等待 wait_time 秒 -> 自動呼叫下一句
		tween.tween_callback(func(): is_typing = false)
		tween.tween_interval(wait_time) # 這裡是「停留」的時間
		tween.tween_callback(show_next_line) # 時間到，自動換下一句
	else:
		# 一般模式：打完字後 -> 標記打字結束 -> 等待玩家按空白鍵
		tween.tween_callback(func(): is_typing = false)

func complete_text():
	# 瞬間顯示所有文字 (僅手動模式會觸發)
	text_label.visible_ratio = 1.0
	is_typing = false

func finish_dialogue():
	box.visible = false
	is_active = false
	is_auto_mode = false # 重置模式
	emit_signal("dialogue_finished")
