extends Node2D

@export var mode: int
@export var hint: Sprite2D
var can_be_hint: bool = true
var duriation: float = 0.5

var _tween: Tween

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if hint:
		hint.scale = Vector2.ZERO
		hint.modulate.a = 1
			


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func show_hint():
	# initialize
	if hint:
		hint.scale = Vector2.ZERO
		hint.modulate.a = 1
	
	if not _tween == null :
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true) 
	_tween.tween_property(hint, "scale", Vector2(0.5, 0.5), duriation)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# --- 階段 2: 停留 (關鍵！) ---
	# chain() 會等待上面的彈出動畫結束
	# 然後我們加入一個 interval (空白時間) 讓玩家閱讀
	_tween.chain().tween_interval(1.5) # 停留 1.5 秒
	
	# --- 階段 3: 淡出 ---
	# chain() 會等待上面的 interval 結束
	# 然後執行淡出
	_tween.chain().tween_property(hint, "modulate:a", 0.0, duriation)
	


func _on_detect_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		pass


func _on_detect_area_body_exited(body: Node2D) -> void:
	pass # Replace with function body.

func _on_recieve_detect_signal():
	show_hint()
