extends Node

# 基礎路徑，%s 會被替換成數字
const SAVE_PATH_TEMPLATE = "user://save_%s.json"
const MAX_SLOTS = 50

# 取得某個存檔槽的路徑
func get_save_path(slot_id: int) -> String:
	return SAVE_PATH_TEMPLATE % str(slot_id)

# 檢查該槽位是否有存檔
func save_exists(slot_id: int) -> bool:
	return FileAccess.file_exists(get_save_path(slot_id))

# 【修改】存檔：多加一個 slot_id 參數
func save_game(slot_id: int):
	var save_data = {
		"scene_path": get_tree().current_scene.scene_file_path,
		"player": get_tree().get_first_node_in_group("player").save(),
		"objects": [],
		# 新增：存檔時間與地點名稱，用於顯示在存檔介面上
		"timestamp": Time.get_datetime_string_from_system(),
		"location_name": "未知的荒野" # 之後可以根據地圖名稱變更
	}
	
	# ... (中間收集 objects 的邏輯保持不變) ...
	var persist_nodes = get_tree().get_nodes_in_group("persist")
	for node in persist_nodes:
		if node.has_method("save"):
			save_data["objects"].append(node.save())

	# 寫入檔案
	var file = FileAccess.open(get_save_path(slot_id), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		print("存檔成功：Slot ", slot_id)

# 【修改】讀檔：多加一個 slot_id 參數
func load_game(slot_id: int):
	var path = get_save_path(slot_id)
	if not FileAccess.file_exists(path): return
	
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK: return
	var data = json.get_data()
	
	# 切換場景 (使用淡入淡出，稍後會寫 SceneTransition)
	SceneTransition.change_scene(data["scene_path"])
	
	await SceneTransition.transition_finished # 等待轉場變黑且場景載入完成
	
	# ... (中間清空物件與生成物件的邏輯保持不變) ...
	# 注意：這裡要配合 SceneTransition 的邏輯，確保在場景載入後才執行還原
	_restore_data(data)

# 將還原邏輯獨立出來，方便呼叫
func _restore_data(data):
	# 【保險 1】多等兩個 Frame，確保新場景 (World) 已經完全載入並掛在 Root 底下
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 刪除舊物件 (如果場景剛載入，其實只有預設物件)
	var existing_nodes = get_tree().get_nodes_in_group("persist")
	for node in existing_nodes:
		node.queue_free()
		
	# 確保刪除動作完成
	await get_tree().process_frame
	
	# --- 還原玩家 ---
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.load_data(data["player"])
	else:
		print("錯誤：在新場景中找不到玩家節點！")
	
	# --- 還原物件 ---
	for obj_data in data["objects"]:
		# 檢查檔案是否存在 (防止因為改檔名導致崩潰)
		if not FileAccess.file_exists(obj_data["filename"]):
			print("讀檔警告：找不到檔案 ", obj_data["filename"])
			continue
			
		var new_obj = load(obj_data["filename"]).instantiate()
		
		# 【保險 2】嘗試尋找原本的父節點 (通常是 /root/world)
		var parent_node = get_node_or_null(obj_data["parent"])
		
		if parent_node:
			parent_node.add_child(new_obj)
			# 設定位置與屬性
			new_obj.global_position = Vector2(obj_data["pos_x"], obj_data["pos_y"])
			if "hp" in obj_data: new_obj.hp = obj_data["hp"]
		else:
			# 如果找不到原本的爸爸 (例如場景改名了)，就改掛在當前場景的根節點底下
			print("讀檔警告：找不到父節點 ", obj_data["parent"], "，改掛載到當前場景。")
			get_tree().current_scene.add_child(new_obj)
			# 依然要設定位置
			new_obj.global_position = Vector2(obj_data["pos_x"], obj_data["pos_y"])

	print("讀檔成功！環境已還原。")

# 【新增】取得存檔預覽資訊 (給 UI 用)
func get_save_info(slot_id: int) -> Dictionary:
	var path = get_save_path(slot_id)
	if not FileAccess.file_exists(path):
		return {} # 空字典代表沒存檔
	
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data = json.get_data()
		# 只回傳需要的顯示資訊
		return {
			"timestamp": data.get("timestamp", "未知時間"),
			"location": data.get("location_name", "未知地點")
		}
	return {}
