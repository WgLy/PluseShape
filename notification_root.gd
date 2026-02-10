extends Control

# --- 參數設定 ---
@export var box_width: float = 300.0   # 提示框總寬度
@export var box_height: float = 60.0   # 提示框高度
@export var bar_thickness: float = 5.0 # 最後留下的右邊框寬度
@export var duration: float = 0.4      # 動畫單程時間
@export var stay_time: float = 3.0     # 停留時間

# --- 節點參照 ---
@onready var content_mask: Control = $ContentMask
@onready var message_label: RichTextLabel = $ContentMask/MessageLabel
@onready var white_bar: ColorRect = $WhiteBar
@onready var timer: Timer = $Timer

var _tween: Tween

func _ready() -> void:
	# 初始化：確保一開始看不見
	_reset_visuals()
	timer.timeout.connect(close_notification)


# ==========================================================
#       【新增】測試輸入
# ==========================================================
func _input(event: InputEvent) -> void:
	# 偵測鍵盤按鍵 Q，且只在按下瞬間觸發 (不包含長按重複觸發)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			# 呼叫顯示函式，並指定停留 1.0 秒
			show_notification("提示訊息", 1.0)

func _reset_visuals():
	# Mask 寬度為 0 (隱藏文字)
	content_mask.size = Vector2(0, box_height)
	# Bar 寬度為 0
	white_bar.size = Vector2(0, box_height)
	# Bar 位置在最左邊
	white_bar.position = Vector2(0, 0)
	# 確保 Label 的寬度始終是滿的 (避免文字被擠壓換行)
	message_label.size = Vector2(box_width, box_height)

# ==========================================================
#       開啟動畫 (Open)
# ==========================================================
# ==========================================================
#       開啟動畫 (Open) - 【修改】加入 custom_stay_time 參數
# ==========================================================
# 如果呼叫時沒給第二個參數，它會預設為 -1，代表使用原本的 stay_time
func show_notification(text: String, custom_stay_time: float = -1.0):
	# 1. 設定文字
	message_label.text = text
	
	# 2. 重置狀態並殺死舊動畫
	if _tween: _tween.kill()
	timer.stop()
	_reset_visuals()
	
	_tween = create_tween()
	
	# --- 階段一：白色長條拉伸 (Stretch) ---
	_tween.tween_property(white_bar, "size:x", box_width, duration * 0.5)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	# --- 階段二：揭示文字 (Reveal) ---
	_tween.set_parallel(true)
	
	# A. WhiteBar 寬度縮小
	_tween.tween_property(white_bar, "size:x", bar_thickness, duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# B. WhiteBar 位置往右移
	_tween.tween_property(white_bar, "position:x", box_width - bar_thickness, duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	# C. ContentMask 寬度變大
	_tween.tween_property(content_mask, "size:x", box_width, duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# --- 【修改】決定停留時間 ---
	var final_wait_time = stay_time # 預設使用 Inspector 設定的時間
	if custom_stay_time > 0:
		final_wait_time = custom_stay_time # 如果有指定，就用指定的
	
	# 動畫結束後，啟動 Timer
	_tween.chain().tween_callback(timer.start.bind(final_wait_time))

# ==========================================================
#       關閉動畫 (Close) - 開啟的反向
# ==========================================================
func close_notification():
	if _tween: _tween.kill()
	_tween = create_tween()
	
	# --- 階段一：遮蔽文字 (Cover) ---
	_tween.set_parallel(true)
	
	# A. WhiteBar 變寬 (向左長回來)
	_tween.tween_property(white_bar, "size:x", box_width, duration * 0.8)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	# B. WhiteBar 位置歸零 (回到最左邊)
	_tween.tween_property(white_bar, "position:x", 0.0, duration * 0.8)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		
	# C. ContentMask 變窄 (隱藏文字)
	_tween.tween_property(content_mask, "size:x", 0.0, duration * 0.8)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	# --- 階段二：收縮 (Shrink) ---
	# WhiteBar 縮回 0
	_tween.chain().tween_property(white_bar, "size:x", 0.0, duration * 0.5)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	
	# 結束後清理
	_tween.chain().tween_callback(func(): 
		# 可以在這裡 queue_free 或者只是隱藏
		pass
	)
