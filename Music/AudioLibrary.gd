# AudioLibrary.gd
extends Node

# 使用 Dictionary 存儲所有音效路徑
# 格式： "音效ID": "res://檔案路徑"
var sounds = {
	# --- UI 音效 ---
	"ui_click": "res://Music/SoundResource/UI Soundpack/UI Soundpack/WAV/Minimalist11.wav",
	
	# --- 玩家音效 ---
	"player_attack": "res://Music/SoundResource/Minifantasy_Dungeon_SFX/27_sword_miss_1.wav", # apply
	"player_dash": "res://Music/SoundResource/Minifantasy_Dungeon_SFX/15_human_dash_1.wav", # apply
	"sonar_pluse": "res://Music/SoundResource/sonar_pluse.wav",

	# --- 怪物音效 ---
	"enemy_hurt": "res://Music/SoundResource/Minifantasy_Dungeon_SFX/11_human_damage_1.wav", # apply
	"enemy_die": "res://Music/SoundResource/Minifantasy_Dungeon_SFX/12_human_die_1.wav", # apply
	"enemy_dash": "res://Music/SoundResource/Minifantasy_Dungeon_SFX/10_human_special_atk_2.wav", # apply
	"enemy_shock": "res://Music/SoundResource/shock.wav",
	
	# --- 物品音效 ---
	"fall_rock_shock": "res://Music/SoundResource/fall_rock_shock.wav",
	
	# --- 環境音效 ---
	"door_toggle": "res://Music/SoundResource/Minifantasy_Dungeon_SFX/04_sack_open_1.wav", # apply
	"rock_hit": "res://Music/SoundResource/UI Soundpack/UI Soundpack/WAV/Minimalist12.wav" # apply
}

# 簡單的查詢函式
func get_audio_path(sfx_name: String) -> String:
	if sounds.has(sfx_name):
		return sounds[sfx_name]
	else:
		push_warning("找不到音效名稱: " + sfx_name)
		return ""
