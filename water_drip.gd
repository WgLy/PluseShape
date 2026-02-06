extends Node2D

# 載入我們的聲納波場景
var sonar_scene = preload("res://sonar_pulse.tscn") # 確保路徑對應你的檔案位置

func _ready():
	# 連接計時器的訊號
	$Timer.timeout.connect(_on_timer_timeout)

func _on_timer_timeout():
	emit_pulse()

func emit_pulse():
	# 1. 生成脈衝
	var pulse = sonar_scene.instantiate()
	
	# 2. 設定位置 (就在這個物件的位置)
	pulse.global_position = global_position
	
	# 3. 客製化：環境聲音的波紋應該比較小、比較弱
	pulse.max_scale = 1.5   # 原本是 6.0，改小一點
	pulse.expand_speed = 0.5 # 擴散慢一點
	
	# 4. 加到場景中
	get_tree().root.add_child(pulse)
	
	# (未來這裡可以加入 $AudioStreamPlayer2D.play() 來播放真的滴水聲)
