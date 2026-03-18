## Player.gd  v1.1
## 玩家控制角色
## 新增功能：背包系统、武器切换、H/B键使用药水、挥击弧线特效

extends BaseCharacter
class_name Player

# ─────────────────────────────────────────────
# 攻击
# ─────────────────────────────────────────────

const ATTACK_COOLDOWN := 0.5
var _attack_timer: float = 0.0

## 攻击范围内的目标
var enemies_in_range: Array = []

# ─────────────────────────────────────────────
# 交互
# ─────────────────────────────────────────────

var interactable_target: Node = null
var nearby_items: Array = []  # 附近掉落物品

# ─────────────────────────────────────────────
# 背包系统
# ─────────────────────────────────────────────

var inventory_ui: InventoryUI = null

# ─────────────────────────────────────────────
# 武器名称提示
# ─────────────────────────────────────────────

var _weapon_name_label: Label = null
var _weapon_name_timer: float = 0.0
const WEAPON_NAME_DISPLAY_TIME := 2.0


# ─────────────────────────────────────────────
# 初始化
# ─────────────────────────────────────────────

func _ready() -> void:
	faction = FactionSystem.Faction.PLAYER
	
	var char_id = GameStateManager.selected_character_id
	if char_id.is_empty():
		char_id = "villager"
	
	setup_from_data(char_id, false)
	
	# 连接区域信号
	if has_node("InteractArea"):
		$InteractArea.body_entered.connect(_on_interact_area_body_entered)
		$InteractArea.body_exited.connect(_on_interact_area_body_exited)
	
	if has_node("AttackArea"):
		$AttackArea.body_entered.connect(_on_attack_area_body_entered)
		$AttackArea.body_exited.connect(_on_attack_area_body_exited)
	
	EventBus.entity_died.connect(_on_entity_died)
	
	# 初始化状态机
	if state_machine_node:
		state_machine_node.init_state(state_machine_node.states.get("IdleState"))
	
	# 创建武器名称标签
	_create_weapon_name_label()
	
	# 创建背包UI
	_setup_inventory()
	
	print("[Player] 玩家初始化: ", display_name)


func _create_weapon_name_label() -> void:
	_weapon_name_label = Label.new()
	_weapon_name_label.name = "WeaponNameLabel"
	_weapon_name_label.add_theme_font_size_override("font_size", 10)
	_weapon_name_label.add_theme_color_override("font_color", Color.WHITE)
	_weapon_name_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_weapon_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_weapon_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_weapon_name_label.position = Vector2(-30, -36)
	_weapon_name_label.size = Vector2(60, 14)
	_weapon_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_weapon_name_label.visible = false
	add_child(_weapon_name_label)


func _setup_inventory() -> void:
	# 查找场景树中的 InventoryUI（由 GameLevel 场景管理）
	await get_tree().process_frame
	var ui_nodes = get_tree().get_nodes_in_group("inventory_ui")
	if ui_nodes.size() > 0:
		inventory_ui = ui_nodes[0] as InventoryUI
		inventory_ui.init_with_player(self)
	else:
		# 如果没找到，动态创建
		inventory_ui = InventoryUI.new()
		inventory_ui.name = "InventoryUI"
		get_tree().root.add_child(inventory_ui)
		inventory_ui.init_with_player(self)
	
	# 将初始武器加入武器列表
	if inventory_ui and not weapon_data.is_empty():
		inventory_ui._inventory.weapon_list.append(weapon_data.duplicate(true))


# ─────────────────────────────────────────────
# 每帧更新
# ─────────────────────────────────────────────

func _process(delta: float) -> void:
	super._process(delta)
	
	if not is_alive or not GameStateManager.is_playing():
		return
	
	# 攻击冷却
	if _attack_timer > 0:
		_attack_timer -= delta
	
	# 武器名称显示倒计时
	if _weapon_name_timer > 0:
		_weapon_name_timer -= delta
		if _weapon_name_timer <= 0 and _weapon_name_label:
			_weapon_name_label.visible = false
	
	# 交互键（F）
	if Input.is_action_just_pressed("interact"):
		_try_interact_or_pickup()
	
	# 攻击键（鼠标左键/J）
	if Input.is_action_just_pressed("attack") and _attack_timer <= 0:
		_try_attack()
	
	# 背包键（E）
	if Input.is_action_just_pressed("open_inventory"):
		if inventory_ui:
			inventory_ui.toggle()
	
	# 使用血瓶（H键）
	if Input.is_action_just_pressed("use_health_potion"):
		_use_potion("health_potion")
	
	# 使用蓝瓶（B键）
	if Input.is_action_just_pressed("use_mana_potion"):
		_use_potion("mana_potion")
	
	# 武器切换（鼠标滚轮）
	if Input.is_action_just_pressed("switch_weapon_next"):
		_switch_weapon(1)
	if Input.is_action_just_pressed("switch_weapon_prev"):
		_switch_weapon(-1)


func _physics_process(_delta: float) -> void:
	if not is_alive or not GameStateManager.is_playing():
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# 背包打开时不移动
	if inventory_ui and inventory_ui.is_open():
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	var input_dir = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	).normalized()
	
	velocity = input_dir * get_pixel_speed()
	
	if input_dir != Vector2.ZERO:
		update_facing(input_dir)
		if state_machine_node and state_machine_node.get_current_state_name() == "IdleState":
			state_machine_node.transition_to("MoveState")
	else:
		if state_machine_node and state_machine_node.get_current_state_name() == "MoveState":
			state_machine_node.transition_to("IdleState")
	
	move_and_slide()


# ─────────────────────────────────────────────
# 交互 / 拾取
# ─────────────────────────────────────────────

func _try_interact_or_pickup() -> void:
	# 优先拾取附近物品
	if nearby_items.size() > 0:
		var item = nearby_items[0]
		if is_instance_valid(item):
			item.pickup(self)
			return
	
	# 其次交互NPC
	if interactable_target != null:
		if interactable_target.has_method("interact"):
			interactable_target.interact(self)


func _on_interact_area_body_entered(body: Node) -> void:
	if body.has_method("interact"):
		interactable_target = body


func _on_interact_area_body_exited(body: Node) -> void:
	if interactable_target == body:
		interactable_target = null


# ─────────────────────────────────────────────
# 攻击
# ─────────────────────────────────────────────

func _try_attack() -> void:
	var weapon_type = weapon_data.get("type", weapon_data.get("weapon_type", "melee"))
	
	if weapon_type == "ranged":
		# 远程：向鼠标方向射击
		var mouse_world_pos = get_global_mouse_position()
		shoot_projectile(mouse_world_pos)
		_attack_timer = ATTACK_COOLDOWN
		# 播放挥击动画
		play_weapon_swing()
	else:
		# 近战：攻击范围内最近敌人
		var target = _get_nearest_enemy()
		if target:
			attack(target)
			_attack_timer = ATTACK_COOLDOWN
			# 播放武器挥击弧线特效
			play_weapon_swing()
			_spawn_swing_effect()


func _get_nearest_enemy() -> BaseCharacter:
	var nearest: BaseCharacter = null
	var min_dist = INF
	
	for entity in enemies_in_range:
		if entity is BaseCharacter and entity.is_alive:
			if FactionSystem.is_hostile(self, entity):
				var dist = global_position.distance_to(entity.global_position)
				if dist < min_dist:
					min_dist = dist
					nearest = entity
	
	return nearest


func _on_attack_area_body_entered(body: Node) -> void:
	if body is BaseCharacter and body != self:
		enemies_in_range.append(body)


func _on_attack_area_body_exited(body: Node) -> void:
	enemies_in_range.erase(body)


## 挥击弧线白线特效（在角色前方生成一个白色弧线节点）
func _spawn_swing_effect() -> void:
	var effect = Line2D.new()
	effect.width = 2.0
	effect.default_color = Color(1, 1, 1, 0.9)
	effect.z_index = 5
	
	# 根据朝向决定弧线方向
	var offset_base = Vector2.ZERO
	var arc_dir = 1.0
	match facing_direction:
		Direction.RIGHT:
			offset_base = Vector2(20, 0)
			arc_dir = 1.0
		Direction.LEFT:
			offset_base = Vector2(-20, 0)
			arc_dir = -1.0
		Direction.DOWN:
			offset_base = Vector2(0, 20)
			arc_dir = 1.0
		Direction.UP:
			offset_base = Vector2(0, -20)
			arc_dir = -1.0
	
	# 生成弧线点（半圆）
	var points = PackedVector2Array()
	for i in range(7):
		var angle = -60.0 + i * 20.0
		var rad = deg_to_rad(angle)
		var weight = float(weapon_data.get("weight", 1))
		var radius = 18.0 + weight * 2.0
		
		var px: float
		var py: float
		match facing_direction:
			Direction.RIGHT, Direction.LEFT:
				px = offset_base.x + cos(rad) * weight * arc_dir
				py = sin(rad) * radius
			_:
				px = sin(rad) * radius
				py = offset_base.y + cos(rad) * weight * arc_dir
		points.append(Vector2(px, py))
	
	effect.points = points
	add_child(effect)
	
	# 淡出并移除
	var tween = create_tween()
	tween.tween_property(effect, "modulate:a", 0.0, 0.2)
	tween.tween_callback(effect.queue_free)


# ─────────────────────────────────────────────
# 武器切换
# ─────────────────────────────────────────────

func _switch_weapon(direction: int) -> void:
	if inventory_ui == null or inventory_ui._inventory == null:
		return
	
	var new_weapon: Dictionary
	if direction > 0:
		new_weapon = inventory_ui._inventory.switch_weapon_next()
	else:
		new_weapon = inventory_ui._inventory.switch_weapon_prev()
	
	if not new_weapon.is_empty():
		equip_weapon_from_inventory(new_weapon)


## 从背包装备武器（供背包UI和武器切换调用）
func equip_weapon_from_inventory(new_weapon_data: Dictionary) -> void:
	weapon_data = new_weapon_data.duplicate(true)
	
	var dur = weapon_data.get("durability", -1)
	weapon_durability = float(dur)
	
	_update_weapon_display()
	EventBus.weapon_durability_changed.emit(self, weapon_durability, float(dur))
	
	# 显示武器名称提示
	_show_weapon_name(weapon_data.get("display_name", "武器"))
	print("[Player] 切换武器: %s" % weapon_data.get("display_name", "?"))


func _show_weapon_name(name: String) -> void:
	if not _weapon_name_label:
		return
	_weapon_name_label.text = name
	_weapon_name_label.visible = true
	_weapon_name_timer = WEAPON_NAME_DISPLAY_TIME


# ─────────────────────────────────────────────
# 药水使用
# ─────────────────────────────────────────────

func _use_potion(potion_id: String) -> void:
	if inventory_ui == null or inventory_ui._inventory == null:
		# 如果没有背包中的药水，尝试直接消耗（兼容商店直接使用）
		_apply_potion_effect(potion_id)
		return
	
	# 从背包中取出
	if inventory_ui._inventory.consume_item(potion_id):
		_apply_potion_effect(potion_id)
		inventory_ui.refresh_display()
	else:
		print("[Player] 背包中没有 %s" % potion_id)


func _apply_potion_effect(potion_id: String) -> void:
	var item_data = DataManager.get_shop_item(potion_id)
	if item_data.is_empty():
		return
	
	var effect = item_data.get("effect", "")
	var value = float(item_data.get("effect_value", 0))
	match effect:
		"heal":
			heal(value)
			print("[Player] 使用血瓶，恢复 %.0f HP" % value)
		"restore_mp":
			change_mp(value)
			print("[Player] 使用蓝瓶，恢复 %.0f MP" % value)


# ─────────────────────────────────────────────
# 事件处理
# ─────────────────────────────────────────────

func _on_entity_died(entity: Node, killer: Node) -> void:
	if killer != self:
		return
	if not entity is BaseCharacter:
		return
	
	var char_data = DataManager.get_character(entity.character_id)
	if char_data.is_empty():
		return
	
	var gold_min = char_data.get("drop_gold_min", 0)
	var gold_max = char_data.get("drop_gold_max", 0)
	if gold_max > 0:
		var gold_drop = randi_range(gold_min, gold_max)
		GameStateManager.add_gold(gold_drop)
		print("[Player] 击杀 %s 获得 %d 金币" % [entity.display_name, gold_drop])
	
	if entity.faction == FactionSystem.Faction.MONSTER:
		GameStateManager.update_kill_count()


func _react_to_being_attacked(attacker: BaseCharacter) -> void:
	pass
