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

# --- 選項系統變數 ---
signal choice_selected(index: int) # 選項確認訊號

@onready var option_container = $OptionContainer # 請確保節點名稱正確

var is_choosing: bool = false
var current_option_index: int = 0
var active_option_nodes: Array = [] # 存儲生成的選項節點

func _ready():
	box.visible = false

func _input(event):
	if is_choosing:
		_handle_choice_input(event)
		return
	if not is_active: return
	
	# ### 修改：如果是自動模式，忽略玩家的空白鍵輸入，強制看完
	# (如果你希望玩家可以按空白鍵加速，可以把這行拿掉)
	if is_auto_mode: return

	if event.is_action_pressed("ui_accept"):
		if is_typing:
			complete_text()
		else:
			show_next_line()

func _handle_choice_input(event):
	var prev_index = current_option_index
	
	# 滾輪向上 / 鍵盤上
	if event.is_action_pressed("ui_up") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed):
		current_option_index -= 1
	
	# 滾輪向下 / 鍵盤下
	if event.is_action_pressed("ui_down") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed):
		current_option_index += 1
		
	# 循環選擇 (Loop)
	if active_option_nodes.size() > 0:
		current_option_index = posmod(current_option_index, active_option_nodes.size())
	
	# 如果選項改變了，更新視覺
	if prev_index != current_option_index:
		_update_option_visuals()
		
	# 空白鍵確認
	if event.is_action_pressed("ui_accept"):
		_confirm_choice()

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
	
# 用法: var result = await DialogueManager.show_options("要吃什麼?", ["蘋果", "香蕉"])
# 回傳: 玩家選擇的 index (0, 1, 2...)
func show_options(question_text: String, options: Array) -> int:
	# 1. 如果有問題文本，先顯示在對話框 (可選)
	if question_text != "":
		# 強制設定為手動模式並顯示問題
		start_dialogue([question_text], "") 
		# 等待打字機效果跑完 (如果你希望字打完才出選項)
		await get_tree().create_timer(question_text.length() / 20.0 + 0.5).timeout
	
	# 2. 初始化狀態
	is_choosing = true
	current_option_index = 0
	active_option_nodes.clear()
	
	# 清空舊選項 (防呆)
	for child in option_container.get_children():
		child.queue_free()
		
	# 3. 動態生成選項節點
	for i in range(options.size()):
		var opt_text = options[i]
		var opt_node = OptionItem.new(opt_text) # 使用下方的內部類別
		option_container.add_child(opt_node)
		active_option_nodes.append(opt_node)
		
		# 錯開時間播放 "出現動畫" (由上而下依序出現)
		opt_node.play_appear(i * 0.1)
	
	# 4. 更新初始選取狀態
	_update_option_visuals()
	
	# 5. 等待玩家選擇 (await 訊號)
	var selected_index = await choice_selected
	
	# 6. 播放消失動畫
	is_choosing = false
	for node in active_option_nodes:
		node.play_disappear()
		
	# 等待動畫播完再回傳
	await get_tree().create_timer(0.5).timeout
	
	# 清理
	for node in active_option_nodes:
		node.queue_free()
	active_option_nodes.clear()
	
	# 關閉對話框 (或是你可以選擇保留)
	finish_dialogue()
	
	return selected_index

# 輔助：更新視覺 (高亮目前選中的)
func _update_option_visuals():
	for i in range(active_option_nodes.size()):
		var is_selected = (i == current_option_index)
		active_option_nodes[i].set_highlight(is_selected)

# 輔助：確認選擇
func _confirm_choice():
	# 播放被選中動畫
	if active_option_nodes.size() > current_option_index:
		active_option_nodes[current_option_index].play_selected()
	
	emit_signal("choice_selected", current_option_index)
	

# 選項節點動畫
# ==========================================
#  內部類別：動態生成的選項按鈕 (高質感風格)
# ==========================================
class OptionItem extends Control:
	var label: RichTextLabel
	var bar: ColorRect
	var mask: Control
	var tween: Tween
	
	var base_width = 300.0
	var height = 60.0
	
	func _init(text_content: String):
		custom_minimum_size = Vector2(base_width, height)
		
		# 1. 建立遮罩 (Mask) - 用來裁切文字
		mask = Control.new()
		mask.clip_contents = true
		mask.size = Vector2(0, height) # 初始寬度 0
		mask.anchors_preset = Control.PRESET_CENTER_RIGHT # 靠右對齊
		mask.position = Vector2(base_width, 0) # 初始位置在最右邊
		add_child(mask)
		
		# 2. 建立文字 (改用 RichTextLabel)
		label = RichTextLabel.new()
		label.bbcode_enabled = true # 【關鍵】啟用 BBCode
		# 設定文字內容 (這裡示範如何包裝置中標籤)
		# 如果您希望選項文字預設就置中或靠右，可以用 BBCode 包起來
		# 或是使用 RichTextLabel 的對齊設定
		label.text = text_content
		# 設定字體大小 (方法與 Label 略有不同，建議用 theme override)
		label.add_theme_font_size_override("normal_font_size", 30) 
		label.add_theme_color_override("default_color", Color.WHITE)
		# RichTextLabel 預設會自動換行，且高度可能不固定
		# 我們要關閉捲動條並設定固定大小
		label.scroll_active = false
		label.autowrap_mode = TextServer.AUTOWRAP_OFF # 選項通常不換行
		# 設定位置與大小
		label.size = Vector2(base_width - 20, height)
		label.position = Vector2(0, 0)
		# 如果您不使用 BBCode 的 [right]，也可以用屬性設定對齊 (但 BBCode 更靈活)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT # (RichTextLabel 沒有這個屬性，要用 push_right 或 tag)
		mask.add_child(label)
		
		# 3. 建立白色長條 (不變)
		bar = ColorRect.new()
		bar.color = Color.WHITE
		bar.size = Vector2(0, height)
		bar.position = Vector2(base_width, 0)
		add_child(bar)
		
		# 3. 建立白色長條 (Bar)
		bar = ColorRect.new()
		bar.color = Color.WHITE
		bar.size = Vector2(0, height)
		bar.position = Vector2(base_width, 0) # 靠右
		add_child(bar)

	func play_appear(delay: float):
		# 確保狀態重置
		mask.size.x = 0
		mask.position.x = base_width
		bar.size.x = 0
		bar.position.x = base_width
		modulate.a = 1.0
		
		if tween: tween.kill()
		tween = create_tween()
		tween.tween_interval(delay) # 錯開動畫
		
		# 階段 A: Bar 向左伸長
		tween.tween_property(bar, "size:x", base_width, 0.3)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(bar, "position:x", 0.0, 0.3)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			
		# 階段 B: Bar 收縮到右邊 + Mask 展開 (揭示文字)
		tween.set_parallel(true)
		# Bar 變細
		tween.tween_property(bar, "size:x", 5.0, 0.3).set_delay(0.3)
		tween.tween_property(bar, "position:x", base_width - 5.0, 0.3).set_delay(0.3)
		# Mask 變寬 (向左展開)
		tween.tween_property(mask, "size:x", base_width, 0.3).set_delay(0.3)
		tween.tween_property(mask, "position:x", 0.0, 0.3).set_delay(0.3)

	func set_highlight(is_active: bool):
		var t = create_tween()
		if is_active:
			# 選中狀態：文字變黃，稍微放大，稍微往左移
			t.set_parallel(true)
			t.tween_property(label, "modulate", Color(0.0, 1.0, 1.0, 1.0), 0.2) # 青色
			t.tween_property(self, "scale", Vector2(1.1, 1.1), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			# Bar 變寬一點點
			t.tween_property(bar, "size:x", 15.0, 0.2)
			t.tween_property(bar, "position:x", base_width - 15.0, 0.2)
		else:
			# 未選中：恢復原狀
			t.set_parallel(true)
			t.tween_property(label, "modulate", Color.WHITE, 0.2)
			t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
			t.tween_property(bar, "size:x", 5.0, 0.2)
			t.tween_property(bar, "position:x", base_width - 5.0, 0.2)

	func play_selected():
		# 確認選擇動畫：閃爍後消失
		var t = create_tween()
		t.tween_property(self, "modulate", Color(2, 2, 2), 0.1) # 變亮
		t.tween_property(self, "modulate", Color.WHITE, 0.1)

	func play_disappear():
		var t = create_tween()
		t.set_parallel(true)
		# 快速縮回
		t.tween_property(mask, "size:x", 0.0, 0.2)
		t.tween_property(mask, "position:x", base_width, 0.2)
		t.tween_property(bar, "size:x", 0.0, 0.2)
		t.tween_property(bar, "position:x", base_width, 0.2)
		t.tween_property(self, "modulate:a", 0.0, 0.2)
