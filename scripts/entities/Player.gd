## Player.gd
## 玩家控制角色 v1.0.2
## 新增：背包开关(E)、药水使用(H/B)、滚轮切武器、拾取(F)

extends BaseCharacter
class_name Player

# ─────────────────────────────────────────────
# 玩家专属属性
# ─────────────────────────────────────────────
const ATTACK_COOLDOWN := 0.5
var _attack_timer: float = 0.0

var interactable_target: Node = null
var enemies_in_range: Array = []

## 武器列表（背包中的武器ID），用于滚轮切换
var weapon_list: Array = []
var _current_weapon_index: int = 0


# ─────────────────────────────────────────────
# 初始化
# ─────────────────────────────────────────────

func _ready() -> void:
	super._ready()
	faction = FactionSystem.Faction.PLAYER
	
	var char_id = GameStateManager.selected_character_id
	if char_id.is_empty():
		char_id = "villager"
	
	setup_from_data(char_id, false)
	
	# 初始武器加入武器列表
	weapon_list.append(weapon_data.get("id", "fist"))
	
	if has_node("InteractArea"):
		$InteractArea.body_entered.connect(_on_interact_area_body_entered)
		$InteractArea.body_exited.connect(_on_interact_area_body_exited)
	
	if has_node("AttackArea"):
		$AttackArea.body_entered.connect(_on_attack_area_body_entered)
		$AttackArea.body_exited.connect(_on_attack_area_body_exited)
	
	EventBus.entity_died.connect(_on_entity_died)
	
	if state_machine_node:
		state_machine_node.init_state(state_machine_node.states.get("IdleState"))
	
	print("[Player] 玩家角色初始化: ", display_name)


# ─────────────────────────────────────────────
# 每帧更新
# ─────────────────────────────────────────────

func _process(delta: float) -> void:
	super._process(delta)
	
	if not is_alive or not GameStateManager.is_playing():
		return
	
	if _attack_timer > 0:
		_attack_timer -= delta
	
	# 交互
	if Input.is_action_just_pressed("interact"):
		_try_interact()
	
	# 攻击
	if Input.is_action_just_pressed("attack") and _attack_timer <= 0:
		_try_attack()
	
	# 背包开关 (v1.0.2)
	if Input.is_action_just_pressed("toggle_inventory"):
		EventBus.inventory_changed.emit()
	
	# 使用血瓶 (v1.0.2)
	if Input.is_action_just_pressed("use_health_potion"):
		if not use_health_potion():
			_show_floating_text("没有血瓶！")
	
	# 使用蓝瓶 (v1.0.2)
	if Input.is_action_just_pressed("use_mana_potion"):
		if not use_mana_potion():
			_show_floating_text("没有蓝瓶！")


func _physics_process(_delta: float) -> void:
	if not is_alive or not GameStateManager.is_playing():
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


func _unhandled_input(event: InputEvent) -> void:
	if not is_alive or not GameStateManager.is_playing():
		return
	
	# 鼠标滚轮切换武器 (v1.0.2)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_cycle_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_cycle_weapon(1)


# ─────────────────────────────────────────────
# 武器切换 (v1.0.2)
# ─────────────────────────────────────────────

func _cycle_weapon(direction: int) -> void:
	if weapon_list.size() <= 1:
		return
	_current_weapon_index = (_current_weapon_index + direction) % weapon_list.size()
	if _current_weapon_index < 0:
		_current_weapon_index = weapon_list.size() - 1
	switch_weapon(weapon_list[_current_weapon_index])


# ─────────────────────────────────────────────
# 交互逻辑
# ─────────────────────────────────────────────

func _try_interact() -> void:
	if interactable_target == null:
		return
	if interactable_target.has_method("interact"):
		interactable_target.interact(self)


func _on_interact_area_body_entered(body: Node) -> void:
	if body.has_method("interact"):
		interactable_target = body

func _on_interact_area_body_exited(body: Node) -> void:
	if interactable_target == body:
		interactable_target = null


# ─────────────────────────────────────────────
# 攻击逻辑
# ─────────────────────────────────────────────

func _try_attack() -> void:
	var target = _get_nearest_enemy()
	if target:
		attack(target)
		_attack_timer = ATTACK_COOLDOWN


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
		_show_floating_text("+%d 金币" % gold_drop)
		print("[Player] 击杀 %s 获得 %d 金币" % [entity.display_name, gold_drop])
	
	if entity.faction == FactionSystem.Faction.MONSTER:
		GameStateManager.update_kill_count()


func _react_to_being_attacked(attacker: BaseCharacter) -> void:
	pass
