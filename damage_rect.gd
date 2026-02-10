extends TextureRect

var _tween: Tween

func _ready():
	# 初始化：確保透明且不擋滑鼠
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

# ==========================================================
#       通用特效函式 (內部使用)
# ==========================================================
func _play_effect(target_color: Color):
	# 1. 設定顏色 (這就是為什麼原圖要白色的原因)
	# 我們先設定顏色，但保留目前的 alpha 值 (或是重置為 0)
	modulate = target_color
	modulate.a = 0.0 
	
	if _tween: _tween.kill()
	_tween = create_tween()
	
	# 階段 1: 瞬間顯示
	_tween.tween_property(self, "modulate:a", 1.0, 0.1)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	# 階段 2: 緩慢淡出
	_tween.chain().tween_property(self, "modulate:a", 0.0, 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

# ==========================================================
#       公開介面 (給 Player 呼叫)
# ==========================================================

# 播放受傷 (紅色)
func play_damage_effect():
	_play_effect(Color(1, 0, 0)) # 純紅

# 播放補血 (綠色)
func play_heal_effect():
	_play_effect(Color(0, 1, 0)) # 純綠
