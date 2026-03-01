extends Button

signal mouse_button_left_press
signal mouse_button_right_press

@onready var slot_background: ColorRect = %SlotBackground
@onready var center_container: CenterContainer = %CenterContainer

var slot_inventory: Inventory
var slot_index: int
var contained_item_icon: SlotItem

func _ready() -> void:
	# 【注意】原代碼設定了 button_mask，這裡保持不變
	button_mask = MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT
	reset_color()

func reset_color():
	slot_background.color = Color(0.5, 0.5, 0.5, 0.8)

func insert(new_item_icon: SlotItem):
	contained_item_icon = new_item_icon
	slot_background.color = Color(0.7, 0.7, 0.7, 0.8)
	center_container.add_child(contained_item_icon)
	
	# 【修復】：加入防呆判斷，確保資料庫參考與圖示皆存在才執行更新
	if !contained_item_icon or !slot_inventory:
		return
	
	slot_inventory.insert_slot(slot_index, contained_item_icon.slot_data)

func clear_box():
	if contained_item_icon:
		contained_item_icon.queue_free()
		contained_item_icon = null
	reset_color()

func _on_gui_input(event: InputEvent) -> void:
	# 【修復】：將 MOUSE_BUTTON_MASK_LEFT 改為 MOUSE_BUTTON_LEFT
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			mouse_button_left_press.emit()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			mouse_button_right_press.emit()

func take_item():
	var take_item_ = contained_item_icon
	
	# 【修復】：順序調換，先通知資料庫移除物品資料，再拔除 UI 節點
	if contained_item_icon and contained_item_icon.slot_data and slot_inventory:
		slot_inventory.remove_slot(contained_item_icon.slot_data)
	
	center_container.remove_child(contained_item_icon)
	contained_item_icon = null
	reset_color()
	
	return take_item_

func is_empty():
	return !contained_item_icon
