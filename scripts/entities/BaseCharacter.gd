## BaseCharacter.gd
## 所有游戏实体（玩家、NPC、怪物）的基础类 v1.0.2
## 新增：击退、僵直、尸体爆裂、武器显示、挥击弧线、射弹

extends CharacterBody2D
class_name BaseCharacter

# ─────────────────────────────────────────────
# 身份标识
# ─────────────────────────────────────────────
var unique_id: String = ""
var character_id: String = ""
var display_name: String = "未知"

# ─────────────────────────────────────────────
# 阵营
# ─────────────────────────────────────────────
var faction: int = FactionSystem.Faction.NEUTRAL

# ─────────────────────────────────────────────
# 核心属性
# ─────────────────────────────────────────────
var max_hp: float = 100.0
var current_hp: float = 100.0
var max_mp: float = 0.0
var current_mp: float = 0.0
var base_damage: float = 3.0
var magic_damage: float = 0.0
var move_speed: float = 3.0

enum Direction { RIGHT, DOWN, LEFT, UP }
var facing_direction: int = Direction.DOWN
var is_alive: bool = true

# ─────────────────────────────────────────────
# 武器组件
# ─────────────────────────────────────────────
var weapon_data: Dictionary = {}
var weapon_durability: float = -1.0

# ─────────────────────────────────────────────
# 背包系统 (v1.0.2)
# ─────────────────────────────────────────────
const INVENTORY_SIZE := 25  # 5x5 grid
var inventory: Array = []  # Array of item dictionaries
var health_potions: int = 0
var mana_potions: int = 0

# ─────────────────────────────────────────────
# 技能
# ─────────────────────────────────────────────
var skills: Array = []

# ─────────────────────────────────────────────
# 打击感参数 (v1.0.2)
# ─────────────────────────────────────────────
const KNOCKBACK_FORCE := 400.0
const KNOCKBACK_DECAY := 0.85
const DEATH_KNOCKBACK_MULTIPLIER := 1.5
var _knockback_velocity: Vector2 = Vector2.ZERO
var _is_in_hit_stun: bool = false
var _corpse_hit_count: int = 0
var _death_knockback: Vector2 = Vector2.ZERO

# ─────────────────────────────────────────────
# 武器显示节点 (v1.0.2)
# ─────────────────────────────────────────────
var _weapon_sprite: Sprite2D = null
var _swing_arc_node: Node2D = null

# ─────────────────────────────────────────────
# 节点引用
# ─────────────────────────────────────────────
@onready var state_machine_node: StateMachine = $StateMachine if has_node("StateMachine") else null
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var collision: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null
@onready var detection_area: Area2D = $DetectionArea if has_node("DetectionArea") else null
@onready var attack_area: Area2D = $AttackArea if has_node("AttackArea") else null

# 常量
const TILE_SIZE := 32
const MP_REGEN_INTERVAL := 1.0

var _mp_regen_timer: float = 0.0


# ─────────────────────────────────────────────
# 初始化
# ─────────────────────────────────────────────

func _ready() -> void:
	_setup_weapon_sprite()
	_setup_swing_arc()


func setup_from_data(char_id: String, is_npc: bool = false) -> void:
	character_id = char_id
	var data = DataManager.get_character(char_id)
	if data.is_empty():
		push_error("[BaseCharacter] 无法加载角色数据: " + char_id)
		return
	
	display_name = data.get("display_name", "未知")
	
	var faction_str = data.get("faction", "NEUTRAL")
	faction = _parse_faction(faction_str)
	
	var base_hp = float(data.get("hp", 100))
	if is_npc:
		max_hp = base_hp * data.get("npc_hp_ratio", 0.5)
	else:
		max_hp = base_hp
	current_hp = max_hp
	
	max_mp = float(data.get("mp", 0))
	current_mp = max_mp
	
	base_damage = float(data.get("damage", 3))
	magic_damage = float(data.get("magic_damage", 0))
	move_speed = float(data.get("move_speed", 3))
	
	var weapon_id = data.get("starting_weapon", "fist")
	_equip_weapon(weapon_id)
	
	skills = data.get("skills", [])
	
	if unique_id.is_empty():
		unique_id = char_id + "_" + str(randi())
	
	_update_weapon_sprite()
	
	print("[BaseCharacter] %s 初始化完成: HP=%.0f, MP=%.0f, 武器=%s" % [
		display_name, max_hp, max_mp, weapon_data.get("display_name", "无")
	])


# ─────────────────────────────────────────────
# 武器显示 (v1.0.2)
# ─────────────────────────────────────────────

func _setup_weapon_sprite() -> void:
	_weapon_sprite = Sprite2D.new()
	_weapon_sprite.name = "WeaponSprite"
	_weapon_sprite.z_index = 1
	add_child(_weapon_sprite)
	_weapon_sprite.position = Vector2(12, 0)


func _setup_swing_arc() -> void:
	_swing_arc_node = Node2D.new()
	_swing_arc_node.name = "SwingArc"
	_swing_arc_node.z_index = 2
	add_child(_swing_arc_node)


func _update_weapon_sprite() -> void:
	if _weapon_sprite == null:
		return
	
	var weapon_id = weapon_data.get("id", "fist")
	if weapon_id == "fist":
		_weapon_sprite.visible = false
		return
	
	_weapon_sprite.visible = true
	# 生成简单的武器像素图标
	var img = Image.create(8, 16, false, Image.FORMAT_RGBA8)
	var wcolor: Color
	match weapon_id:
		"axe": wcolor = Color(0.6, 0.4, 0.2)
		"cleaver": wcolor = Color(0.7, 0.7, 0.7)
		"holy_staff": wcolor = Color(1.0, 0.9, 0.3)
		"dagger": wcolor = Color(0.8, 0.8, 0.9)
		"sword": wcolor = Color(0.75, 0.75, 0.8)
		_: wcolor = Color(0.5, 0.5, 0.5)
	
	# 画武器形状
	for y in range(16):
		for x in range(8):
			if y < 4:  # 刀刃/杖头
				if x >= 2 and x <= 5:
					img.set_pixel(x, y, wcolor.lightened(0.3))
			elif y < 12:  # 刀身
				if x >= 3 and x <= 4:
					img.set_pixel(x, y, wcolor)
			else:  # 手柄
				if x >= 3 and x <= 4:
					img.set_pixel(x, y, Color(0.4, 0.25, 0.1))
	
	_weapon_sprite.texture = ImageTexture.create_from_image(img)


func _update_weapon_position() -> void:
	if _weapon_sprite == null:
		return
	match facing_direction:
		Direction.RIGHT:
			_weapon_sprite.position = Vector2(12, 0)
			_weapon_sprite.rotation_degrees = -30
			_weapon_sprite.flip_h = false
		Direction.LEFT:
			_weapon_sprite.position = Vector2(-12, 0)
			_weapon_sprite.rotation_degrees = 30
			_weapon_sprite.flip_h = true
		Direction.DOWN:
			_weapon_sprite.position = Vector2(8, 8)
			_weapon_sprite.rotation_degrees = -45
		Direction.UP:
			_weapon_sprite.position = Vector2(-8, -8)
			_weapon_sprite.rotation_degrees = 135


# ─────────────────────────────────────────────
# 每帧更新
# ─────────────────────────────────────────────

func _process(delta: float) -> void:
	if not is_alive:
		return
	_process_passive_skills(delta)
	_update_weapon_position()


func _process_passive_skills(delta: float) -> void:
	if not skills.has("chant"):
		return
	if current_mp <= 10.0 and current_mp < 30.0:
		_mp_regen_timer += delta
		if _mp_regen_timer >= MP_REGEN_INTERVAL:
			_mp_regen_timer = 0.0
			var regen = min(1.0, 30.0 - current_mp)
			change_mp(regen)


# ─────────────────────────────────────────────
# 战斗核心方法
# ─────────────────────────────────────────────

func attack(target: BaseCharacter) -> void:
	if not is_alive or not target.is_alive:
		return
	
	var damage = _calculate_damage(target)
	
	# 判断是远程还是近战
	var wtype = weapon_data.get("weapon_type", "melee")
	if wtype == "ranged":
		# 远程武器：发射射弹，伤害由射弹处理，不直接调用 take_damage
		_fire_projectile(target)
		_consume_weapon_durability()
		# 远程攻击也发出事件（damage 仅用于日志，实际由射弹处理）
		EventBus.entity_attacked.emit(self, target, damage)
	else:
		# 近战攻击：挥击特效 + 直接伤害
		_play_swing_effect()
		_consume_weapon_durability()
		target.take_damage(damage, self)
		EventBus.entity_attacked.emit(self, target, damage)


func _calculate_damage(target: BaseCharacter) -> float:
	var total_damage = base_damage
	
	if weapon_data.is_empty():
		return total_damage
	
	if weapon_durability == -1.0 or weapon_durability > 0:
		var extra = float(weapon_data.get("extra_damage", 0))
		total_damage += extra
		
		var special_target = weapon_data.get("special_target", null)
		if special_target != null and target.character_id == "undead":
			var multiplier = float(weapon_data.get("special_multiplier", 1.0))
			total_damage *= multiplier
	
	return total_damage


# ─────────────────────────────────────────────
# 挥击特效 (v1.0.2)
# ─────────────────────────────────────────────

func _play_swing_effect() -> void:
	if _swing_arc_node == null:
		return
	
	# 创建临时弧线精灵
	var arc = _create_swing_arc_sprite()
	_swing_arc_node.add_child(arc)
	
	# 根据面朝方向设置初始角度
	var start_angle: float = 0.0
	var end_angle: float = 0.0
	var arc_pos: Vector2 = Vector2.ZERO
	match facing_direction:
		Direction.RIGHT:
			start_angle = -60.0
			end_angle = 60.0
			arc_pos = Vector2(16, 0)
		Direction.LEFT:
			start_angle = 120.0
			end_angle = 240.0
			arc_pos = Vector2(-16, 0)
		Direction.DOWN:
			start_angle = 30.0
			end_angle = 150.0
			arc_pos = Vector2(0, 16)
		Direction.UP:
			start_angle = 210.0
			end_angle = 330.0
			arc_pos = Vector2(0, -16)
	
	arc.position = arc_pos
	arc.rotation_degrees = start_angle
	
	# 动画：旋转弧线
	var tween = create_tween()
	tween.tween_property(arc, "rotation_degrees", end_angle, 0.15)
	tween.tween_property(arc, "modulate:a", 0.0, 0.1)
	tween.tween_callback(arc.queue_free)
	
	EventBus.swing_effect.emit(global_position, facing_direction)


func _create_swing_arc_sprite() -> Sprite2D:
	var arc_sprite = Sprite2D.new()
	# 创建弧线图像
	var img = Image.create(24, 6, false, Image.FORMAT_RGBA8)
	for x in range(24):
		for y in range(6):
			var alpha = 1.0 - float(x) / 24.0
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha * 0.8))
	arc_sprite.texture = ImageTexture.create_from_image(img)
	arc_sprite.z_index = 10
	return arc_sprite


# ─────────────────────────────────────────────
# 射弹系统 (v1.0.2)
# ─────────────────────────────────────────────

func _fire_projectile(target: BaseCharacter) -> void:
	var dir = (target.global_position - global_position).normalized()
	EventBus.projectile_fired.emit(global_position, dir, weapon_data, self)


# ─────────────────────────────────────────────
# 接受伤害 (v1.0.2 增强)
# ─────────────────────────────────────────────

func take_damage(amount: float, attacker: BaseCharacter = null) -> void:
	if not is_alive:
		# 尸体被攻击 (v1.0.2)
		if attacker:
			_corpse_hit(attacker)
		return
	
	current_hp = max(0.0, current_hp - amount)
	EventBus.hp_changed.emit(self, current_hp, max_hp)
	
	# 击退和僵直 (v1.0.2)
	if attacker:
		_apply_knockback(attacker)
		_react_to_being_attacked(attacker)
	
	if current_hp <= 0.0:
		die(attacker)


## 应用击退效果 (v1.0.2)
func _apply_knockback(attacker: BaseCharacter) -> void:
	var dir = (global_position - attacker.global_position).normalized()
	var weapon_weight = float(attacker.weapon_data.get("weight", 1))
	var force = KNOCKBACK_FORCE * (weapon_weight / 3.0)
	
	_knockback_velocity = dir * force
	
	# 将击退速度传递给 HitStunState
	set_meta("knockback_velocity", _knockback_velocity)
	
	# 进入僵直状态
	_enter_hit_stun()


## 进入受击僵直 (v1.0.2)
func _enter_hit_stun() -> void:
	if state_machine_node and state_machine_node.states.has("HitStunState"):
		_is_in_hit_stun = true
		state_machine_node.transition_to("HitStunState")


## 清除击退 (v1.0.2)
func clear_knockback() -> void:
	_knockback_velocity = Vector2.ZERO
	_is_in_hit_stun = false


# ─────────────────────────────────────────────
# 尸体系统 (v1.0.2)
# ─────────────────────────────────────────────

func _corpse_hit(attacker: BaseCharacter) -> void:
	_corpse_hit_count += 1
	_play_corpse_hit_effect()
	
	if _corpse_hit_count >= 3:
		_explode_corpse()


func _play_corpse_hit_effect() -> void:
	if has_node("AnimatedSprite2D"):
		var anim: AnimatedSprite2D = get_node("AnimatedSprite2D")
		anim.modulate = Color(1.0, 0.2, 0.2, 1.0)
		var tween = create_tween()
		tween.tween_property(anim, "modulate", Color(0.3, 0.3, 0.3, 0.6), 0.3)


func _explode_corpse() -> void:
	print("[BaseCharacter] %s 的尸体爆裂了！" % display_name)
	EventBus.blood_splatter.emit(global_position)
	_create_blood_splatter()
	
	if has_node("AnimatedSprite2D"):
		get_node("AnimatedSprite2D").visible = false
	
	# 延迟移除
	var timer = get_tree().create_timer(0.5)
	await timer.timeout
	queue_free()


func _create_blood_splatter() -> void:
	# 创建简单的红色粒子效果
	for i in range(8):
		var particle = Sprite2D.new()
		var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.8, 0.1, 0.05, 0.9))
		particle.texture = ImageTexture.create_from_image(img)
		particle.global_position = global_position
		particle.z_index = 5
		get_parent().add_child(particle)
		
		var angle = randf() * TAU
		var dist = randf_range(15.0, 40.0)
		var target_pos = global_position + Vector2(cos(angle), sin(angle)) * dist
		
		var tween = particle.create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", target_pos, 0.4)
		tween.tween_property(particle, "modulate:a", 0.0, 0.6)
		tween.set_parallel(false)
		tween.tween_callback(particle.queue_free)


# ─────────────────────────────────────────────
# 治疗与魔力
# ─────────────────────────────────────────────

func heal(amount: float) -> void:
	current_hp = min(max_hp, current_hp + amount)
	EventBus.hp_changed.emit(self, current_hp, max_hp)


func change_mp(amount: float) -> void:
	current_mp = clamp(current_mp + amount, 0.0, max_mp)
	EventBus.mp_changed.emit(self, current_mp, max_mp)


# ─────────────────────────────────────────────
# 死亡处理 (v1.0.2 增强)
# ─────────────────────────────────────────────

func die(killer: BaseCharacter = null) -> void:
	is_alive = false
	_corpse_hit_count = 0
	
	# 死亡击飞 (v1.0.2)
	if killer:
		var dir = (global_position - killer.global_position).normalized()
		var weapon_weight = float(killer.weapon_data.get("weight", 1))
		_death_knockback = dir * KNOCKBACK_FORCE * DEATH_KNOCKBACK_MULTIPLIER * (weapon_weight / 3.0)
		velocity = _death_knockback
	
	if state_machine_node:
		state_machine_node.transition_to("DeadState")
	
	EventBus.entity_died.emit(self, killer)
	FactionSystem.clear_individual_relations(self)
	
	# 隐藏武器
	if _weapon_sprite:
		_weapon_sprite.visible = false
	
	print("[BaseCharacter] %s 死亡！击杀者: %s" % [
		display_name, 
		killer.display_name if killer else "未知"
	])


# ─────────────────────────────────────────────
# 移动
# ─────────────────────────────────────────────

func get_pixel_speed() -> float:
	return move_speed * TILE_SIZE


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
	_update_weapon_sprite()


func switch_weapon(weapon_id: String) -> void:
	_equip_weapon(weapon_id)
	EventBus.weapon_switched.emit(self, weapon_data)
	# 头顶浮动文字
	_show_floating_text(weapon_data.get("display_name", "拳头"))


func _show_floating_text(text: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-20, -40)
	label.z_index = 20
	add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 20, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)


func _consume_weapon_durability() -> void:
	if weapon_durability == -1.0:
		return
	
	var cost = float(weapon_data.get("durability_per_hit", 0))
	weapon_durability = max(0.0, weapon_durability - cost)
	
	var max_dur = float(weapon_data.get("durability", 100))
	EventBus.weapon_durability_changed.emit(self, weapon_durability, max_dur)
	
	if weapon_durability <= 0.0:
		_break_weapon()


func _break_weapon() -> void:
	print("[BaseCharacter] %s 的武器 %s 损坏了！" % [display_name, weapon_data.get("display_name", "武器")])
	EventBus.weapon_broken.emit(self, weapon_data.get("id", ""))
	weapon_data = DataManager.get_weapon("fist")
	_update_weapon_sprite()


# ─────────────────────────────────────────────
# 背包管理 (v1.0.2)
# ─────────────────────────────────────────────

func add_to_inventory(item_data: Dictionary) -> bool:
	if inventory.size() >= INVENTORY_SIZE:
		return false
	
	# 特殊处理药水计数
	var item_type = item_data.get("item_type", "")
	if item_type == "health_potion":
		health_potions += 1
	elif item_type == "mana_potion":
		mana_potions += 1
	
	inventory.append(item_data.duplicate(true))
	EventBus.inventory_changed.emit()
	return true


func remove_from_inventory(index: int) -> Dictionary:
	if index < 0 or index >= inventory.size():
		return {}
	var item = inventory[index]
	inventory.remove_at(index)
	EventBus.inventory_changed.emit()
	return item


func use_health_potion() -> bool:
	for i in range(inventory.size()):
		if inventory[i].get("item_type", "") == "health_potion":
			var effect_val = float(inventory[i].get("effect_value", 30))
			heal(effect_val)
			health_potions -= 1
			inventory.remove_at(i)
			EventBus.inventory_changed.emit()
			_show_floating_text("+%.0f HP" % effect_val)
			return true
	return false


func use_mana_potion() -> bool:
	for i in range(inventory.size()):
		if inventory[i].get("item_type", "") == "mana_potion":
			var effect_val = float(inventory[i].get("effect_value", 30))
			change_mp(effect_val)
			mana_potions -= 1
			inventory.remove_at(i)
			EventBus.inventory_changed.emit()
			_show_floating_text("+%.0f MP" % effect_val)
			return true
	return false


# ─────────────────────────────────────────────
# 阵营关系响应
# ─────────────────────────────────────────────

func _react_to_being_attacked(attacker: BaseCharacter) -> void:
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


func get_hp_percent() -> float:
	if max_hp <= 0:
		return 0.0
	return current_hp / max_hp


func is_low_hp(threshold: float = 0.3) -> bool:
	return get_hp_percent() < threshold
