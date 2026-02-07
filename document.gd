extends CanvasLayer # 或 CanvasLayer，視你的根節點類型而定

signal closed # 當文件關閉時發出訊號

# --- 節點參照 ---
@onready var background: Control = $Control # 黑色遮罩背景
@onready var paper_panel: Panel = $Control/Panel # 紙張本體
@onready var text_label: RichTextLabel = $Control/Panel/RichTextLabel

# --- 動畫變數 ---
var tween: Tween

func _ready() -> void:
	# 遊戲開始時隱藏
	visible = false
	
	# 初始化狀態：把紙張設為隱藏狀態的數值
	_reset_visuals()

# --- 重置視覺狀態 (內部用) ---
func _reset_visuals():
	background.modulate.a = 0.0 # 背景全透明
	paper_panel.scale = Vector2(0.1, 0.1) # 紙張縮得很小
	paper_panel.modulate.a = 0.0 # 紙張透明
	paper_panel.rotation_degrees = -5.0 # 稍微歪一點

# ==========================================================
#       開啟文件 (Open)
# ==========================================================
func open(content: String):
	# 1. 設定內容
	text_label.text = content
	
	# 2. 顯示節點並暫停遊戲 (選擇性，看你想不想讓背後的怪打玩家)
	visible = true
	# get_tree().paused = true 
	
	# 3. 播放音效 (整合你的 SoundManager)
	# SoundManager.play_sfx("paper_open") 
	
	# 4. 執行開啟動畫
	if tween: tween.kill() # 確保上一個動畫停止
	tween = create_tween()
	tween.set_parallel(true) # 讓以下動畫同時發生
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # 確保暫停時動畫照樣跑
	
	# A. 背景遮罩淡入 (變暗)
	tween.tween_property(background, "modulate:a", 1.0, 0.3)
	
	# B. 紙張動畫：彈出效果 (Back Out)
	# Scale: 從 0.1 變大到 1.0
	tween.tween_property(paper_panel, "scale", Vector2.ONE, 0.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Alpha: 從透明變實體
	tween.tween_property(paper_panel, "modulate:a", 1.0, 0.3)
	
	# Rotation: 從歪的轉正 (更有拿起來的感覺)
	tween.tween_property(paper_panel, "rotation_degrees", 0.0, 0.4)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ==========================================================
#       關閉文件 (Close)
# ==========================================================
func close():
	# 1. 播放音效
	# SoundManager.play_sfx("paper_close")
	
	# 2. 執行關閉動畫
	if tween: tween.kill()
	tween = create_tween()
	tween.set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# A. 背景淡出
	tween.tween_property(background, "modulate:a", 0.0, 0.2)
	
	# B. 紙張動畫：縮小淡出 (Back In)
	# Scale: 縮小一點點就好，不需要縮到 0 (看起來像放下)
	tween.tween_property(paper_panel, "scale", Vector2(0.8, 0.8), 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	# Alpha: 變透明
	tween.tween_property(paper_panel, "modulate:a", 0.0, 0.2)
	
	# Rotation: 稍微轉一下
	tween.tween_property(paper_panel, "rotation_degrees", 5.0, 0.2)
	
	# 3. 動畫結束後的清理
	tween.chain().tween_callback(func():
		visible = false
		_reset_visuals() # 重置狀態以備下次開啟
		# get_tree().paused = false # 恢復遊戲
		emit_signal("closed") # 通知外部
	)

# ==========================================================
#       輸入偵測 (Input)
# ==========================================================
func _input(event: InputEvent) -> void:
	if not visible: return
	
	# 如果正在跑開啟動畫，禁止立刻關閉 (防止誤觸)
	if tween and tween.is_running() and paper_panel.scale.x < 0.8:
		return

	# 按下 ESC、空白鍵、或滑鼠左鍵點擊時關閉
	if event.is_action_pressed("ui_cancel") or \
	   event.is_action_pressed("ui_accept") or \
	   (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		
		# 呼叫關閉
		close()
		
		# 標記輸入已處理，避免穿透到後面的遊戲層
		get_viewport().set_input_as_handled()
