## FactionSystem.gd
## 全局阵营与关系系统（单例）
## 管理游戏中所有阵营定义，以及实体间的关系判定
## 
## 阵营枚举:
##   HUMAN   - 人类（村民/商人/神父等）
##   MONSTER - 魔物（哥布林/不死者等）
##   PLAYER  - 玩家（动态，取决于选择角色）
##   ALLY    - 同盟（被雇佣后变为此状态）
##   NEUTRAL - 中立（不主动攻击）
##
## 关系枚举:
##   LOYAL   - 忠诚：主动保护，受攻击立即转为仇恨
##   ALLIED  - 同盟：受攻击时转为仇恨
##   HOSTILE - 仇恨：主动攻击
##   NEUTRAL - 中立：不主动攻击

extends Node

# ─────────────────────────────────────────────
# 枚举定义（GDScript 4.x 全局枚举）
# ─────────────────────────────────────────────

## 阵营枚举
enum Faction {
	PLAYER  = 0,
	HUMAN   = 1,
	MONSTER = 2,
	ALLY    = 3,  # 被雇佣/加入玩家队伍后的特殊状态
	NEUTRAL = 4
}

## 关系枚举（对应文档中的"角色与角色之间的关系"）
enum Relation {
	LOYAL   = 0,  # 忠诚：跟随玩家，被攻击立刻反击并仇恨
	ALLIED  = 1,  # 同盟：玩家受攻击时一起反击
	HOSTILE = 2,  # 仇恨：AI 转为 Attack 状态
	NEUTRAL = 3   # 中立：不主动攻击，受攻击才反击
}

# ─────────────────────────────────────────────
# 默认阵营关系矩阵
# faction_matrix[faction_a][faction_b] = Relation
# 表示 faction_a 眼中对 faction_b 的默认关系
# ─────────────────────────────────────────────
var _default_matrix: Dictionary = {
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

# 个体关系覆盖表：允许对特定实体设置不同于默认阵营关系的个体关系
# 格式: { entity_a_id: { entity_b_id: Relation } }
var _individual_overrides: Dictionary = {}


# ─────────────────────────────────────────────
# 核心查询方法
# ─────────────────────────────────────────────

## 获取 entity_a 对 entity_b 的关系
## entity_a, entity_b 需要有 faction 属性和 unique_id 属性
func get_relation(entity_a: Node, entity_b: Node) -> Relation:
	var id_a = entity_a.get("unique_id")
	var id_b = entity_b.get("unique_id")
	
	# 先检查个体覆盖表
	if id_a and id_b:
		if _individual_overrides.has(id_a) and _individual_overrides[id_a].has(id_b):
			return _individual_overrides[id_a][id_b]
	
	# 使用默认阵营矩阵（修复处）
	var faction_a: int = entity_a.get("faction")
	if faction_a == null:
		faction_a = Faction.NEUTRAL
	
	var faction_b: int = entity_b.get("faction")
	if faction_b == null:
		faction_b = Faction.NEUTRAL
	
	return get_faction_relation(faction_a, faction_b)


## 获取两个阵营之间的默认关系
func get_faction_relation(faction_a: int, faction_b: int) -> Relation:
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
func set_individual_relation(entity_a: Node, entity_b: Node, relation: Relation, one_way: bool = false) -> void:
	var id_a = entity_a.get("unique_id")
	var id_b = entity_b.get("unique_id")
	if not id_a or not id_b:
		push_warning("[FactionSystem] 实体缺少 unique_id，无法设置个体关系")
		return
	
	if not _individual_overrides.has(id_a):
		_individual_overrides[id_a] = {}
	_individual_overrides[id_a][id_b] = relation
	
	if not one_way:
		# 同时设置对方关系（如果不是单向的）
		# 例如：A 变成 B 的同盟，B 也相应变成 A 的同盟
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

## 关系的镜像（A对B的关系确定后B对A的合理对应关系）
func _mirror_relation(relation: Relation) -> Relation:
	match relation:
		Relation.LOYAL:   return Relation.ALLIED   # 对方至少也是同盟
		Relation.ALLIED:  return Relation.ALLIED
		Relation.HOSTILE: return Relation.HOSTILE  # 仇恨是双向的
		Relation.NEUTRAL: return Relation.NEUTRAL
	return Relation.NEUTRAL
