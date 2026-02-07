extends CharacterBody2D

@export var speed: float = 20.0 # 比玩家慢一點 (玩家是 300)
var player = null # 追蹤目標
var hp = 100


func _physics_process(delta):
	if player:
		# 計算與玩家的距離
		var distance = global_position.distance_to(player.global_position)
		
		# 【修改點】只有距離大於 25 像素時才移動 (避免貼身硬擠)
		if distance > 5.0:
			var direction = (player.global_position - global_position).normalized()
			velocity = direction * speed
		else:
			velocity = Vector2.ZERO # 夠近了就煞車
			
		move_and_slide()

# 偵測玩家進入範圍 (聽覺/嗅覺範圍)
func _on_detect_area_body_entered(body):
	if body.name == "Player":
		player = body
		print("怪物：我聞到你的恐懼了...")

# (選做) 玩家逃出範圍
func _on_detect_area_body_exited(body):
	if body == player:
		player = null
		velocity = Vector2.ZERO

func take_damage(amount, source_position = Vector2.ZERO):
	hp -= amount
	print("怪物受傷！剩餘血量：", hp)
	SoundManager.play_spatial_sfx("enemy_hurt", global_position, 0.0, 0.1)
	
	# 受傷視覺反饋：閃爍一下
	var tween = create_tween()
	tween.tween_property($Sprite2D, "modulate", Color(10, 10, 10, 1), 0.05) # 變超亮
	tween.tween_property($Sprite2D, "modulate", Color.WHITE, 0.2) # 變回原色
	
	# hit_stop(0.1)
	# 【新增】擊退效果 (Knockback)
	# 如果傳入的來源位置不是零向量，就計算擊退
	if source_position != Vector2.ZERO:
		var knockback_dir = (global_position - source_position).normalized()
		velocity = knockback_dir * 800 # 擊退力道
		move_and_slide() # 立即執行一次移動以免卡住
	
	
	if hp <= 0:
		die()

func die():
	SoundManager.play_spatial_sfx("enemy_die", global_position, 0.0, 0.1)
	print("怪物死亡！")
	queue_free() # 刪除自己
	
# enemy.gd
func _on_hitbox_body_entered(body):
	if body.name == "Player":
		if body.has_method("take_damage"):
			# 造成傷害
			body.take_damage(10, global_position)
			
			# 【修正點在此】
			# 原本寫 player.global_position，但 player 可能是 null
			# 改用 body.global_position (body 就是撞上來的玩家，絕對存在)
			var knockback_dir = (global_position - body.global_position).normalized()
			
			velocity = knockback_dir * 1000
			move_and_slide()

func save():
	return {
		"filename" : get_scene_file_path(), # 為了知道要生成哪個場景 (res://enemy.tscn)
		"parent" : get_parent().get_path(), # 為了知道要掛在哪個節點下
		"pos_x" : global_position.x,
		"pos_y" : global_position.y,
		"hp" : hp,
		# 這裡可以加更多，例如 "is_alerted": false
	}

func hit_stop(duration: float):
	# 1. 將時間流速變為極慢 (例如原本的 5%)
	# 為什麼不設為 0？因為設為 0 有時會導致 divide_by_zero 的物理錯誤，0.05 效果幾乎一樣
	Engine.time_scale = 0.001
	
	# 2. 等待真實世界的 duration 秒數
	# 關鍵！這裡不能用普通的 await get_tree().create_timer(duration).timeout
	# 因為普通的 Timer 也會受 time_scale 影響而被變慢 20 倍！
	# 我們要告訴 Timer：「請忽略時間縮放，使用真實時間」
	await get_tree().create_timer(duration, true, false, true).timeout
	
	# 3. 恢復時間流速
	Engine.time_scale = 1.0
