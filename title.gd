extends CanvasLayer # 或是 Node2D

@onready var title_words: RichTextLabel = $titleWords
@onready var under_line: Line2D = $underLine

# 動畫設定
@export var fade_time: float = 0.5
@export var line_gap: float = 5.0
@export var line_width: float = 3.0 # 【新增】設定線條的粗細

func _ready():
	# 初始化
	title_words.modulate.a = 0.0
	
	# 【修正 1】這裡只重置點的位置，不要把 width 設為 0，或者之後要設回來
	# 我們改為在 show_title 裡面確保 width 是正確的
	under_line.width = line_width 
	_update_line_extent(0.0)
	
	# 測試呼叫
	# show_title("實驗室", 1.0)

func show_title(text_content: String, duration: float = 1.0):
	# 1. 設定文字
	title_words.text = text_content
	
	# 2. 強制更新大小
	title_words.reset_size()
	await get_tree().process_frame
	
	# 【除錯】印出尺寸，確認是否有抓到寬度 (如果印出 (0,0) 代表 Fit Content 設定有誤)
	# print("Debug: Text Size = ", title_words.size)
	
	# 3. 計算幾何資訊
	var text_size = title_words.size
	var text_pos = title_words.position
	
	# 4. 定位 Line2D
	var center_x = text_pos.x + (text_size.x / 2.0)
	var bottom_y = text_pos.y + text_size.y + line_gap
	under_line.position = Vector2(center_x, bottom_y)
	
	# 【修正 2】確保線條寬度是看得到的，並重置長度為 0
	under_line.width = line_width
	_update_line_extent(0.0)
	
	var target_extent = text_size.x / 2.0
	
	
	# --- 第一階段：進場 ---
	var tween_in = create_tween()
	tween_in.set_parallel(true)
	tween_in.tween_property(title_words, "modulate:a", 1.0, fade_time)
	tween_in.tween_method(_update_line_extent, 0.0, target_extent, fade_time)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 等待進場動畫播放完畢
	await tween_in.finished
	
	# --- 第二階段：停留 ---
	# 建立一個計時器並等待它結束
	if duration > 0:
		await get_tree().create_timer(duration).timeout
	
	# --- 第三階段：退場 ---
	var tween_out = create_tween()
	tween_out.set_parallel(true)
	tween_out.tween_property(title_words, "modulate:a", 0.0, fade_time)
	tween_out.tween_method(_update_line_extent, target_extent, 0.0, fade_time)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

func _update_line_extent(current_extent: float):
	var point_left = Vector2(-current_extent, 0)
	var point_right = Vector2(current_extent, 0)
	
	under_line.clear_points()
	under_line.add_point(point_left)
	under_line.add_point(point_right)
