## BaseCharacter.gd
## 所有游戏实体（玩家、NPC、怪物）的基础类
## 继承自 CharacterBody2D 以获得内置碰撞和移动支持
##
## 对应文档中 BaseCharacter 的完整属性：
##   坐标（东南西北四方向）、阵营、血量、魔力、伤害、移动速度
##   武器组件、技能组件、状态机

extends CharacterBody2D
class_name BaseCharacter

# ─────────────────────────────────────────────
# 身份标识
# ─────────────────────────────────────────────

## 全局唯一ID（由外部赋值，用于个体关系表）
var unique_id: String = ""

## 对应 DataManager 中的 char_id
var character_id: String = ""

## 显示名称
var display_name: String = "未知"


# ─────────────────────────────────────────────
# 阵营（对应文档中的 enum Faction）
# ─────────────────────────────────────────────
var faction: int = FactionSystem.Faction.NEUTRAL


# ─────────────────────────────────────────────
# 核心属性（从 DataManager 加载后赋值）
# ─────────────────────────────────────────────

var max_hp: float = 100.0
var current_hp: float = 100.0

var max_mp: float = 0.0
var current_mp: float = 0.0

var base_damage: float = 3.0
var magic_damage: float = 0.0

## 移动速度（格/秒），单格 = TILE_SIZE = 32px
var move_speed: float = 3.0

## 当前面朝方向（东南西北对应右下左上）
enum Direction { RIGHT, DOWN, LEFT, UP }
var facing_direction: int = Direction.DOWN

# 是否存活
var is_alive: bool = true


# ─────────────────────────────────────────────
# 武器组件（字典形式，从 DataManager 加载）
# ─────────────────────────────────────────────

## 当前装备的武器数据
var weapon_data: Dictionary = {}

## 当前武器剩余耐久度（-1 表示无限耐久）
var weapon_durability: float = -1.0


# ─────────────────────────────────────────────
# 技能列表（从 DataManager 加载）
# ─────────────────────────────────────────────
var skills: Array = []


# ─────────────────────────────────────────────
# 节点引用（由具体子类设置）
# ─────────────────────────────────────────────
@onready var state_machine_node: StateMachine = $StateMachine if has_node("StateMachine") else null
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var collision: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null
@onready var detection_area: Area2D = $DetectionArea if has_node("DetectionArea") else null
@onready var attack_area: Area2D = $AttackArea if has_node("AttackArea") else null

# 常量
const TILE_SIZE := 32  # 单格像素尺寸
const MP_REGEN_INTERVAL := 1.0  # 咏唱技能恢复间隔（秒）

# 内部计时器
var _mp_regen_timer: float = 0.0


# ─────────────────────────────────────────────
# 初始化
# ─────────────────────────────────────────────

func _ready() -> void:
	# 子类应先调用 setup_from_data() 再 call super._ready()
	pass


## 根据角色ID从DataManager加载配置数据进行初始化
## is_npc: 若为true则使用NPC血量（1/3）
func setup_from_data(char_id: String, is_npc: bool = false) -> void:
	character_id = char_id
	var data = DataManager.get_character(char_id)
	if data.is_empty():
		push_error("[BaseCharacter] 无法加载角色数据: " + char_id)
		return
	
	display_name = data.get("display_name", "未知")
	
	# 阵营映射（JSON字符串 → 枚举整数）
	var faction_str = data.get("faction", "NEUTRAL")
	faction = _parse_faction(faction_str)
	
	# 血量（NPC血量为原来的1/3）
	var base_hp = float(data.get("hp", 100))
	if is_npc:
		max_hp = base_hp * data.get("npc_hp_ratio", 0.333)
	else:
		max_hp = base_hp
	current_hp = max_hp
	
	# 魔力
	max_mp = float(data.get("mp", 0))
	current_mp = max_mp
	
	# 战斗属性
	base_damage = float(data.get("damage", 3))
	magic_damage = float(data.get("magic_damage", 0))
	move_speed = float(data.get("move_speed", 3))
	
	# 武器
	var weapon_id = data.get("starting_weapon", "fist")
	_equip_weapon(weapon_id)
	
	# 技能
	skills = data.get("skills", [])
	
	# 生成唯一ID
	if unique_id.is_empty():
		unique_id = char_id + "_" + str(randi())
	
	print("[BaseCharacter] %s 初始化完成: HP=%.0f, MP=%.0f, 武器=%s" % [
		display_name, max_hp, max_mp, weapon_data.get("display_name", "无")
	])


# ─────────────────────────────────────────────
# 每帧更新
# ─────────────────────────────────────────────

func _process(delta: float) -> void:
	if not is_alive:
		return
	_process_passive_skills(delta)


## 处理被动技能（如咏唱 - MP自动恢复）
func _process_passive_skills(delta: float) -> void:
	if not skills.has("chant"):
		return
	
	# 咏唱技能：MP <= 10 时每秒恢复1点直到30
	if current_mp <= 10.0 and current_mp < 30.0:
		_mp_regen_timer += delta
		if _mp_regen_timer >= MP_REGEN_INTERVAL:
			_mp_regen_timer = 0.0
			var regen = min(1.0, 30.0 - current_mp)
			change_mp(regen)


# ─────────────────────────────────────────────
# 战斗核心方法
# ─────────────────────────────────────────────

## 计算并造成伤害给目标
func attack(target: BaseCharacter) -> void:
	if not is_alive or not target.is_alive:
		return
	
	var damage = _calculate_damage(target)
	
	# 扣除武器耐久度
	_consume_weapon_durability()
	
	# 对目标造成伤害
	target.take_damage(damage, self)
	
	# 发布攻击事件（供同盟NPC监听）
	EventBus.entity_attacked.emit(self, target, damage)


## 计算对目标的伤害（含武器特殊加成）
func _calculate_damage(target: BaseCharacter) -> float:
	var total_damage = base_damage
	
	if weapon_data.is_empty():
		return total_damage
	
	# 武器有效时加算额外攻击力
	if weapon_durability == -1.0 or weapon_durability > 0:
		var extra = float(weapon_data.get("extra_damage", 0))
		total_damage += extra
		
		# 圣杖/匕首对不死者的特殊加成
		var special_target = weapon_data.get("special_target", null)
		if special_target != null and target.character_id == "undead":
			var multiplier = float(weapon_data.get("special_multiplier", 1.0))
			total_damage *= multiplier
	
	return total_damage


## 接受伤害
func take_damage(amount: float, attacker: BaseCharacter = null) -> void:
	if not is_alive:
		return
	
	current_hp = max(0.0, current_hp - amount)
	EventBus.hp_changed.emit(self, current_hp, max_hp)
	
	# 阵营关系触发：被攻击时更新关系
	if attacker:
		_react_to_being_attacked(attacker)
	
	if current_hp <= 0.0:
		die(attacker)


## 治疗（恢复血量）
func heal(amount: float) -> void:
	current_hp = min(max_hp, current_hp + amount)
	EventBus.hp_changed.emit(self, current_hp, max_hp)


## 改变魔力值
func change_mp(amount: float) -> void:
	current_mp = clamp(current_mp + amount, 0.0, max_mp)
	EventBus.mp_changed.emit(self, current_mp, max_mp)


## 死亡处理
func die(killer: BaseCharacter = null) -> void:
	is_alive = false
	
	# 通知状态机进入 Dead 状态
	if state_machine_node:
		state_machine_node.transition_to("DeadState")
	
	# 发布死亡事件（用于掉落物品、更新任务等）
	EventBus.entity_died.emit(self, killer)
	
	# 清除个体关系记录
	FactionSystem.clear_individual_relations(self)
	
	print("[BaseCharacter] %s 死亡！击杀者: %s" % [
		display_name, 
		killer.display_name if killer else "未知"
	])


# ─────────────────────────────────────────────
# 移动
# ─────────────────────────────────────────────

## 获取像素移动速度（格/秒 × 像素/格）
func get_pixel_speed() -> float:
	return move_speed * TILE_SIZE


## 更新面朝方向
func update_facing(direction: Vector2) -> void:
	if direction.x > 0.1:
		facing_direction = Direction.RIGHT
	elif direction.x < -0.1:
		facing_direction = Direction.LEFT
	elif direction.y > 0.1:
		facing_direction = Direction.DOWN
	elif direction.y < -0.1:
		facing_direction = Direction.UP


# ─────────────────────────────────────────────
# 武器管理
# ─────────────────────────────────────────────

func _equip_weapon(weapon_id: String) -> void:
	weapon_data = DataManager.get_weapon(weapon_id)
	if weapon_data.is_empty():
		weapon_durability = -1.0
		return
	
	var dur = weapon_data.get("durability", -1)
	weapon_durability = float(dur)
	EventBus.weapon_durability_changed.emit(self, weapon_durability, weapon_data.get("durability", -1))


func _consume_weapon_durability() -> void:
	if weapon_durability == -1.0:
		return  # 无限耐久
	
	var cost = float(weapon_data.get("durability_per_hit", 0))
	weapon_durability = max(0.0, weapon_durability - cost)
	
	var max_dur = float(weapon_data.get("durability", 100))
	EventBus.weapon_durability_changed.emit(self, weapon_durability, max_dur)
	
	if weapon_durability <= 0.0:
		_break_weapon()


func _break_weapon() -> void:
	print("[BaseCharacter] %s 的武器 %s 损坏了！" % [display_name, weapon_data.get("display_name", "武器")])
	EventBus.weapon_broken.emit(self, weapon_data.get("id", ""))
	weapon_data = DataManager.get_weapon("fist")  # 切换为拳头


# ─────────────────────────────────────────────
# 阵营关系响应
# ─────────────────────────────────────────────

## 被攻击时根据阵营关系触发响应
func _react_to_being_attacked(attacker: BaseCharacter) -> void:
	# 不需要在 BaseCharacter 层处理，留给 NPC 子类覆盖
	pass


# ─────────────────────────────────────────────
# 工具方法
# ─────────────────────────────────────────────

func _parse_faction(faction_str: String) -> int:
	match faction_str.to_upper():
		"PLAYER":  return FactionSystem.Faction.PLAYER
		"HUMAN":   return FactionSystem.Faction.HUMAN
		"MONSTER": return FactionSystem.Faction.MONSTER
		"ALLY":    return FactionSystem.Faction.ALLY
		"NEUTRAL": return FactionSystem.Faction.NEUTRAL
	return FactionSystem.Faction.NEUTRAL


## 判断当前血量百分比
func get_hp_percent() -> float:
	if max_hp <= 0:
		return 0.0
	return current_hp / max_hp


## 是否血量低
func is_low_hp(threshold: float = 0.3) -> bool:
	return get_hp_percent() < threshold
