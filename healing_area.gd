extends Area2D

var is_in_area: bool
var player: Node2D
@export var timer: Timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	is_in_area = is_player_in_zone()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_in_area = true
		timer.start()
		player = body


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_in_area = false
		timer.stop()
		player = null

func _on_timer_timeout() -> void:
	player.hp_change(1, "recover")
	player.hp_change(1, "normal")

func is_player_in_zone() -> bool:
	# 1. 取得目前範圍內「所有」的物體
	var bodies = get_overlapping_bodies()
	
	# 2. 一個一個檢查
	for body in bodies:
		# 3. 如果發現其中一個是 "player" 群組 (注意大小寫要跟你設定的一樣)
		if body.is_in_group("player"):
			return true # 找到了！回傳 true
	
	# 4. 檢查完所有名單都沒找到
	return false
