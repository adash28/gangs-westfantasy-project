## InventorySystem.gd
## 背包系统：管理物品存储、拾取、使用逻辑
## 最多25格（5x5），通过 EventBus 通知UI

extends Node
class_name InventorySystem

const MAX_SLOTS = 25  # 5x5 背包

## 背包格子：每格存一个物品字典，null表示空
var slots: Array = []

## 快捷武器列表（按顺序切换）
var weapon_list: Array = []
var current_weapon_index: int = 0


func _init() -> void:
	slots.resize(MAX_SLOTS)
	for i in range(MAX_SLOTS):
		slots[i] = null


## 添加物品到背包，返回是否成功
func add_item(item_data: Dictionary) -> bool:
	# 找第一个空格
	for i in range(MAX_SLOTS):
		if slots[i] == null:
			slots[i] = item_data.duplicate(true)
			print("[Inventory] 添加物品: %s 到格子 %d" % [item_data.get("display_name", "?"), i])
			# 如果是武器，加入武器列表
			if item_data.get("type", "") == "weapon" or item_data.get("weapon_type", "") != "":
				_add_to_weapon_list(item_data)
			return true
	print("[Inventory] 背包已满，无法添加")
	return false


## 移除指定格子的物品
func remove_item(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return {}
	var item = slots[slot_index]
	if item == null:
		return {}
	slots[slot_index] = null
	return item


## 获取指定格子的物品
func get_item(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return {}
	return slots[slot_index] if slots[slot_index] != null else {}


## 是否有指定物品
func has_item(item_id: String) -> bool:
	for slot in slots:
		if slot != null and slot.get("id", "") == item_id:
			return true
	return false


## 消耗一个指定ID的物品（使用后移除）
func consume_item(item_id: String) -> bool:
	for i in range(MAX_SLOTS):
		if slots[i] != null and slots[i].get("id", "") == item_id:
			slots[i] = null
			print("[Inventory] 消耗物品: %s" % item_id)
			return true
	return false


## 清空背包
func clear() -> void:
	for i in range(MAX_SLOTS):
		slots[i] = null
	weapon_list.clear()
	current_weapon_index = 0


## 武器列表管理
func _add_to_weapon_list(weapon_data: Dictionary) -> void:
	# 避免重复
	for w in weapon_list:
		if w.get("id", "") == weapon_data.get("id", ""):
			return
	weapon_list.append(weapon_data)


func switch_weapon_next() -> Dictionary:
	if weapon_list.size() == 0:
		return {}
	current_weapon_index = (current_weapon_index + 1) % weapon_list.size()
	return weapon_list[current_weapon_index]


func switch_weapon_prev() -> Dictionary:
	if weapon_list.size() == 0:
		return {}
	current_weapon_index = (current_weapon_index - 1 + weapon_list.size()) % weapon_list.size()
	return weapon_list[current_weapon_index]


func get_current_weapon() -> Dictionary:
	if weapon_list.size() == 0:
		return {}
	return weapon_list[current_weapon_index]


## 统计某类物品数量
func count_item(item_id: String) -> int:
	var count = 0
	for slot in slots:
		if slot != null and slot.get("id", "") == item_id:
			count += 1
	return count
