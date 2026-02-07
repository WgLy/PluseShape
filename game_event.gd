# GameEvents.gd (Autoload)
extends Node

# 定義聲音事件訊號 (給怪物聽的)
# source_position: 聲源座標
# logic_range: 怪物能聽到的範圍
# type: 聲音類型 ("sonar", "impact", "footstep")
signal sound_emitted(source_position: Vector2, logic_range: float, type: String)

# --- 統一呼叫接口 ---
# 這是你在 Player 或 Rock 腳本中唯一需要呼叫的函式
# audio_stream: 要播放的音效資源 (可以是 null，代表無聲只有訊號)
# logic_range: 引怪範圍 (若為 0 則不發送訊號，只播音效)
func create_noise(pos: Vector2, audio_stream: AudioStream, logic_range: float = 0.0, type: String = "general"):
	# 1. 處理聽覺輸出 (給玩家聽)
	if audio_stream:
		# 假設你有一個 AudioManager，沒有的話這裡可以先暫時用臨時播放器
		# AudioManager.play_sfx_at(pos, audio_stream) 
		# SoundManager.play_spatial_sfx("emeny_shock", pos, 0.0, 0.1)
		pass
	# 2. 處理邏輯訊號 (給怪物聽)
	if logic_range > 0:
		emit_signal("sound_emitted", pos, logic_range, type)
