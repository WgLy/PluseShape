# SoundManager.gd
extends Node

var spatial_audio_scene = preload("res://Music/spatial_audio_player.tscn")

# 音效快取池
var loaded_streams: Dictionary = {}

# 【新增】專門播放背景音樂的播放器 (不會被 queue_free)
var music_player: AudioStreamPlayer

func _ready() -> void:
	# 初始化音樂播放器
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music" # 請確保你的 Audio Bus Layout 有 "Music" 軌道，否則預設會是 "Master"
	music_player.name = "MusicPlayer"
	add_child(music_player)

# --- 內部輔助：根據名稱取得 AudioStream ---
func _get_stream(key_or_stream) -> AudioStream:
	if key_or_stream is AudioStream:
		return key_or_stream
		
	if key_or_stream is String:
		var sfx_name = key_or_stream
		
		if loaded_streams.has(sfx_name):
			return loaded_streams[sfx_name]
			
		# 這裡假設你的 AudioLibrary 也能取得音樂的路徑
		var path = AudioLibrary.get_audio_path(sfx_name)
		if path == "": 
			push_warning("SoundManager: 找不到音效/音樂路徑 -> " + sfx_name)
			return null
		
		var stream = load(path)
		if stream:
			loaded_streams[sfx_name] = stream
			return stream
			
	return null

# --- 【新增】 背景音樂播放功能 ---
# track_name: 音樂名稱 (對應 AudioLibrary)
# volume_db: 音量 (預設 0.0)
# pitch_scale: 音高 (預設 1.0，音樂通常不隨機改變音高)
func play_music(track_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0):
	var stream = _get_stream(track_name)
	if not stream: return

	# 1. 檢查是否正在播放同一首音樂
	# 如果是同一首且正在播放，就不做任何事 (避免切換場景時音樂中斷)
	if music_player.stream == stream and music_player.playing:
		# 如果需要，可以在這裡更新音量
		music_player.volume_db = volume_db
		return

	# 2. 播放新音樂
	music_player.stream = stream
	music_player.volume_db = volume_db
	music_player.pitch_scale = pitch_scale
	music_player.play()

# --- 【新增】 停止音樂功能 ---
func stop_music(fade_out_duration: float = 0.0):
	if fade_out_duration > 0:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -80.0, fade_out_duration)
		tween.tween_callback(music_player.stop)
	else:
		music_player.stop()

# --- 1. 一般音效播放 (維持原樣) ---
func play_sfx(sfx, pitch_scale: float = 1.0, pitch_variation: float = 0.1):
	var stream = _get_stream(sfx)
	if not stream: return
	
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "SFX"
	
	var final_pitch = pitch_scale + randf_range(-pitch_variation, pitch_variation)
	player.pitch_scale = final_pitch
	
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

# --- 2. 空間音效播放 (維持原樣) ---
func play_spatial_sfx(sfx, global_pos: Vector2, volume_db: float = 0.0, pitch_variation: float = 0.2):
	var stream = _get_stream(sfx)
	if not stream: return
	
	var instance = spatial_audio_scene.instantiate()
	get_tree().current_scene.add_child(instance)
	instance.global_position = global_pos
	
	var final_pitch = 1.0 + randf_range(-pitch_variation, pitch_variation)
	instance.setup(stream, volume_db, final_pitch)
