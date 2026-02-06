extends Node2D

func _ready():
	# 如果是粒子系統
	if has_node("CPUParticles2D"):
		$CPUParticles2D.emitting = true
		# 等待粒子壽命結束
		await get_tree().create_timer($CPUParticles2D.lifetime).timeout
		queue_free()
		
	# 如果是 AnimationPlayer
	elif has_node("AnimationPlayer"):
		$AnimationPlayer.play("hit")
		await $AnimationPlayer.animation_finished
		queue_free()
		
	# 如果只是簡單的 Tween (最推薦，不用額外節點)
	else:
		var tween = create_tween()
		# 假設有個 Sprite，讓它瞬間變大並淡出
		tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.1)
		tween.chain().tween_callback(queue_free)
