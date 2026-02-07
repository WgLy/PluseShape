extends Control

@onready var save_load_window = $SaveLoadWindow # 引用存檔介面
var sonar_scene = preload("res://sonar_pulse.tscn")
@onready var background = $TextureRect

func _ready() -> void:
	pass

# 1. 新遊戲
func _on_button_new_game_pressed():
	# 使用過場動畫進入第一關
	SoundManager.play_spatial_sfx("ui_click", global_position, 0.0, 0.1)
	SceneTransition.change_scene("res://world.tscn")
	

# 2. 繼續遊戲
func _on_button_continue_pressed():
	# 打開存檔介面，設定為讀檔模式 (LOAD)
	save_load_window.open(save_load_window.Mode.LOAD)

# 3. 成就
func _on_button_achievements_pressed():
	# 這裡你需要另外做一個顯示 GlobalData.achievements 的簡單介面
	# 邏輯跟 SaveLoadWindow 很像，只是只顯示文字
	pass 

# 4. 離開
func _on_button_quit_pressed():
	get_tree().quit()

func fire_sonar():
	var pulse = sonar_scene.instantiate()
	pulse.global_position = get_viewport_rect().size / 2
	pulse.expand_speed = 40
	pulse.max_scale = 100
	get_tree().root.add_child(pulse)


func _on_soner_timer_timeout() -> void:
	fire_sonar()
