extends Control

# --- 節點引用 (Node References) ---
@onready var bag_slot_container: GridContainer = %BagSlotContainer
@onready var hot_bar_container: HBoxContainer = %HotBarContainer

# --- 資料與設定 (Data & Settings) ---
@onready var all_ui_slots: Array = hot_bar_container.get_children() + bag_slot_container.get_children()

var inventory_data: Inventory = preload("res://player/player_inventory.tres")

@onready var item_icon_scene: PackedScene = preload("res://ui/slot_item.tscn")

var mouse_item: SlotItem = null

# --- 核心生命週期 (Lifecycle) ---
func _ready() -> void:
	connect_slot_signals()
	close_bag()
	
	for i in range(all_ui_slots.size()):
		var slot = all_ui_slots[i]
		slot.slot_index = i

func _process(_delta: float) -> void:
	if mouse_item:
		mouse_item.global_position = get_global_mouse_position()

# --- 介面更新邏輯 (UI Logic) ---
func connect_slot_signals() -> void:
	for slot_button in all_ui_slots:
		if not slot_button.mouse_button_left_press.is_connected(mouse_left_slot_button):
			slot_button.mouse_button_left_press.connect(mouse_left_slot_button.bind(slot_button))

func bag_update() -> void:
	if inventory_data.slots.size() != all_ui_slots.size():
		printerr("錯誤：背包資料長度與 UI 格子數量不符！")
		return
		
	for i in range(all_ui_slots.size()):
		var current_slot_data: Slot = inventory_data.slots[i]
		var current_ui_box = all_ui_slots[i]
	
		if not current_slot_data or not current_slot_data.item:
			current_ui_box.clear_box() 
			continue 
		
		var item_icon: SlotItem = current_ui_box.contained_item_icon
		
		if not item_icon:
			item_icon = item_icon_scene.instantiate()
			current_ui_box.insert(item_icon)
		
		item_icon.slot_data = current_slot_data
		item_icon.slot_item_update()

# --- 背包狀態管理 (State Management) ---
func set_player_inventory(player_inventory: Inventory) -> void:
	if inventory_data and inventory_data.inventory_update.is_connected(bag_update):
		inventory_data.inventory_update.disconnect(bag_update)
	
	inventory_data = player_inventory
	
	if inventory_data:
		# 【修復】：確保在呼叫 bag_update 嘗試插入 UI 前，所有格子都已獲得背包資料庫的參考
		for slot_button in all_ui_slots:
			slot_button.slot_inventory = inventory_data
			
		inventory_data.inventory_update.connect(bag_update)
		bag_update()

func open_bag(player_inventory: Inventory) -> void:
	set_player_inventory(player_inventory)
	# 【修復】：移除了原本多餘的信號斷開與重複的 for 迴圈
	show()

func close_bag() -> void:
	hide()

# --- 滑鼠互動邏輯 (Mouse Interaction) ---
func mouse_left_slot_button(slot_button) -> void:
	if slot_button.is_empty() and mouse_item:
		insert_item_in_slot(slot_button)
	elif not slot_button.is_empty() and not mouse_item:
		take_item_from_slot(slot_button)
		
func take_item_from_slot(slot_button) -> void:
	mouse_item = slot_button.take_item()
	
	if mouse_item:
		add_child(mouse_item)
		mouse_item.global_position = get_global_mouse_position()

func insert_item_in_slot(slot_button):
	var item = mouse_item
	remove_child(mouse_item)
	mouse_item = null
	slot_button.insert(item)
