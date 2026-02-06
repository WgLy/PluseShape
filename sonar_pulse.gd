extends PointLight2D

var max_scale = 60.0 # 聲納最大擴散倍率
var expand_speed = 10.0 # 擴散速度


func _process(delta):
	# 每一幀都變大
	texture_scale += expand_speed * delta
	
	# 越變大越暗 (能量衰減)
	energy = 2.0 * (1.0 - (texture_scale / max_scale))
	
	# 超過最大範圍就自我銷毀
	if texture_scale >= max_scale:
		queue_free() # 從記憶體中刪除
