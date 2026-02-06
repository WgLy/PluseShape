extends CanvasLayer

# 定義模式：是來存檔的？還是來讀檔的？
enum Mode { SAVE, LOAD }
var current_mode = Mode.LOAD

# 【注意】請根據你實際的場景結構修改這些路徑
# 因為根節點變成了 CanvasLayer，所以原本的子節點現在包在 MainPanel 裡
@onready var container = $MainPanel/ScrollContainer/VBoxContainer
@onready var title_label = $MainPanel/Panel/Label
@onready var close_button = $MainPanel/CloseButton # 如果你有做關閉按鈕的話

func _ready():
	# 初始化時隱藏介面
	visible = false 
	
	# 如果有做關閉按鈕，連接訊號
	if close_button:
		close_button.pressed.connect(close)

# 開啟視窗的函式
func open(mode: Mode):
	current_mode = mode
	visible = true # 顯示整個 CanvasLayer
	
	# 設定標題文字
	title_label.text = "儲存進度" if mode == Mode.SAVE else "讀取進度"
	
	# 暫停遊戲 (選用：看你希望存檔時遊戲是否暫停)
	# get_tree().paused = true 
	
	refresh_list()

# 關閉視窗
func close():
	visible = false
	# 恢復遊戲 (如果有暫停的話)
	# get_tree().paused = false

# 刷新存檔列表 (核心邏輯)
func refresh_list():
	# 1. 清除舊按鈕
	for child in container.get_children():
		child.queue_free()
	
	# 2. 生成 50 個存檔槽按鈕
	for i in range(SaveManager.MAX_SLOTS):
		var btn = Button.new()
		
		# --- 樣式與排版設定 (關鍵修正區域) ---
		
		# 設定按鈕最小高度 (100px)，寬度設為 0 (由容器決定)
		btn.custom_minimum_size = Vector2(0, 100)
		
		# 文字對齊靠左
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		# 設定字體大小 (修正：使用 Override)
		btn.add_theme_font_size_override("font_size", 24)
		
		# 防止文字過長超出按鈕 (使用 ... 省略)
		btn.clip_text = true
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		
		# --- 圖示控制 (防止按鈕爆炸) ---
		
		# 允許圖示縮放
		btn.expand_icon = true
		
		# 【重要】限制圖示最大寬度，避免高解析度截圖撐爆按鈕
		# 注意：這需要 Godot 4.0+
		btn.set("theme_override_constants/icon_max_width", 160)
		
		# --- 資料填充 ---
		
		# 從 SaveManager 取得該槽位的資訊
		var info = SaveManager.get_save_info(i)
		
		if info.is_empty():
			btn.text = "存檔 %02d - [ 空 ]" % (i + 1)
			# 如果是讀檔模式，空存檔不能按
			if current_mode == Mode.LOAD:
				btn.disabled = true
		else:
			# 顯示格式：存檔 01 - 黑暗森林 (2025-01-07 12:00:00)
			btn.text = "存檔 %02d - %s (%s)" % [i + 1, info["location"], info["timestamp"]]
			
			# 如果未來你有做截圖功能，可以在這裡設定 icon
			# if "screenshot" in info:
			# 	btn.icon = info["screenshot"]
		
		# --- 連接訊號 ---
		# 使用 bind 將當下的 i (槽位編號) 傳給函式
		btn.pressed.connect(_on_slot_pressed.bind(i))
		
		# 加入到容器中
		container.add_child(btn)

# 當某個存檔槽被點擊時
func _on_slot_pressed(slot_id):
	if current_mode == Mode.SAVE:
		# 執行存檔
		SaveManager.save_game(slot_id)
		# 存檔完畢後關閉視窗 (或者可以彈出一個 "存檔成功" 的提示)
		close()
		
	elif current_mode == Mode.LOAD:
		# 執行讀檔
		SaveManager.load_game(slot_id)
		# 讀檔通常會切換場景，所以不需要特別呼叫 close()，但保險起見可以呼叫
		close()

# 捕捉按鍵 (選用：按 ESC 關閉視窗)
func _input(event):
	if visible and event.is_action_pressed("ui_cancel"): # 預設是 Esc
		close()
