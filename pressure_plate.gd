extends Node2D

@export var door: Node2D
@export var initial_state: bool
@export var image_notPressed: Sprite2D

@export var pressEffect: Sprite2D
@export var pressEffect2: Sprite2D
var is_pressed: bool
var tween: Tween

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pressEffect.visible = false
	initial_state = false
	image_notPressed.visible = true
	if door:
		# 強制覆蓋 Door 的設定，符合你的需求
		door.is_automatically_open = false
		door.is_locked = false
		door.close_door()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _play_press_effect() -> void:
	if pressEffect:
		pressEffect.visible = true
		pressEffect.scale = Vector2(1.0, 1.0)
		pressEffect.modulate.a = 1.0
		pressEffect2.visible = true
		pressEffect2.scale = Vector2(1.0, 1.0)
		pressEffect2.modulate.a = 1.0
		if not tween == null:
			tween.kill()
		
		tween = create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(pressEffect, "scale", Vector2(2.5, 2.5), 0.3)
		tween.tween_property(pressEffect, "modulate:a", 0, 1)
		tween.set_parallel(true)
		tween.tween_property(pressEffect2, "scale", Vector2(2, 2), 0.7)
		tween.tween_property(pressEffect2, "modulate:a", 0, 1)
		tween.chain().tween_callback(func(): pressEffect.visible = false)
		tween.chain().tween_callback(func(): pressEffect2.visible = false)
	else:
		print("pressEffect not found")

func _on_detect_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("pushable") : # 或是 body.is_in_group("player")
		is_pressed = true
		_play_press_effect()
		image_notPressed.visible = false
		if door:
			door.open_door()
		# 這裡可以加入顯示 "按下空白鍵" UI 的邏輯

func _on_detect_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("pushable") :
		is_pressed = false
		image_notPressed.visible = true
		if door:
			door.close_door()
		# 這裡可以加入隱藏 UI 的邏輯
