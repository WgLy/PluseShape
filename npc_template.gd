extends CharacterBody2D

@onready var speech_bubble = $SpeechBubble
@export var hint: Sprite2D
var _tween: Tween
var duriation: int

var can_interact: bool
var player_in_area

func _ready() -> void:
	can_interact = false

func _physics_process(delta: float) -> void:
	if can_interact and Input.is_action_just_pressed("ui_accept") and player_in_area and not DialogueManager.is_active:
		can_interact = false
		DialogueManager.set_name_label("default npc")
		DialogueManager.start_dialogue([
			"開始對話"
		], "test")

func _on_detect_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_in_area = body
		speech_bubble.say("嘿！你好啊！", 2.0)

func _on_detect_body_exited(body: Node2D) -> void:
	can_interact = true
	player_in_area = null

func _on_interact():
	# 讓 NPC 說話，2秒後消失
	speech_bubble.say("嘿！你好啊！", 2.0)

func take_damage(amount):
	# 受傷時也可以冒字
	speech_bubble.say("好痛！！", 1.0)

func say(text: String, time: float):
	if speech_bubble:
		speech_bubble.say(text, time)
		
func show_hint():
	# initialize
	if hint:
		hint.scale = Vector2.ZERO
		hint.modulate.a = 1
	
	if not _tween == null :
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true) 
	_tween.tween_property(hint, "scale", Vector2(0.5, 0.5), duriation).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# --- 階段 2: 停留 (關鍵！) ---
	# chain() 會等待上面的彈出動畫結束
	# 然後我們加入一個 interval (空白時間) 讓玩家閱讀
	_tween.chain().tween_interval(1.5) # 停留 1.5 秒
	
	# --- 階段 3: 淡出 ---
	# chain() 會等待上面的 interval 結束
	# 然後執行淡出
	_tween.chain().tween_property(hint, "modulate:a", 0.0, duriation)
