# SoundManager.gd
extends Node

var spatial_audio_scene = preload("res://Music/spatial_audio_player.tscn")

# 音效快取池
var loaded_streams: Dictionary = {}

# --- 內部輔助：根據名稱取得 AudioStream ---
func _get_stream(key_or_stream) -> AudioStream:
	if key_or_stream is AudioStream:
		return key_or_stream
		
	if key_or_stream is String:
		var sfx_name = key_or_stream
		
		if loaded_streams.has(sfx_name):
			return loaded_streams[sfx_name]
			
		var path = AudioLibrary.get_audio_path(sfx_name)
		if path == "": return null
		
		var stream = load(path)
		if stream:
			loaded_streams[sfx_name] = stream
			return stream
			
	return null

# --- 1. 一般音效播放 (介面更新) ---
# 【修改】新增 pitch_variation 參數，預設為 0.1 (即 +/- 10% 變化)
func play_sfx(sfx, pitch_scale: float = 1.0, pitch_variation: float = 0.1):
	var stream = _get_stream(sfx)
	if not stream: return
	
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "SFX"
	
	# 【關鍵邏輯】計算隨機音高
	# randf_range(-0.1, 0.1) 會產生 -0.1 到 0.1 之間的隨機數
	# 加上原本的 pitch_scale (通常是 1.0)，結果就會是 0.9 ~ 1.1
	var final_pitch = pitch_scale + randf_range(-pitch_variation, pitch_variation)
	player.pitch_scale = final_pitch
	
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

# --- 2. 空間音效播放 (介面更新) ---
# 【修改】將 pitch_variation 預設值改為 0.1
func play_spatial_sfx(sfx, global_pos: Vector2, volume_db: float = 0.0, pitch_variation: float = 0.2):
	var stream = _get_stream(sfx)
	if not stream: return
	
	var instance = spatial_audio_scene.instantiate()
	get_tree().current_scene.add_child(instance)
	instance.global_position = global_pos
	
	# 【關鍵邏輯】這裡原本就有寫，現在因為預設值改了，自動會有 +/- 10% 效果
	var final_pitch = 1.0 + randf_range(-pitch_variation, pitch_variation)
	instance.setup(stream, volume_db, final_pitch)
