extends Control

# 取得節點參照
@onready var title_bar = $title_bar
@onready var start_btn = $Start_button
@onready var settings_btn = $Settings_button
@onready var exit_btn = $Exit_button

# 按鈕相關變數
var btn_original_pos = {}
const COLOR_IDLE = Color("#FFFFFF")
const COLOR_HOVER = Color("#00FFFF")

# 設定資料 (保持你更新後的設定)
var flow_lines: Array[Dictionary] = [
	{
		"initial_delay": 0.0,
		"repeat_interval": 3.0,
		"duration": 2.0,
		"start_pos": Vector2(320, 1190),
		"end_pos": Vector2(-100, 390),
		"width": 3.0,
		"color": Color.WHITE
	},
	{
		"initial_delay": 1.5,
		"repeat_interval": 4.0, 
		"duration": 2.5,
		"start_pos": Vector2(100, 1200),
		"end_pos": Vector2(-50, -200),
		"width": 3.0,
		"color": Color.WHITE
	},
	{
		"start_time": 2.5, # 這裡請記得在編輯器改成 initial_delay
		"initial_delay": 2.5, # 修正你的第三筆資料 Key
		"repeat_interval": 4.5,
		"duration": 2.0,
		"start_pos": Vector2(-100, 500),
		"end_pos": Vector2(400, -100),
		"width": 3.0,
		"color": Color.WHITE
	}
]

func _ready():
	# 1. 初始化按鈕
	var buttons = [start_btn, settings_btn, exit_btn]
	for btn in buttons:
		_setup_button(btn)
	
	# 2. 啟動標題欄動畫
	_animate_title_bar()
	
	# 3. 啟動自動流動線條系統
	_init_flow_lines_system()
	# SoundManager.play_music("background_music", 0.0, 1.0)

# ==========================================
#  核心修改：獨立循環系統
#  (不再計算總時間，每條線自己跑自己的)
# ==========================================
func _init_flow_lines_system():
	for data in flow_lines:
		# 為每一條線啟動獨立的排程
		_start_single_line_loop(data)

func _start_single_line_loop(data: Dictionary):
	var init_delay = data.get("initial_delay", 0.0)
	
	# 如果有初始延遲，先建立一個單次 Tween 等待
	if init_delay > 0:
		var delay_tween = create_tween()
		delay_tween.tween_interval(init_delay)
		# 等待結束後，進入無限循環函式
		delay_tween.tween_callback(_run_infinite_loop.bind(data))
	else:
		# 沒有延遲，直接開始循環
		_run_infinite_loop(data)

func _run_infinite_loop(data: Dictionary):
	var interval = data.get("repeat_interval", 3.0)
	
	# 建立無限循環的 Tween
	var loop_tween = create_tween().set_loops()
	
	# 1. 生成線條
	loop_tween.tween_callback(_spawn_auto_line.bind(data))
	
	# 2. 等待間隔 (這是 "生成點" 到 "下一次生成點" 的時間)
	loop_tween.tween_interval(interval)

# ==========================================
#  線條生成與動畫邏輯
# ==========================================
func _spawn_auto_line(data: Dictionary):
	var start = data.get("start_pos", Vector2.ZERO)
	var end = data.get("end_pos", Vector2(100, 100))
	var dur = data.get("duration", 2.0)
	var width = data.get("width", 2.0)
	var col = data.get("color", Color.WHITE)
	
	var line = Line2D.new()
	line.width = width
	line.default_color = col
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.points = [start, start]
	
	add_child(line)
	# 注意：move_child(line, 0) 會把線放在最底層（背景後面）。
	# 如果你有全螢幕背景圖，線可能會被蓋住看不見。
	# 如果看不見線，請把下面這行註解掉，或是改 Z_Index
	move_child(line, 0) 
	
	# 動畫 Tween
	var tween = create_tween()
	
	# 階段 1: 伸長 (頭部前往終點)
	tween.tween_method(
		func(pos): line.set_point_position(1, pos),
		start,
		end,
		dur
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# 階段 2: 收縮 (尾部前往終點)
	# chain() 讓這段動畫接在階段 1 之後執行 (線條到達終點後才開始消失)
	# 如果你想讓線條像貪食蛇一樣邊跑邊消失，把 .chain() 改成 .parallel() 並加上 .set_delay(0.5) 之類的
	tween.chain().tween_method(
		func(pos): line.set_point_position(0, pos),
		start,
		end,
		dur * 0.8 # 收縮快一點
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	tween.tween_callback(line.queue_free)

# ==========================================
#  舊有的 UI 邏輯 (保持不變)
# ==========================================
func _setup_button(btn: Area2D):
	btn_original_pos[btn] = btn.position
	btn.modulate = COLOR_IDLE
	btn.mouse_entered.connect(_on_button_hover.bind(btn))
	btn.mouse_exited.connect(_on_button_exit.bind(btn))
	btn.input_event.connect(_on_button_input.bind(btn))

func _on_button_hover(btn: Area2D):
	var tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(btn, "modulate", COLOR_HOVER, 0.2)
	tween.tween_property(btn, "position:y", btn_original_pos[btn].y - 10, 0.2)
	SoundManager.play_sfx("button_hovered", 0.0, 1.0)

func _on_button_exit(btn: Area2D):
	var tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(btn, "modulate", COLOR_IDLE, 0.2)
	tween.tween_property(btn, "position:y", btn_original_pos[btn].y, 0.2)

func _on_button_input(viewport: Node, event: InputEvent, shape_idx: int, btn: Area2D):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		match btn.name:
			"Start_button": _on_start_pressed()
			"Settings_button": _on_settings_pressed()
			"Exit_button": _on_exit_pressed()

func _on_start_pressed():
	print("Start Pressed")
	SoundManager.play_sfx("button_pressed", 0.0, 1.0)
	SceneTransition.change_scene("res://world.tscn")

func _on_settings_pressed():
	SoundManager.play_sfx("button_pressed", 0.0, 1.0)
	print("Settings Pressed")

func _on_exit_pressed():
	print("Exit Pressed")
	SoundManager.play_sfx("button_pressed", 0.0, 1.0)
	get_tree().quit()

func _animate_title_bar():
	var pos_tween = create_tween().set_loops()
	pos_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pos_tween.tween_property(title_bar, "position:y", -5.0, 2.0).as_relative()
	pos_tween.tween_property(title_bar, "position:y", 5.0, 2.0).as_relative()
	
	var alpha_tween = create_tween().set_loops()
	alpha_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	alpha_tween.tween_property(title_bar, "modulate:a", 0.7, 1.5)
	alpha_tween.tween_property(title_bar, "modulate:a", 1.0, 1.5)

# 手動觸發用的函式
func create_flowing_line(start_pos: Vector2, end_pos: Vector2, width: float, color: Color, duration: float):
	_spawn_auto_line({
		"start_pos": start_pos,
		"end_pos": end_pos,
		"width": width,
		"color": color,
		"duration": duration
	})
