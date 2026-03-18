## BaseCharacter.gd  v1.1
## 全角色基类：增强版
## 新增：更大像素小人精灵(16x24)、碰撞弹回、武器显示改进

extends CharacterBody2D
class_name BaseCharacter

# ─────────────────────────────────────────────
# 身份
# ─────────────────────────────────────────────

var unique_id: String = ""
var character_id: String = ""
var display_name: String = "未知"

var faction: int = FactionSystem.Faction.NEUTRAL


# ─────────────────────────────────────────────
# 属性
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
# 武器
# ─────────────────────────────────────────────

var weapon_data: Dictionary = {}
var weapon_durability: float = -1.0
var skills: Array = []


# ─────────────────────────────────────────────
# 节点引用
# ─────────────────────────────────────────────

@onready var state_machine_node: StateMachine = $StateMachine if has_node("StateMachine") else null
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var collision: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null
@onready var detection_area: Area2D = $DetectionArea if has_node("DetectionArea") else null
@onready var attack_area: Area2D = $AttackArea if has_node("AttackArea") else null

var weapon_sprite: Sprite2D = null


# ─────────────────────────────────────────────
# 常量
# ─────────────────────────────────────────────

const TILE_SIZE := 32
const MP_REGEN_INTERVAL := 1.0
const KNOCKBACK_FORCE := 350.0
const KNOCKBACK_DECAY := 0.85


# ─────────────────────────────────────────────
# 击退 / 状态
# ─────────────────────────────────────────────

var _knockback_velocity: Vector2 = Vector2.ZERO
var _is_in_hit_stun: bool = false
var _corpse_hit_count: int = 0
var _death_knockback: Vector2 = Vector2.ZERO
var _mp_regen_timer: float = 0.0

# 碰撞反弹相关
var _last_velocity: Vector2 = Vector2.ZERO


# ─────────────────────────────────────────────
# 初始化
# ─────────────────────────────────────────────

func _ready() -> void:
	if state_machine_node:
		print("[BaseCharacter] %s 状态机节点: %s" % [display_name, state_machine_node.name])
	
	# 应用像素小人精灵
	_apply_character_sprite()
	
	# 创建武器精灵
	_create_weapon_sprite()


func _apply_character_sprite() -> void:
	if sprite == null:
		return
	
	var tex = PlaceholderSpriteGenerator.generate_for_character(character_id)
	if tex:
		sprite.texture = tex
		# 16x24 像素，scale x2 显示更清晰
		sprite.scale = Vector2(2.0, 2.0)
		sprite.position = Vector2(0, -8)  # 上移半格，让脚在碰撞圆中心


func setup_from_data(char_id: String, is_npc: bool = false) -> void:
	character_id = char_id
	var data = DataManager.get_character(char_id)
	if data.is_empty():
		push_error("[BaseCharacter] 无法加载角色数据: " + char_id)
		return
	
	display_name = data.get("display_name", "未知")
	
	var faction_str = data.get("faction", "NEUTRAL")
	faction = _parse_faction(faction_str)
	
	# NPC血量现在使用npc_hp_ratio = 1.0（不再削减）
	var base_hp = float(data.get("hp", 100))
	if is_npc:
		max_hp = base_hp * data.get("npc_hp_ratio", 1.0)
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
	
	# 更新精灵（此时character_id已设置）
	_apply_character_sprite()
	
	print("[BaseCharacter] %s 初始化: HP=%.0f, 武器=%s" % [
		display_name, max_hp, weapon_data.get("display_name", "无")
	])


# ─────────────────────────────────────────────
# 每帧
# ─────────────────────────────────────────────

func _process(delta: float) -> void:
	if not is_alive:
		return
	_process_passive_skills(delta)


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
# 战斗
# ─────────────────────────────────────────────

func attack(target: BaseCharacter) -> void:
	if not is_alive or not target.is_alive:
		return
	
	var damage = _calculate_damage(target)
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
		if special_target != null and target.character_id == special_target:
			var multiplier = float(weapon_data.get("special_multiplier", 1.0))
			total_damage *= multiplier
	
	return total_damage


func take_damage(amount: float, attacker: BaseCharacter = null) -> void:
	print("[BaseCharacter] %s 受到伤害: %.1f" % [display_name, amount])
	
	if is_alive:
		current_hp = max(0.0, current_hp - amount)
		EventBus.hp_changed.emit(self, current_hp, max_hp)
		
		if attacker:
			_react_to_being_attacked(attacker)
		
		if attacker and is_alive:
			_apply_knockback(attacker)
			_enter_hit_stun()
		
		if current_hp <= 0.0:
			die(attacker)
	else:
		_corpse_hit(attacker)


func heal(amount: float) -> void:
	current_hp = min(max_hp, current_hp + amount)
	EventBus.hp_changed.emit(self, current_hp, max_hp)


func change_mp(amount: float) -> void:
	current_mp = clamp(current_mp + amount, 0.0, max_mp)
	EventBus.mp_changed.emit(self, current_mp, max_mp)


func die(killer: BaseCharacter = null) -> void:
	is_alive = false
	
	if killer:
		var death_dir = (global_position - killer.global_position).normalized()
		if death_dir.length() < 0.1:
			death_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		_death_knockback = death_dir * KNOCKBACK_FORCE * 1.5
	else:
		_death_knockback = Vector2.ZERO
	
	_corpse_hit_count = 0
	
	if state_machine_node:
		state_machine_node.transition_to("DeadState")
	
	EventBus.entity_died.emit(self, killer)
	FactionSystem.clear_individual_relations(self)
	
	print("[BaseCharacter] %s 死亡！击杀者: %s" % [
		display_name, killer.display_name if killer else "未知"
	])


# ─────────────────────────────────────────────
# 移动
# ─────────────────────────────────────────────

func get_pixel_speed() -> float:
	return move_speed * TILE_SIZE


func update_facing(direction: Vector2) -> void:
	var old_dir = facing_direction
	if direction.x > 0.1:
		facing_direction = Direction.RIGHT
	elif direction.x < -0.1:
		facing_direction = Direction.LEFT
	elif direction.y > 0.1:
		facing_direction = Direction.DOWN
	elif direction.y < -0.1:
		facing_direction = Direction.UP
	
	if old_dir != facing_direction:
		_update_weapon_position()
		# 精灵翻转（左右方向）
		if sprite:
			sprite.flip_h = (facing_direction == Direction.LEFT)


# ─────────────────────────────────────────────
# 武器管理
# ─────────────────────────────────────────────

func _equip_weapon(weapon_id: String) -> void:
	weapon_data = DataManager.get_weapon(weapon_id)
	if weapon_data.is_empty():
		weapon_durability = -1.0
		if weapon_sprite:
			weapon_sprite.visible = false
		return
	
	var dur = weapon_data.get("durability", -1)
	weapon_durability = float(dur)
	EventBus.weapon_durability_changed.emit(self, weapon_durability, float(dur))
	
	_update_weapon_display()


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
	print("[BaseCharacter] %s 的武器损坏！" % display_name)
	EventBus.weapon_broken.emit(self, weapon_data.get("id", ""))
	weapon_data = DataManager.get_weapon("fist")


func _react_to_being_attacked(attacker: BaseCharacter) -> void:
	pass


# ─────────────────────────────────────────────
# 工具
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


# ─────────────────────────────────────────────
# 击退和僵直
# ─────────────────────────────────────────────

func _apply_knockback(attacker: BaseCharacter) -> void:
	if not attacker:
		return
	
	var knockback_dir = (global_position - attacker.global_position).normalized()
	if knockback_dir.length() < 0.1:
		knockback_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	
	var knockback_strength = KNOCKBACK_FORCE
	
	# 武器重量影响击退力度
	if attacker.weapon_data and attacker.weapon_data.has("weight"):
		var weight = float(attacker.weapon_data.get("weight", 1))
		knockback_strength *= (0.5 + weight * 0.2)  # weight 1→0.7x, 3→1.1x, 5→1.5x
	
	_knockback_velocity = knockback_dir * knockback_strength
	
	if state_machine_node:
		set_meta("hit_knockback_direction", knockback_dir)
		set_meta("hit_knockback_speed", knockback_strength)
	
	print("[BaseCharacter] %s 受击退，力度: %.1f" % [display_name, knockback_strength])


func _enter_hit_stun() -> void:
	if not state_machine_node:
		return
	
	if state_machine_node.get_current_state_name() == "HitStunState":
		return  # 已在僵直状态，不重复进入（避免无限循环）
	
	state_machine_node.transition_to("HitStunState")
	_is_in_hit_stun = true


func clear_knockback() -> void:
	_knockback_velocity = Vector2.ZERO
	_is_in_hit_stun = false


## 碰撞弹回：击退速度撞墙时反弹
func apply_bounce_on_collision() -> void:
	if not is_alive:
		return
	
	var slide_count = get_slide_collision_count()
	if slide_count > 0 and _knockback_velocity.length() > 50.0:
		var col = get_slide_collision(0)
		if col:
			# 反射速度
			var normal = col.get_normal()
			_knockback_velocity = _knockback_velocity.bounce(normal) * 0.6
			if state_machine_node:
				set_meta("hit_knockback_speed", _knockback_velocity.length())
				set_meta("hit_knockback_direction", _knockback_velocity.normalized())


# ─────────────────────────────────────────────
# 尸体效果
# ─────────────────────────────────────────────

func _corpse_hit(attacker: BaseCharacter) -> void:
	if is_alive:
		return
	
	_corpse_hit_count += 1
	_play_corpse_hit_effect()
	
	if attacker:
		var corpse_dir = (global_position - attacker.global_position).normalized()
		if corpse_dir.length() < 0.1:
			corpse_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		_death_knockback = corpse_dir * KNOCKBACK_FORCE * 0.5
	
	if _corpse_hit_count >= 3:
		_explode_corpse()


func _play_corpse_hit_effect() -> void:
	if has_node("Sprite2D"):
		var sp: Sprite2D = get_node("Sprite2D")
		sp.modulate = Color(1, 0.3, 0.3, 1)
		var timer = get_tree().create_timer(0.1)
		timer.timeout.connect(_restore_corpse_color)
	EventBus.play_sound.emit("corpse_hit", global_position)


func _restore_corpse_color() -> void:
	if has_node("Sprite2D"):
		get_node("Sprite2D").modulate = Color(1, 1, 1, 1)


func _explode_corpse() -> void:
	print("[BaseCharacter] %s 的尸体爆裂！" % display_name)
	_create_blood_splatter()
	EventBus.play_sound.emit("corpse_explode", global_position)
	if sprite:
		sprite.visible = false
	await get_tree().create_timer(0.5).timeout
	queue_free()


func _create_blood_splatter() -> void:
	print("[BaseCharacter] 血液飞溅 at ", global_position)
	EventBus.blood_splatter.emit(global_position)


# ─────────────────────────────────────────────
# 武器显示
# ─────────────────────────────────────────────

func _create_weapon_sprite() -> void:
	if weapon_sprite and is_instance_valid(weapon_sprite):
		remove_child(weapon_sprite)
		weapon_sprite.queue_free()
	
	weapon_sprite = Sprite2D.new()
	weapon_sprite.name = "WeaponSprite"
	weapon_sprite.z_index = 2
	weapon_sprite.visible = false
	weapon_sprite.scale = Vector2(2.0, 2.0)  # 放大武器图标
	add_child(weapon_sprite)


func _update_weapon_display() -> void:
	if not weapon_sprite:
		return
	
	if weapon_data.is_empty():
		weapon_sprite.visible = false
		return
	
	# 使用生成的武器图标纹理
	var weapon_id = weapon_data.get("id", "fist")
	var tex = PlaceholderSpriteGenerator.generate_weapon_icon(weapon_id)
	if tex:
		weapon_sprite.texture = tex
		weapon_sprite.visible = true
	else:
		weapon_sprite.visible = false
	
	_update_weapon_position()


func _update_weapon_position() -> void:
	if not weapon_sprite or not weapon_sprite.visible:
		return
	
	var offset = Vector2.ZERO
	match facing_direction:
		Direction.RIGHT:
			offset = Vector2(18, 0)
			weapon_sprite.rotation_degrees = 0
		Direction.LEFT:
			offset = Vector2(-18, 0)
			weapon_sprite.rotation_degrees = 180
		Direction.DOWN:
			offset = Vector2(0, 18)
			weapon_sprite.rotation_degrees = 90
		Direction.UP:
			offset = Vector2(0, -18)
			weapon_sprite.rotation_degrees = -90
	
	weapon_sprite.position = offset


func play_weapon_swing() -> void:
	if not weapon_sprite or not weapon_sprite.visible:
		return
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	
	var weight = float(weapon_data.get("weight", 1))
	var swing_angle = 60.0 + weight * 10.0  # 重量越大摆动角越大
	var swing_speed = max(0.08, 0.15 - weight * 0.01)
	
	var start_rot = weapon_sprite.rotation_degrees
	var end_rot = start_rot + swing_angle
	
	tween.tween_property(weapon_sprite, "rotation_degrees", end_rot, swing_speed)
	tween.tween_property(weapon_sprite, "rotation_degrees", start_rot, swing_speed)


## 发射射弹（圣杖）
func shoot_projectile(target_position: Vector2) -> void:
	if weapon_data.is_empty():
		return
	
	var weapon_type = weapon_data.get("type", weapon_data.get("weapon_type", "melee"))
	if weapon_type != "ranged":
		return
	
	var projectile_scene = load("res://scenes/Projectile.tscn")
	if not projectile_scene:
		print("[BaseCharacter] 无法加载射弹场景")
		return
	
	var projectile = projectile_scene.instantiate()
	get_parent().add_child(projectile)
	projectile.global_position = global_position
	
	var direction = (target_position - global_position).normalized()
	projectile.set_direction(direction, self, base_damage + magic_damage)
	
	print("[BaseCharacter] 发射射弹")
