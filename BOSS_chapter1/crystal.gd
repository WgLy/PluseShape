extends StaticBody2D

# --- 定義狀態與模式 ---
enum Mode { NORMAL, BOSS_FIGHT }
enum State { ACTIVE, BROKEN }

# --- 參數設定 ---
@export_group("Settings")
@export var mode: Mode = Mode.BOSS_FIGHT
@export var max_hp: int = 3
@export var regenerate_time: float = 5.0 # 碎裂後幾秒重生

# --- 訊號 ---
# 通知 BOSS 水晶狀態改變 (破了/重生了)
# is_broken: true 代表剛碎掉, false 代表剛重生
signal state_changed(is_broken: bool)

# --- 內部變數 ---
var current_hp: int
var current_state: State = State.ACTIVE

@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D
@onready var regen_timer = $RegenTimer

# 如果你有碎裂後的圖片，可以在這裡參照，沒有的話就單純隱藏 Sprite
@onready var broken_sprite = get_node_or_null("BrokenSprite") 

func _ready() -> void:
	current_hp = max_hp
	current_state = State.ACTIVE
	
	# 初始化計時器
	regen_timer.wait_time = regenerate_time
	regen_timer.one_shot = true
	if not regen_timer.timeout.is_connected(_on_regen_timer_timeout):
		regen_timer.timeout.connect(_on_regen_timer_timeout)
	
	update_visuals()

# --- 受傷邏輯 ---
func take_damage(amount, _source_pos = Vector2.ZERO):
	if current_state == State.BROKEN:
		return # 已經碎了就不要再扣血
	
	current_hp -= amount
	flash_effect() # 受傷閃爍
	
	if current_hp <= 0:
		break_crystal()

# --- 碎裂邏輯 ---
func break_crystal():
	if mode == Mode.NORMAL:
		# 普通模式：直接掉寶或刪除
		# spawn_loot() 
		queue_free()
	
	elif mode == Mode.BOSS_FIGHT:
		# BOSS 模式：進入暫時損毀狀態
		current_state = State.BROKEN
		
		# 關閉碰撞 (使用 set_deferred 以避免物理錯誤)
		collision_shape.set_deferred("disabled", true)
		
		# 發出訊號通知 BOSS
		emit_signal("state_changed", true)
		
		# 啟動重生計時器
		regen_timer.start()
		update_visuals()
		
		# 可以在這裡播放碎裂音效

# --- 重生邏輯 ---
func _on_regen_timer_timeout():
	regenerate()

func regenerate():
	current_state = State.ACTIVE
	current_hp = max_hp
	
	# 恢復碰撞
	collision_shape.set_deferred("disabled", false)
	
	# 發出訊號通知 BOSS
	emit_signal("state_changed", false)
	
	update_visuals()
	# 可以在這裡播放重生音效/特效

# --- 視覺更新 ---
func update_visuals():
	if current_state == State.ACTIVE:
		sprite.visible = true
		sprite.modulate.a = 1.0
		if broken_sprite: broken_sprite.visible = false
	else:
		# 碎裂狀態
		sprite.visible = false # 或者設為半透明
		if broken_sprite: broken_sprite.visible = true

func flash_effect():
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(10, 10, 10), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
