extends Area2D

var player_in_area = null
var can_interact

func _process(delta):
	if player_in_area and Input.is_action_just_pressed("ui_accept") and can_interact:
		can_interact = false
		if not DialogueManager.is_active:
			
			print("【DEBUG】條件成立，嘗試呼叫對話...")
			# 2. 開始對話
			DialogueManager.set_name_label("存檔點")
			DialogueManager.start_dialogue([
				"開啟存檔介面。"
			])
					
			# 3. 【關鍵】等待對話結束訊號
			# 程式會暫停在這行，直到 DialogueManager 發出 dialogue_finished 訊號
			await DialogueManager.dialogue_finished
		# 呼叫全域 UI (如果 SaveLoadWindow 是 Autoload 或是掛在 CanvasLayer)
		# 這裡建議把 SaveLoadWindow 做成一個獨立的 Autoload UI 場景
		# 或者在 World 場景裡也放一個 SaveLoadWindow
		print("szve point trigger")
		SaveLoadWindow.open(SaveLoadWindow.Mode.SAVE)
		
	

func _on_body_entered(body):
	print("進入存檔點")
	if body.is_in_group("player"):
		StoryManager.update_checkpoint(global_position)
		player_in_area = body

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_area = null
		can_interact = true
	
