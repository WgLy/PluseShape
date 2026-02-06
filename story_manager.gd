extends Node

# 連結節點
@onready var cutscene_layer = $CutsceneLayer
@onready var overlay_screen = $CutsceneLayer/OverlayScreen
@onready var sfx_player = $CutsceneLayer/AudioStreamPlayer

# 請將這裡換成你的機械音效路徑
var machine_sfx# = preload("res://sfx/machine_hum.wav") 

# --- 新增變數：紀錄重生點 ---
# 預設為 (0,0)，建議在 Player _ready 時呼叫 update_checkpoint 更新一次
var current_checkpoint_pos: Vector2 = Vector2.ZERO

func update_checkpoint(new_pos: Vector2):
	current_checkpoint_pos = new_pos
	print("存檔點已更新: ", current_checkpoint_pos)

func _ready():
	# 遊戲開始時先隱藏 UI 層，以免擋住編輯器畫面
	cutscene_layer.visible = false
	
	# 如果你是從標題畫面進入，請由 TitleScreen 呼叫這個函式
	# 如果是直接執行場景測試，請取消下面這行的註解：
	# play_new_game_sequence()

func play_new_game_sequence():
	var player = get_tree().get_first_node_in_group("player")
	var woman_npc = get_tree().get_first_node_in_group("story_woman")
	var health_bar = get_tree().get_first_node_in_group("health_bar")
	
	# 1. 鎖定並隱藏玩家
	if player: 
		player.can_move = false
		# player.visible = false 
		# 確保聲納能力此時是關閉的，以免玩家亂按提早發光
		player.can_sonar_ability = false 

	if health_bar :
		health_bar.visible = false

	# 2. 初始化畫面：全黑
	cutscene_layer.visible = true
	overlay_screen.color = Color.BLACK # 設定為黑幕
	overlay_screen.modulate.a = 1.0    # 確保不透明

	# ==========================================
	# 第一階段：實驗室對話 (自動推進)
	# ==========================================
	
	var intro_lines = [
		{"text": "實驗準備就緒了嗎？", "time": 2.0},
		{"text": "線路一切正常。", "time": 1.5},
		{"text": "......電力輸出沒有問題。", "time": 2.0},
		{"text": "等等，系統程式好像出了些問題。", "time": 2.5},
		{"text": "現在可以解決嗎？", "time": 1.5},
		{"text": "等我修改一下。", "time": 1.5},
		{"text": "......他好像有點痛苦。要不我們還是延後吧。等到一切確實準備完成後再......", "time": 3.0},
		{"text": "在說什麼傻話！為了這項研究，我們已經花了多久你自己心知肚明！", "time": 3.5},
		{"text": "好不容易找到了一個如此合適的實驗體，況且我們時間也不多了，必須在現在執行！", "time": 4.0},
		{"text": "報告長官，程式已修改無誤。", "time": 2.0},
		{"text": "那就開始吧。該為這一系列的研究畫下個句點了。", "time": 3.0},
		{"text": "等──", "time": 0.5}
	]
	
	# 呼叫對話管理器 (傳入空字串 "" 作為圖片 ID，只顯示文字框)
	DialogueManager.set_name_label("???") 
	DialogueManager.start_auto_dialogue(intro_lines, "") 
	
	# 等待對話結束
	await DialogueManager.dialogue_finished
	if player: 
		player.can_move = false 
		player.velocity = Vector2.ZERO # 確保慣性也歸零
	# ==========================================
	# 第二階段：故障 (黑 -> 白 -> 斷電)
	# ==========================================
	
	if sfx_player and machine_sfx:
		sfx_player.stream = machine_sfx
		sfx_player.play()
	
	var tween = create_tween()
	# 聲音變尖銳、變大聲
	if sfx_player:
		tween.parallel().tween_property(sfx_player, "pitch_scale", 3.0, 3.0)
		tween.parallel().tween_property(sfx_player, "volume_db", 10.0, 3.0)
	
	# 畫面從 黑 漸變到 白 (模擬過載強光)
	# 我們重複利用 OverlayScreen，直接改變它的顏色
	tween.parallel().tween_property(overlay_screen, "color", Color.WHITE, 3.0).set_ease(Tween.EASE_IN)
	
	await tween.finished
	
	# 斷電瞬間
	if sfx_player:
		sfx_player.stop()
	
	# ==========================================
	# 第三階段：切換到世界黑暗 (World Darkness)
	# ==========================================
	
	# 這裡很重要：我們要把 UI 的遮擋拿掉，讓 CanvasModulate 接手
	# 視覺上玩家會覺得「沒變」，因為兩個都是黑的
	# 但實際上我們從「看著一張黑紙」變成了「看著關燈的房間」
	
	overlay_screen.color = Color.BLACK # 瞬間變回黑色 (或設透明)
	overlay_screen.modulate.a = 0.0    # 讓 UI 層完全隱藏
	
	# 黑暗中沉默 3 秒
	await get_tree().create_timer(3.0).timeout
	
	# ==========================================
	# 第四階段：喚醒循環
	# ==========================================
	
	if woman_npc and woman_npc.has_method("say"): # 假設你的 speech_bubble 邏輯封裝在 woman.say()
		
		# 【關鍵】在此刻默默解鎖聲納能力
		# 這樣當玩家按下空白鍵跳出迴圈的那一瞬間，也能觸發 Player.gd 裡的 fire_sonar()
		if player: player.can_sonar_ability = true
		
		var wake_up_lines = [
			"「你醒來了嗎？」",
			"「你沒事吧？」",
			"「醒來的話給我個反應可以嗎？」"
		]
		var line_index = 0
		
		# 循環直到按下空白鍵
		while not Input.is_action_just_pressed("ui_accept"):
			
			# 讓 Woman 說話 (Unshaded 氣泡會在黑暗中發亮)
			if line_index == 2:
				woman_npc.say(wake_up_lines[line_index], 3.0)
				if await wait_input(2.0): break 
			else :
				woman_npc.say(wake_up_lines[line_index], 2.0)
			
			# 等待 2.5 秒，期間偵測輸入
			if await wait_input(2.5): break 
			
			# 間隔 1 秒
			if await wait_input(1.0): break
			
			line_index = (line_index + 1) % wake_up_lines.size()
			
		# 玩家按下空白鍵後：
		woman_npc.speech_bubble.visible = false # 強制關閉氣泡
		
	# ==========================================
	# 遊戲開始
	# ==========================================
	
	cutscene_layer.visible = false # 關閉整個過場層
	
	if player:
		player.visible = true
		player.can_move = true
		print("劇情結束，玩家甦醒，聲納已發射")
	if health_bar :
		health_bar.visible = true
		
	
func play_death_sequence():
	var player = get_tree().get_first_node_in_group("player")
	var health_bar = get_tree().get_first_node_in_group("health_bar")
	
	print("播放死亡動畫...")

	# 1. 鎖定玩家操作 & 隱藏 UI
	if player:
		player.can_move = false
		player.velocity = Vector2.ZERO # 停止移動
		player.can_sonar_ability = false # 禁止死掉時亂發光
		# 如果你的 Player 有無敵狀態變數，建議在這裡開啟，以免黑幕中被怪打
		if "is_invincible" in player: player.is_invincible = true
			
	if health_bar:
		health_bar.visible = false

	# 2. 畫面漸暗 (Fade Out)
	cutscene_layer.visible = true
	overlay_screen.color = Color.BLACK 
	overlay_screen.modulate.a = 0.0 # 從透明開始
	
	var tween = create_tween()
	# 1.5秒內變全黑
	tween.tween_property(overlay_screen, "modulate:a", 1.0, 1.5)
	
	await tween.finished
	
	# 3. 播放死亡獨白 (可自訂)
	var death_lines = [
		{"text": "到此為止了嗎......", "time": 2.0},
		{"text": "[color=red]『允你復活。』[/color]", "time": 2.0},
		{"text": "必須......再試一次。", "time": 2.0}
	]
	
	DialogueManager.set_name_label("") # 不需要名字
	DialogueManager.start_auto_dialogue(death_lines, "")
	
	await DialogueManager.dialogue_finished
	
	# 4. 執行復活邏輯 (在黑幕遮擋下進行)
	if player:
		# 重置位置
		player.global_position = current_checkpoint_pos
		
		# 重置血量 (假設你的 Player 有 reset_hp 或類似函式)
		if player.has_method("reset_hp"):
			player.reset_hp()
		else:
			print("cannot reset hp")

		# 重置無敵狀態
		if "is_invincible" in player: player.is_invincible = false
		
		# 如果場上有需要重置的敵人或機關，可以在這裡發送訊號
		# get_tree().call_group("enemies", "reset_position") 

	# 稍作停頓，讓玩家準備好
	await get_tree().create_timer(1.0).timeout

	# 5. 畫面漸亮 (Fade In)
	var tween_in = create_tween()
	tween_in.tween_property(overlay_screen, "modulate:a", 0.0, 1.5) # 1.5秒變透明
	
	await tween_in.finished
	
	# 6. 恢復遊戲控制
	cutscene_layer.visible = false # 隱藏遮罩層
	if health_bar: health_bar.visible = true
	
	if player:
		player.can_move = true
		player.can_sonar_ability = true
		print("玩家已復活")

# --- 輔助函式 ---
func wait_input(duration: float) -> bool:
	var t = 0.0
	while t < duration:
		if Input.is_action_just_pressed("ui_accept"):
			return true
		t += get_process_delta_time()
		await get_tree().process_frame
	return false
