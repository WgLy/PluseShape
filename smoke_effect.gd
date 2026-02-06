extends Node2D

# --- 參數設定 ---
@export var particle_count: int = 10      # 要產生幾團煙霧
@export var spread_distance: float = 100.0 # 煙霧擴散的半徑範圍
@export var duration: float = 10.0        # 煙霧存活時間
@export var scale_variation: Vector2 = Vector2(0.5, 1.5) # 隨機大小範圍 (最小, 最大)

# --- 內部變數 ---
@onready var template_sprite: Sprite2D = $smoke_particle # 取得子節點作為模板
var active_particles: int = 0 # 目前還存活的煙霧數量

func _ready() -> void:
	# 1. 隱藏並關閉模板的處理 (我們只用它來複製)
	if template_sprite:
		template_sprite.visible = false
		# 如果模板本身有掛腳本或物理碰撞，這裡可能需要額外處理
		# 但如果是單純的圖片，visible = false 即可
		
		# 2. 開始生成迴圈
		for i in range(particle_count):
			spawn_particle()
	else:
		print("錯誤：找不到子節點 Sprite2D！")
		queue_free()

func spawn_particle():
	# A. 複製模板
	var part = template_sprite.duplicate()
	add_child(part)
	
	# B. 初始化狀態
	part.visible = true
	part.position = Vector2.ZERO # 從中心點開始
	part.modulate.a = 1.0        # 確保不透明度是滿的
	
	# 隨機大小
	var rand_scale = randf_range(scale_variation.x, scale_variation.y)
	part.scale = Vector2(rand_scale, rand_scale)
	
	# C. 計算隨機擴散方向
	# 隨機角度 (0 ~ 2 PI)
	var angle = randf() * TAU 
	# 隨機距離 (為了讓煙霧不要變成一個完美的圓圈，距離也要隨機)
	var distance = randf_range(spread_distance * 0.5, spread_distance)
	# 計算目標座標
	var target_pos = Vector2(cos(angle), sin(angle)) * distance
	
	# 增加計數
	active_particles += 1
	
	# D. 建立動畫
	var tween = create_tween()
	tween.set_parallel(true) # 讓移動、透明度、縮放同時發生
	
	# 設定 "先快後慢" 的曲線 (Ease Out + Cubic/Quart/Expo)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 1. 移動：向外擴散
	tween.tween_property(part, "position", target_pos, duration)
	
	# 2. 透明度：變為 0 (這部分可以用 Linear，或是稍微延遲一點再淡出)
	tween.tween_property(part, "modulate:a", 0.0, duration)
	
	# 3. (選用) 縮放：稍微變大一點，更有煙霧感
	tween.tween_property(part, "scale", part.scale * 1.5, duration)
	
	# E. 動畫結束後的清理工作
	# 使用 chain() 確保動畫跑完才執行 callback
	tween.chain().tween_callback(func(): _on_particle_finished(part))

func _on_particle_finished(part: Sprite2D):
	# 1. 刪除該顆粒子
	part.queue_free()
	
	# 2. 減少計數
	active_particles -= 1
	
	# 3. 檢查是否全部結束
	if active_particles <= 0:
		# 所有煙霧都散去了，刪除管理器自己
		queue_free()
