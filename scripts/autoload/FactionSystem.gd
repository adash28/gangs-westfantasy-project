## FactionSystem.gd
## 全局阵营与关系系统（单例）
## 管理游戏中所有阵营定义，以及实体间的关系判定
## v1.0.2 修复：移除枚举类型作为返回值标注（Godot 4.x autoload parse error 修复）

extends Node

# ─────────────────────────────────────────────
# 枚举定义（GDScript 4.x 全局枚举）
# ─────────────────────────────────────────────

## 阵营枚举
enum Faction {
	PLAYER  = 0,
	HUMAN   = 1,
	MONSTER = 2,
	ALLY    = 3,
	NEUTRAL = 4
}

## 关系枚举
enum Relation {
	LOYAL   = 0,
	ALLIED  = 1,
	HOSTILE = 2,
	NEUTRAL = 3
}

# ─────────────────────────────────────────────
# 默认阵营关系矩阵
# ─────────────────────────────────────────────
# 注意：在 _ready 中初始化，避免 autoload 启动时枚举尚未就绪的问题
var _default_matrix: Dictionary = {}

# 个体关系覆盖表
var _individual_overrides: Dictionary = {}


func _ready() -> void:
	# 在 _ready 中初始化矩阵，确保枚举已经就绪
	_default_matrix = {
		Faction.PLAYER: {
			Faction.PLAYER:  Relation.LOYAL,
			Faction.HUMAN:   Relation.ALLIED,
			Faction.MONSTER: Relation.HOSTILE,
			Faction.ALLY:    Relation.LOYAL,
			Faction.NEUTRAL: Relation.NEUTRAL
		},
		Faction.HUMAN: {
			Faction.PLAYER:  Relation.ALLIED,
			Faction.HUMAN:   Relation.ALLIED,
			Faction.MONSTER: Relation.HOSTILE,
			Faction.ALLY:    Relation.LOYAL,
			Faction.NEUTRAL: Relation.NEUTRAL
		},
		Faction.MONSTER: {
			Faction.PLAYER:  Relation.HOSTILE,
			Faction.HUMAN:   Relation.HOSTILE,
			Faction.MONSTER: Relation.ALLIED,
			Faction.ALLY:    Relation.HOSTILE,
			Faction.NEUTRAL: Relation.NEUTRAL
		},
		Faction.ALLY: {
			Faction.PLAYER:  Relation.LOYAL,
			Faction.HUMAN:   Relation.ALLIED,
			Faction.MONSTER: Relation.HOSTILE,
			Faction.ALLY:    Relation.LOYAL,
			Faction.NEUTRAL: Relation.NEUTRAL
		},
		Faction.NEUTRAL: {
			Faction.PLAYER:  Relation.NEUTRAL,
			Faction.HUMAN:   Relation.NEUTRAL,
			Faction.MONSTER: Relation.NEUTRAL,
			Faction.ALLY:    Relation.NEUTRAL,
			Faction.NEUTRAL: Relation.NEUTRAL
		}
	}


# ─────────────────────────────────────────────
# 核心查询方法
# 注意：返回类型使用 int 而非 Relation，避免 Godot 4.x 中 autoload parse error
# ─────────────────────────────────────────────

## 获取 entity_a 对 entity_b 的关系（返回 int，对应 Relation 枚举值）
func get_relation(entity_a: Node, entity_b: Node) -> int:
	var id_a = entity_a.get("unique_id")
	var id_b = entity_b.get("unique_id")
	
	# 先检查个体覆盖表
	if id_a and id_b:
		if _individual_overrides.has(id_a) and _individual_overrides[id_a].has(id_b):
			return _individual_overrides[id_a][id_b]
	
	# 使用默认阵营矩阵
	var faction_a: int = entity_a.get("faction", Faction.NEUTRAL)
	var faction_b: int = entity_b.get("faction", Faction.NEUTRAL)
	return get_faction_relation(faction_a, faction_b)


## 获取两个阵营之间的默认关系（返回 int）
func get_faction_relation(faction_a: int, faction_b: int) -> int:
	if _default_matrix.has(faction_a) and _default_matrix[faction_a].has(faction_b):
		return _default_matrix[faction_a][faction_b]
	return Relation.NEUTRAL


## 判断 entity_a 是否对 entity_b 持敌对关系
func is_hostile(entity_a: Node, entity_b: Node) -> bool:
	return get_relation(entity_a, entity_b) == Relation.HOSTILE


## 判断 entity_a 是否对 entity_b 持同盟/忠诚关系
func is_friendly(entity_a: Node, entity_b: Node) -> bool:
	var rel = get_relation(entity_a, entity_b)
	return rel == Relation.ALLIED or rel == Relation.LOYAL


## 判断是否为中立关系
func is_neutral(entity_a: Node, entity_b: Node) -> bool:
	return get_relation(entity_a, entity_b) == Relation.NEUTRAL


# ─────────────────────────────────────────────
# 关系修改方法
# ─────────────────────────────────────────────

## 设置个体关系覆盖（双向，除非 one_way=true）
func set_individual_relation(entity_a: Node, entity_b: Node, relation: int, one_way: bool = false) -> void:
	var id_a = entity_a.get("unique_id")
	var id_b = entity_b.get("unique_id")
	if not id_a or not id_b:
		push_warning("[FactionSystem] 实体缺少 unique_id，无法设置个体关系")
		return
	
	if not _individual_overrides.has(id_a):
		_individual_overrides[id_a] = {}
	_individual_overrides[id_a][id_b] = relation
	
	if not one_way:
		if not _individual_overrides.has(id_b):
			_individual_overrides[id_b] = {}
		_individual_overrides[id_b][id_a] = _mirror_relation(relation)
	
	EventBus.relation_changed.emit(entity_a, relation)


## 清除某实体的所有个体覆盖关系（实体死亡后调用）
func clear_individual_relations(entity: Node) -> void:
	var uid = entity.get("unique_id")
	if uid and _individual_overrides.has(uid):
		_individual_overrides.erase(uid)


## 获取阵营名称字符串（用于调试和UI显示）
func get_faction_name(faction: int) -> String:
	match faction:
		Faction.PLAYER:  return "玩家"
		Faction.HUMAN:   return "人类"
		Faction.MONSTER: return "魔物"
		Faction.ALLY:    return "同盟"
		Faction.NEUTRAL: return "中立"
	return "未知"


## 获取关系名称字符串
func get_relation_name(relation: int) -> String:
	match relation:
		Relation.LOYAL:   return "忠诚"
		Relation.ALLIED:  return "同盟"
		Relation.HOSTILE: return "仇恨"
		Relation.NEUTRAL: return "中立"
	return "未知"


# ─────────────────────────────────────────────
# 内部工具
# ─────────────────────────────────────────────

## 关系的镜像
func _mirror_relation(relation: int) -> int:
	match relation:
		Relation.LOYAL:   return Relation.ALLIED
		Relation.ALLIED:  return Relation.ALLIED
		Relation.HOSTILE: return Relation.HOSTILE
		Relation.NEUTRAL: return Relation.NEUTRAL
	return Relation.NEUTRAL
