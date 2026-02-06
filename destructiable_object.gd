extends CharacterBody2D

# --- 設定區塊 ---
@export_group("Configuration")
@export var type: String = "default"         # 用來決定血量
@export var shape_type: String = "round"     # "round" 或 "rectangle"，用來決定外觀與碰撞

@export_group("Shape Resources")
# 【重要】請在 Inspector 把你的 CircleShape2D 和 RectangleShape2D 拖進這兩個欄位
@export var shape_round: Shape2D 
@export var shape_rect: Shape2D 

# --- 內部變數 ---
var hp: int
var initialhp = {
	"default": 1,
	"healthbull": 100,
	"fall_rock": 30
}

# --- 節點參照 ---
# 取得唯一的碰撞節點
@onready var collision_node: CollisionShape2D = $CollisionShape2D

# 取得視覺容器節點 (假設你的場景結構如下)
# Visuals (Node2D)
#   |- RoundArt (Node2D) -> 裡面放圓形的 Sprite2D
#   |- RectArt (Node2D)  -> 裡面放方形的 Sprite2D
@onready var visuals = {
	"round": $Visuals/RoundArt,
	"rectangle": $Visuals/RectArt
}

func _ready() -> void:
	# 1. 初始化血量 (使用 get 來避免找不到 key 報錯，預設給 1)
	hp = initialhp.get(type, 1)
	
	if hint:
		hint.scale = Vector2.ZERO
		hint.modulate.a = 1
	
	# 2. 初始化形狀與外觀
	update_shape()

func update_shape():
	# --- A. 切換物理碰撞形狀 ---
	# 這裡加入了 disabled = false 的保險機制，確保切換後碰撞是開啟的
	if shape_type == "round" and shape_round:
		collision_node.shape = shape_round
		collision_node.disabled = false 
		
	elif shape_type == "rectangle" and shape_rect:
		collision_node.shape = shape_rect
		collision_node.disabled = false
		
	else:
		# 如果沒設定 Resource，為了安全起見，可以選擇停用碰撞或報錯
		print("警告：DestructibleObject 缺少對應的 Shape Resource 設定！")
		# collision_node.disabled = true 
	
	# --- B. 切換視覺顯示 ---
	for key in visuals:
		var visual_node = visuals[key]
		if visual_node:
			if key == shape_type:
				visual_node.visible = true
			else:
				visual_node.visible = false

# --- 受傷邏輯 ---
func take_damage(amount, source_position = Vector2.ZERO):
	hp -= amount
	
	# --- 視覺反饋：閃爍 ---
	# 我們只讓「目前顯示中」的那個圖案閃爍
	var active_visual = visuals.get(shape_type)
	if active_visual:
		# 嘗試抓取容器底下的 Sprite2D
		var sprite = active_visual.get_node_or_null("Sprite2D")
		if sprite:
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(10, 10, 10, 1), 0.05) # 變超亮
			tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)      # 變回原色
	
	if hp <= 0:
		die()

func die():
	# 這裡可以加入播放音效或生成破碎粒子的邏輯
	queue_free() # 刪除自己


@onready var hint: Sprite2D = $Hint
var _tween: Tween
var duriation: float = 0.5

func show_hint():
	# initialize
	if hint:
		hint.scale = Vector2.ZERO
		hint.modulate.a = 1
	
	if not _tween == null :
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true) 
	_tween.tween_property(hint, "scale", Vector2(1.6, 1.6), duriation)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# --- 階段 2: 停留 (關鍵！) ---
	# chain() 會等待上面的彈出動畫結束
	# 然後我們加入一個 interval (空白時間) 讓玩家閱讀
	_tween.chain().tween_interval(1.5) # 停留 1.5 秒
	
	# --- 階段 3: 淡出 ---
	# chain() 會等待上面的 interval 結束
	# 然後執行淡出
	_tween.chain().tween_property(hint, "modulate:a", 0.0, duriation)
	
func _on_recieve_detect_signal():
	show_hint()


func _on_detect_area_body_entered(body: Node2D) -> void:
	# 1. 判斷是否為玩家 (建議檢查 Group)
	if body.is_in_group("player"): # 或是 body.name == "Player"
		# 2. 確認玩家腳本中有這個訊號，且尚未連接
		if body.has_signal("detect_interactable"):
			if not body.detect_interactable.is_connected(_on_recieve_detect_signal):
				# 3. 進行連接：當玩家發出 detect_interactable -> 執行我的 _on_recieve_detect_signal
				body.detect_interactable.connect(_on_recieve_detect_signal)


func _on_detect_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		# 4. 離開時斷開連接 (重要！避免報錯或遠端觸發)
		if body.has_signal("detect_interactable"):
			if body.detect_interactable.is_connected(_on_recieve_detect_signal):
				body.detect_interactable.disconnect(_on_recieve_detect_signal)
