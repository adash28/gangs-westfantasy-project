## DataManager.gd
## 全局数据管理器（单例）
## 在游戏启动时加载所有 JSON 配置到内存中
## 提供统一的数据查询接口，避免重复读取文件

extends Node

# ─────────────────────────────────────────────
# 内存中的配置数据
# ─────────────────────────────────────────────
var characters: Dictionary = {}
var skills: Dictionary = {}
var weapons: Dictionary = {}
var shop_items: Dictionary = {}

# 数据文件路径
const CHARACTER_DATA_PATH := "res://data/characters/characters.json"
const ITEM_DATA_PATH := "res://data/items/items.json"

# ─────────────────────────────────────────────
# 初始化
# ─────────────────────────────────────────────
func _ready() -> void:
	_load_all_data()


func _load_all_data() -> void:
	print("[DataManager] 开始加载配置数据...")
	_load_character_data()
	_load_item_data()
	print("[DataManager] 所有配置数据加载完成。")
	print("  已加载角色: ", characters.keys())
	print("  已加载技能: ", skills.keys())
	print("  已加载武器: ", weapons.keys())


func _load_character_data() -> void:
	var data = _read_json(CHARACTER_DATA_PATH)
	if data.is_empty():
		push_error("[DataManager] 角色配置文件加载失败！")
		return
	characters = data.get("characters", {})
	skills = data.get("skills", {})
	print("[DataManager] 角色配置加载成功，共 %d 个角色，%d 个技能" % [characters.size(), skills.size()])


func _load_item_data() -> void:
	var data = _read_json(ITEM_DATA_PATH)
	if data.is_empty():
		push_error("[DataManager] 物品配置文件加载失败！")
		return
	weapons = data.get("weapons", {})
	shop_items = data.get("shop_items", {})
	print("[DataManager] 物品配置加载成功，共 %d 个武器，%d 个商店物品" % [weapons.size(), shop_items.size()])


# ─────────────────────────────────────────────
# 核心查询接口
# ─────────────────────────────────────────────

## 获取角色配置，返回 Dictionary，找不到时返回 {}
func get_character(char_id: String) -> Dictionary:
	if characters.has(char_id):
		return characters[char_id].duplicate(true)  # 深拷贝，防止外部修改原数据
	push_warning("[DataManager] 找不到角色: " + char_id)
	return {}


## 获取武器配置
func get_weapon(weapon_id: String) -> Dictionary:
	if weapons.has(weapon_id):
		return weapons[weapon_id].duplicate(true)
	# 找不到武器时默认返回拳头
	push_warning("[DataManager] 找不到武器: " + weapon_id + "，将使用拳头")
	return weapons.get("fist", {}).duplicate(true)


## 获取技能配置
func get_skill(skill_id: String) -> Dictionary:
	if skills.has(skill_id):
		return skills[skill_id].duplicate(true)
	push_warning("[DataManager] 找不到技能: " + skill_id)
	return {}


## 获取商店物品配置
func get_shop_item(item_id: String) -> Dictionary:
	if shop_items.has(item_id):
		return shop_items[item_id].duplicate(true)
	push_warning("[DataManager] 找不到商品: " + item_id)
	return {}


## 获取所有可选玩家角色的ID列表
func get_playable_character_ids() -> Array:
	var result: Array = []
	for char_id in characters:
		if characters[char_id].get("is_player_class", false):
			result.append(char_id)
	return result


## 计算NPC的实际血量（NPC血量 = 玩家血量 × 1/3）
func get_npc_hp(char_id: String) -> float:
	var char_data = get_character(char_id)
	if char_data.is_empty():
		return 30.0
	var ratio = char_data.get("npc_hp_ratio", 0.333)
	return char_data.get("hp", 100) * ratio


# ─────────────────────────────────────────────
# 内部工具方法
# ─────────────────────────────────────────────

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("[DataManager] 文件不存在: " + path)
		return {}
	
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[DataManager] 无法打开文件: " + path)
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("[DataManager] JSON解析错误 %s: %s" % [path, json.get_error_message()])
		return {}
	
	return json.data
