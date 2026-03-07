## bag_ui.gd
## 背包 UI 控制器
## 負責管理玩家背包介面的所有互動邏輯，包含：
##   - 物品的拿起、放下、交換、堆疊、平分
##   - 滑鼠跟隨圖示（mouse_item）
##   - 建造預覽（build_preview）的顯示與隱藏
##   - 背包開關與資料同步
extends Control

# ==========================================
# 節點參考 (Node References)
# ==========================================

## 背包主格子區：GridContainer，用 % 進行唯一名稱存取
@onready var bag_slot_container: GridContainer = %BagSlotContainer

## 快捷欄容器：HBoxContainer，用 % 進行唯一名稱存取
@onready var hot_bar_container: HBoxContainer = %HotBarContainer

## 所有 UI 格子的集合：快捷欄格子 + 背包格子，合併成一個陣列以統一處理
## 索引 0 ~ (快捷欄格子數-1) 為快捷欄，之後為背包
@onready var all_ui_slots: Array = hot_bar_container.get_children() + bag_slot_container.get_children()

# ==========================================
# 資料與場景參考 (Data & Scene References)
# ==========================================

## 玩家的背包資料資源（Inventory Resource），預先載入固定路徑
## 此資源可在外部透過 set_player_inventory() 替換
var inventory_data: Inventory = preload("res://player/player_inventory.tres")

## 格子物品圖示的 PackedScene，用於動態實例化物品 UI 節點
@onready var item_icon_scene: PackedScene = preload("res://ui/slot_item.tscn")

## 建造預覽的 PackedScene，用於動態實例化地圖上的預覽節點
@onready var build_preview_scene: PackedScene = preload("res://ui/build_preview.tscn")

# ==========================================
# 執行時狀態 (Runtime State)
# ==========================================

## 目前被滑鼠「拿著」的物品圖示節點
## 若為 null，表示玩家手上什麼都沒有
var mouse_item: SlotItem = null

## 建造預覽節點的參考（建塔/生怪蛋時顯示在地圖上的半透明預覽）
var build_preview: BuildPreview = null


# ==========================================
# 生命週期函式 (Lifecycle Functions)
# ==========================================

## _ready：節點進入場景樹時自動呼叫
## 執行初始化：連接訊號、關閉背包、設定格子索引、實例化建造預覽
func _ready() -> void:
	# 為所有格子按鈕連接左鍵與右鍵的訊號
	connect_slot_signals()
	
	# 預設關閉背包介面（隱藏）
	close_bag()
	
	# 依序設定每個格子的索引編號（slot_index），方便之後對資料庫進行定位操作
	for i in range(all_ui_slots.size()):
		var slot = all_ui_slots[i]
		slot.slot_index = i
		
	# 實例化建造預覽節點，並延遲加入根節點（避免初始化順序問題）
	build_preview = build_preview_scene.instantiate()
	get_tree().root.call_deferred("add_child", build_preview)


## _process：每幀呼叫，用於更新滑鼠跟隨物品的位置與建造預覽狀態
func _process(_delta: float) -> void:
	if mouse_item:
		# 讓滑鼠拿著的物品圖示跟隨滑鼠位置移動
		mouse_item.global_position = get_global_mouse_position()
		
		# 若手上拿著的是「防禦塔資料」或「生怪蛋資料」，顯示建造預覽
		if mouse_item.slot_data and (mouse_item.slot_data.item is TowerData or mouse_item.slot_data.item is SpawnItemData):
			if not build_preview.is_active:
				build_preview.activate()
		else:
			# 手上拿著其他物品，關閉建造預覽
			if build_preview.is_active:
				build_preview.deactivate()
	else:
		# 手上沒東西，確保建造預覽不顯示
		if build_preview and build_preview.is_active:
			build_preview.deactivate()


## _unhandled_input：處理未被其他節點消耗的輸入事件
## 主要負責「在地圖上點擊放置防禦塔或生怪蛋」的邏輯
func _unhandled_input(event: InputEvent) -> void:
	# 只處理滑鼠左鍵按下事件
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		
		# ── 情況 A：手上拿著防禦塔 ──
		if mouse_item and mouse_item.slot_data and mouse_item.slot_data.item is TowerData:
			# 將螢幕座標轉換為世界座標（考慮攝影機 Transform）
			var world_pos = get_viewport().get_canvas_transform().affine_inverse() * event.position
			# 再將世界座標轉換為格子座標
			var grid_pos = MapManager.world_to_grid(world_pos)
			
			if MapManager.is_buildable(grid_pos):
				# 取得防禦塔資料
				var tower_data = mouse_item.slot_data.item as TowerData
				if tower_data.tower_scene:
					# 實例化防禦塔並加入目前場景
					var tower = tower_data.tower_scene.instantiate()
					get_tree().current_scene.add_child(tower)
					# 通知 MapManager 在該格子放置防禦塔（更新地圖佔用狀態）
					MapManager.place_tower(grid_pos, tower)
					
					# 注入塔的數值資料（傷害、射程、攻速、血量）
					# 必須在 add_child 之後呼叫，確保 @onready 節點已初始化
					if tower.has_method("setup"):
						tower.setup(tower_data)
					
					# 消耗手上的一個道具
					consume_mouse_item()
		
		# ── 情況 B：手上拿著生怪蛋 ──
		elif mouse_item and mouse_item.slot_data and mouse_item.slot_data.item is SpawnItemData:
			# 生怪蛋放置邏輯
			var world_pos = get_viewport().get_canvas_transform().affine_inverse() * event.position
			var grid_pos = MapManager.world_to_grid(world_pos)
			
			if MapManager.is_buildable(grid_pos):
				# 將格子座標轉回世界座標作為生成位置
				var spawn_pos = MapManager.grid_to_world(grid_pos)
				# 嘗試使用道具生成實體
				var success = use_item(mouse_item.slot_data.item, spawn_pos)
				if success:
					# 使用成功後消耗道具
					consume_mouse_item()


## _exit_tree：節點從場景樹移除前呼叫
## 確保建造預覽節點被正確清除，避免記憶體洩漏
func _exit_tree() -> void:
	if is_instance_valid(build_preview):
		build_preview.queue_free()


# ==========================================
# 格子訊號連接 (Slot Signal Connection)
# ==========================================

## connect_slot_signals：為所有 UI 格子按鈕連接左鍵與右鍵點擊訊號
## 每次連接前先檢查是否已連接，避免重複綁定造成函式被呼叫多次
func connect_slot_signals() -> void:
	for slot_button in all_ui_slots:
		# 【修復小細節】：Godot 4 的 Callable 檢查必須包含 bind，否則每次都會以為沒綁定過
		# 為左鍵訊號建立帶有 slot_button 參數的 Callable
		var callable = mouse_left_slot_button.bind(slot_button)
		if not slot_button.mouse_button_left_press.is_connected(callable):
			slot_button.mouse_button_left_press.connect(callable)
		
		# 為右鍵訊號建立帶有 slot_button 參數的 Callable
		var right_callable = mouse_right_slot_button.bind(slot_button)
		if not slot_button.mouse_button_right_press.is_connected(right_callable):
			slot_button.mouse_button_right_press.connect(right_callable)
			

# ==========================================
# 背包 UI 同步 (Inventory UI Sync)
# ==========================================

## bag_update：將 inventory_data 資料同步到所有 UI 格子
## 此函式通常由 inventory_update 訊號自動觸發，無需手動頻繁呼叫
func bag_update() -> void:
	# 防呆：若資料格子數與 UI 格子數不符，印出錯誤並終止
	if inventory_data.slots.size() != all_ui_slots.size():
		printerr("錯誤：背包資料長度與 UI 格子數量不符！")
		return
		
	for i in range(all_ui_slots.size()):
		var current_slot_data: Slot = inventory_data.slots[i]
		var current_ui_box = all_ui_slots[i]
	
		# 若該格資料為空（或道具為空），清除 UI 格子後繼續下一格
		if not current_slot_data or not current_slot_data.item:
			current_ui_box.clear_box() 
			continue 
		
		# 取得目前 UI 格子內的物品圖示節點
		var item_icon: SlotItem = current_ui_box.contained_item_icon
		
		# 若格子內還沒有圖示節點，就實例化一個並插入
		if not item_icon:
			item_icon = item_icon_scene.instantiate()
			current_ui_box.insert(item_icon)
		
		# 更新圖示的資料並刷新顯示
		item_icon.slot_data = current_slot_data
		item_icon.slot_item_update()


# ==========================================
# 背包資料管理 (Inventory Data Management)
# ==========================================

## set_player_inventory：切換背包所綁定的 Inventory 資料
## 會先斷開舊資料的訊號，再連接新資料的訊號，並立即同步 UI
func set_player_inventory(player_inventory: Inventory) -> void:
	# 若舊資料已連接 bag_update 訊號，先斷開以避免資料混用
	if inventory_data and inventory_data.inventory_update.is_connected(bag_update):
		inventory_data.inventory_update.disconnect(bag_update)
	
	# 替換為新的背包資料
	inventory_data = player_inventory
	
	if inventory_data:
		# 連接新資料的更新訊號，之後資料有變動時會自動刷新 UI
		inventory_data.inventory_update.connect(bag_update)
		# 立即同步一次 UI，確保顯示與資料一致
		bag_update()


## open_bag：開啟背包介面，並綁定指定的 inventory 資料
func open_bag(player_inventory: Inventory) -> void:
	set_player_inventory(player_inventory)
	show()


## close_bag：關閉（隱藏）背包介面
func close_bag() -> void:
	hide()


# ==========================================
# 左鍵點擊邏輯 (Left-Click Logic)
# ==========================================

## mouse_left_slot_button：處理玩家左鍵點擊格子時的所有情況
## 依「格子是否有物品」與「手上是否有物品」分為三種情況
func mouse_left_slot_button(slot_button) -> void:
	# 情況 1：點擊空格 且 手上有東西 -> 放下物品
	if slot_button.is_empty() and mouse_item:
		insert_item_in_slot(slot_button)
		
	# 情況 2：點擊有東西的格子 且 手上沒東西 -> 拿起物品
	elif not slot_button.is_empty() and not mouse_item:
		take_item_from_slot(slot_button)
		
	# 情況 3：點擊有東西的格子 且 手上也有東西
	elif not slot_button.is_empty() and mouse_item:
		# 取得兩邊的資料
		var slot_data: Slot = slot_button.contained_item_icon.slot_data
		var hand_data: Slot = mouse_item.slot_data
		
		# 【判斷分支】：利用 is_same_item 判斷要堆疊還是交換
		if slot_data.is_same_item(hand_data):
			stack_items(slot_button)  # 相同道具 -> 執行堆疊邏輯
		else:
			swap_item_with_slot(slot_button) # 不同道具 -> 執行交換邏輯


## stack_items：將手上的物品堆疊到格子裡（僅限相同道具）
## 若合計數量超過堆疊上限，則格子塞滿，手上保留溢出的部分
func stack_items(slot_button) -> void:
	var slot_data: Slot = slot_button.contained_item_icon.slot_data
	var hand_data: Slot = mouse_item.slot_data
	# 取得該道具的堆疊上限
	var max_stack: int = slot_data.item.max_stack
	
	# 計算兩邊合計總數
	var total_amount: int = slot_data.count + hand_data.count
	
	if total_amount <= max_stack:
		# ── 情況 A：完美合併，合計未超出堆疊上限 ──
		# 1. 更新資料庫中該格子的數量
		inventory_data.set_slot_count(slot_button.slot_index, total_amount)
		
		# 2. 銷毀手上的道具節點，回復空手狀態
		mouse_item.queue_free()
		mouse_item = null
	else:
		# ── 情況 B：溢出與殘留，合計超出堆疊上限 ──
		# 1. 格子塞滿至上限
		inventory_data.set_slot_count(slot_button.slot_index, max_stack)
		
		# 2. 計算手上還剩多少並更新手上道具的資料
		hand_data.count = total_amount - max_stack
		
		# 3. 呼叫 UI 節點內建方法，讓它重新顯示剩餘的數字
		mouse_item.slot_item_update()


## take_item_from_slot：從格子中拿起物品到滑鼠上
## UI 節點的拿起由 slot_button.take_item() 完成，資料層由 inventory_data.remove_slot() 同步
func take_item_from_slot(slot_button) -> void:
	# 從 UI 格子取出物品圖示節點，並讓它跟隨滑鼠
	mouse_item = slot_button.take_item()
	
	if mouse_item:
		# 將物品圖示節點從格子移到 bag_ui 下（才能正確顯示在最上層）
		add_child(mouse_item)
		mouse_item.global_position = get_global_mouse_position()
		
		# 通知資料庫移除這筆格子資料
		inventory_data.remove_slot(mouse_item.slot_data)


## insert_item_in_slot：將手上的物品放入空格子
## 先移除滑鼠跟隨節點，再插入格子，最後通知資料庫寫入
func insert_item_in_slot(slot_button) -> void:
	var item = mouse_item
	# 將物品圖示節點從 bag_ui 底下移除
	remove_child(mouse_item)
	mouse_item = null
	
	# 將物品圖示節點插入目標格子（UI 層操作）
	slot_button.insert(item)
	
	# 通知資料庫在對應索引位置寫入這筆資料（資料層操作）
	inventory_data.insert_slot(slot_button.slot_index, item.slot_data)


## swap_item_with_slot：交換手上物品與格子裡的不同種物品
## 操作步驟：暫存 -> 拿出 -> 放入 -> 接手 -> 更新資料庫
func swap_item_with_slot(slot_button) -> void:
	# 1. 暫存：記住原本游標上的資料（用於最後寫入資料庫）
	var original_mouse_data: Slot = mouse_item.slot_data
	
	# 2. 拿出：把格子裡原本的道具拿出來（UI 層操作），暫存為 temp_item
	var temp_item: SlotItem = slot_button.take_item()
	
	# 3. 放入：把手上的道具圖示從 bag_ui 移除，再插入目標格子
	remove_child(mouse_item)
	slot_button.insert(mouse_item)
	
	# 4. 接手：讓原本格子裡的道具，變成玩家手上拿著的東西
	mouse_item = temp_item
	add_child(mouse_item)
	mouse_item.global_position = get_global_mouse_position() # 瞬間校正位置，防止閃爍
	
	# 5. 更新資料庫：將「原本手上的資料」覆蓋寫入目標格子
	#    insert_slot 會觸發 inventory_update 訊號，此時 UI 已換好，不會有衝突
	inventory_data.insert_slot(slot_button.slot_index, original_mouse_data)


# ==========================================
# 右鍵系統邏輯 (Right-Click Logic)
# ==========================================

## mouse_right_slot_button：處理玩家右鍵點擊格子時的所有情況
## 右鍵主要提供「平分拿起」與「單個放下」的精細操作
func mouse_right_slot_button(slot_button) -> void:
	# 情況 1：點擊有東西的格子 且 手上沒東西 -> 【平分拿起】
	if not slot_button.is_empty() and not mouse_item:
		split_half_from_slot(slot_button)
		
	# 情況 2：手上有東西 且 點擊空格 -> 【放 1 個到空格】
	elif slot_button.is_empty() and mouse_item:
		drop_one_to_slot(slot_button)
		
	# 情況 3：手上有東西 且 點擊有東西的格子
	elif not slot_button.is_empty() and mouse_item:
		var slot_data: Slot = slot_button.contained_item_icon.slot_data
		var hand_data: Slot = mouse_item.slot_data
		
		# 只有在「相同道具」且「格子未達堆疊上限」時，才允許【放 1 個進去】
		if slot_data.is_same_item(hand_data) and slot_data.count < slot_data.item.max_stack:
			drop_one_to_slot(slot_button)


## split_half_from_slot：從格子中平分拿起一半的物品（進位取整）
## 例：格子有 5 個 -> 手上拿 3 個，格子剩 2 個
##     格子有 1 個 -> 等同左鍵拿走全部
func split_half_from_slot(slot_button) -> void:
	var slot_data: Slot = slot_button.contained_item_icon.slot_data
	var total_count: int = slot_data.count
	
	# 數學計算：手上拿走一半（進位），剩下留在格子裡
	var hand_count: int = int((total_count + 1) / 2) 
	var left_count: int = total_count - hand_count   
	
	# ── 表現層（UI）處理 ──
	if left_count == 0:
		# 如果原本只有 1 個，平分後格子會變空，直接當作左鍵拿走全部
		take_item_from_slot(slot_button)
		return
		
	# 格子還有剩，需「憑空創造」一個新圖示給滑鼠
	mouse_item = item_icon_scene.instantiate()
	
	# 創造獨立的新資料（避免與格子裡的資料共用同一個記憶體位置）
	var new_hand_data = Slot.new()
	new_hand_data.item = slot_data.item
	new_hand_data.count = hand_count
	mouse_item.slot_data = new_hand_data
	
	# 讓新圖示顯示在畫面上並跟隨滑鼠
	add_child(mouse_item)
	mouse_item.global_position = get_global_mouse_position()
	mouse_item.slot_item_update()
	
	# ── 資料層（Data）處理 ──
	# 扣除被拿走的數量（sub_slot_count 會自動發出 inventory_update 訊號更新 UI）
	inventory_data.sub_slot_count(slot_button.slot_index, hand_count)


## drop_one_to_slot：將手上的物品單個放入目標格子
## 目標格子可以是空格（創建新項目）或相同道具的格子（直接 +1）
func drop_one_to_slot(slot_button) -> void:
	var hand_data: Slot = mouse_item.slot_data
	
	# ── 表現層（UI）與 資料層（Data）處理 ──
	if slot_button.is_empty():
		# ── 情況 A：丟 1 個到「空格子」──
		# 1. 創造格子裡的新圖示節點與新資料（數量為 1）
		var new_icon = item_icon_scene.instantiate()
		var new_slot_data = Slot.new()
		new_slot_data.item = hand_data.item
		new_slot_data.count = 1
		new_icon.slot_data = new_slot_data
		
		# 2. 將新圖示塞入 UI 格子並更新顯示
		slot_button.insert(new_icon)
		new_icon.slot_item_update()
		
		# 3. 寫入資料庫（覆蓋空格）
		inventory_data.update_slot(slot_button.slot_index, new_slot_data)
		
	else:
		# ── 情況 B：丟 1 個到「有相同道具的格子」──
		# 直接讓後台方法將對應格子的數量 +1（會自動發出 inventory_update 訊號）
		inventory_data.add_slot_count(slot_button.slot_index, 1)

	# ── 處理手上剩下的道具 ──
	hand_data.count -= 1 # 手上扣 1 個
	
	if hand_data.count > 0:
		# 手上還有剩，讓滑鼠上的圖示更新數字顯示
		mouse_item.slot_item_update()
	else:
		# 手上扣到 0，銷毀滑鼠上的節點，回歸空手狀態
		mouse_item.queue_free()
		mouse_item = null


# ==========================================
# 消耗手上道具 (Consume Held Item)
# ==========================================

## consume_mouse_item：消耗滑鼠上正在持有的道具一個
## 若消耗後數量歸零，則銷毀圖示節點並關閉建造預覽
func consume_mouse_item() -> void:
	mouse_item.slot_data.count -= 1
	if mouse_item.slot_data.count <= 0:
		# 數量歸零，清除滑鼠跟隨物品並關閉建造預覽
		mouse_item.queue_free()
		mouse_item = null
		build_preview.deactivate()
	else:
		# 數量仍有剩，更新滑鼠圖示的數字顯示
		mouse_item.slot_item_update()


# ==========================================
# 生怪蛋使用邏輯 (Spawn Egg Use Logic)
# ==========================================

## use_item：嘗試使用一個 SpawnItemData 道具，在指定世界座標生成實體。
## 回傳 true 表示成功生成，回傳 false 表示失敗（場景或資料缺失）。
func use_item(item: ItemData, spawn_pos: Vector2) -> bool:
	# 1. 型別檢查：確認這是一個 SpawnItemData，否則忽略並警告
	if not item is SpawnItemData:
		push_warning("use_item: 傳入的道具不是 SpawnItemData，已忽略。")
		return false
	
	var spawn_data := item as SpawnItemData
	
	# 2. 防呆：確保 entity_scene 已設定，否則無法實例化
	if spawn_data.entity_scene == null:
		push_warning("use_item: SpawnItemData 的 entity_scene 為 null，無法生成實體。")
		return false
	
	# 3. 實例化場景
	var entity: Node = spawn_data.entity_scene.instantiate()
	
	# 4. 設定位置並加入場景樹
	#    必須先 add_child，@onready 變數才會在 _ready() 中被賦值，
	#    後續 setup() 才能安全存取 collision_shape 等子節點
	if entity is Node2D:
		(entity as Node2D).global_position = spawn_pos
	
	# 嘗試加入 NavigationRegion2D 下的 EnemyContainer，確保尋路正常
	var enemy_container = get_tree().current_scene.get_node_or_null("NavigationRegion2D/EnemyContainer")
	if enemy_container:
		enemy_container.add_child(entity)
	else:
		get_tree().current_scene.add_child(entity)
	
	# 5. 在節點進入場景樹後才注入 payload 資料（與 WaveManager 的做法一致）
	if spawn_data.payload_data != null and entity.has_method("setup"):
		entity.call("setup", spawn_data.payload_data)
	elif spawn_data.payload_data != null:
		push_warning("use_item: 實體缺少 setup() 函數，payload_data 未注入。")
	
	# 6. 設定導航目標（與 WaveManager 邏輯一致）
	if entity.has_method("set_target"):
		var base = get_tree().current_scene.get_node_or_null("BasePosition")
		if base:
			entity.set_target(base.global_position)
		else:
			push_warning("use_item: 找不到 Base 節點，敵人將沒有導航目標。")
	
	return true
