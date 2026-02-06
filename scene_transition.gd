extends CanvasLayer

@onready var color_rect = $ColorRect
signal transition_finished

func change_scene(target_path: String):
	# 1. 淡出 (變黑)
	var tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 1.0, 0.5) # 0.5秒變黑
	await tween.finished
	
	# 2. 實際切換場景
	get_tree().change_scene_to_file(target_path)
	
	# 3. 淡入 (變亮)
	tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 0.0, 0.5) # 0.5秒變透明
	
	emit_signal("transition_finished")
