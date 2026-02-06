extends Node2D

@onready var player = $Player
@onready var health_bar = $CanvasLayer/HealthBar # 這次找得到了！
@onready var health_bar_2 = $CanvasLayer/HealthBar2 # 這次找得到了！

func _ready():
	# 1. 初始化血條最大值
	health_bar.max_value = player.max_hp
	health_bar.value = player.current_hp
	health_bar_2.value = player.recover_hp
	# 2. 監聽玩家血量變化
	player.hp_changed.connect(_on_player_hp_changed)
	player.recover_hp_changed.connect(_on_player_recover_hp_changed)

# 當收到訊號時，更新 UI
func _on_player_hp_changed(new_hp):
	health_bar.value = new_hp
	cheack_if_player_die()

func _on_player_recover_hp_changed(new_recover_hp):
	health_bar_2.value = new_recover_hp

func cheack_if_player_die():
	if health_bar.value <= 0:
		player.die()
