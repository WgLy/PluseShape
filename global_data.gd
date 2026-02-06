extends Node

const ACHIEVEMENTS_PATH = "user://achievements.save"

# 定義成就清單 (key: 是否達成)
var achievements = {
	"first_kill": false,
	"stone_master": false,
	"game_clear": false
}

func _ready():
	load_achievements()

func unlock_achievement(key: String):
	if key in achievements and not achievements[key]:
		achievements[key] = true
		save_achievements()
		# 這裡可以呼叫 UI 顯示 "成就解鎖！" 的小通知
		print("成就解鎖：", key)

func save_achievements():
	var file = FileAccess.open(ACHIEVEMENTS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(achievements))

func load_achievements():
	if FileAccess.file_exists(ACHIEVEMENTS_PATH):
		var file = FileAccess.open(ACHIEVEMENTS_PATH, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		if data:
			# 合併讀取的資料 (避免版本更新後新成就被覆蓋掉)
			for key in data:
				if key in achievements:
					achievements[key] = data[key]
