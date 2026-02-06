extends Control

@onready var label = $Anchor/BubblePanel/Label
@onready var panel = $Anchor/BubblePanel

func _ready():
	visible = false # 平時隱藏

func say(text: String, duration: float = 2.0):
	# 1. 初始化顯示
	label.text = text
	label.visible_ratio = 0.0 # 先把字隱藏
	visible = true
	
	# 2. 建立 Tween 動畫
	var tween = create_tween()
	
	# --- 打字機效果 ---
	# 計算打字時間：例如每個字 0.05 秒，最快 0.2 秒，最慢 1.0 秒
	var type_time = clamp(text.length() * 0.05, 0.2, 1.0)
	
	tween.tween_property(label, "visible_ratio", 1.0, type_time)
	
	# --- 停留時間 ---
	# 打完字後，停留 duration 秒
	tween.tween_interval(duration)
	
	# --- 消失 (可選：淡出效果) ---
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(_on_finished)

func _on_finished():
	visible = false
	modulate.a = 1.0 # 重置透明度，為了下次顯示
