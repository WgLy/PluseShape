extends Node2D

# 移除 @onready，改為普通變數，我們手動抓取
var audio_player: AudioStreamPlayer2D
var ray_cast: RayCast2D

var player_ref: Node2D = null

func _ready():
	# 【安全修正】在這裡抓取節點，確保節點存在
	# 如果你的節點名稱不同，請修改括號內的字串
	if has_node("AudioStreamPlayer2D"):
		audio_player = $AudioStreamPlayer2D
	else:
		push_error("SpatialAudioPlayer: 找不到子節點 AudioStreamPlayer2D，請檢查場景檔名稱！")
		return

	if has_node("RayCast2D"):
		ray_cast = $RayCast2D
	
	player_ref = get_tree().get_first_node_in_group("player")
	
	if audio_player:
		audio_player.finished.connect(queue_free)

func setup(stream: AudioStream, vol: float, pitch: float):
	# 【安全修正】如果 setup 比 _ready 先跑，或 _ready 失敗，手動再抓一次
	if not audio_player:
		audio_player = get_node_or_null("AudioStreamPlayer2D")
	
	# 如果還是找不到，就報錯並退出，防止遊戲崩潰
	if not audio_player:
		push_error("SpatialAudioPlayer Error: AudioPlayer node is missing!")
		return
		
	audio_player.stream = stream
	audio_player.volume_db = vol
	audio_player.pitch_scale = pitch
	
	_check_occlusion()
	audio_player.play()


func _physics_process(_delta):
	# 如果聲音正在播放，持續檢查遮擋 (可選：為了效能可以用 Timer 降低頻率)
	if audio_player.playing:
		_check_occlusion()

func _check_occlusion():
	if not is_instance_valid(player_ref): return
	
	# 1. 更新射線目標：從音源位置 -> 玩家位置
	ray_cast.target_position = to_local(player_ref.global_position)
	ray_cast.force_raycast_update() # 強制立即更新
	
	# 2. 判斷是否撞到牆
	if ray_cast.is_colliding():
		# 撞到牆壁了 -> 切換到「悶音 Bus」
		if audio_player.bus != "SFX_Muffled":
			audio_player.bus = "SFX_Muffled"
			# 可選：稍微降低音量
			audio_player.volume_db -= 5.0 
	else:
		# 沒撞到牆 -> 恢復正常 Bus
		if audio_player.bus != "SFX":
			audio_player.bus = "SFX"
			audio_player.volume_db += 5.0 # 補回音量
