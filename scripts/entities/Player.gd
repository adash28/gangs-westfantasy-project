## Player.gd
## 玩家控制角色，继承自 BaseCharacter
## 处理键盘输入、攻击操作、交互等

extends BaseCharacter
class_name Player

# ─────────────────────────────────────────────
# 玩家专属属性
# ─────────────────────────────────────────────

## 攻击冷却时间（秒）
const ATTACK_COOLDOWN := 0.5
var _attack_timer: float = 0.0

## 交互范围内的目标
var interactable_target: Node = null

## 攻击范围内的敌人列表
var enemies_in_range: Array = []


# ─────────────────────────────────────────────
# 初始化
# ─────────────────────────────────────────────

func _ready() -> void:
	faction = FactionSystem.Faction.PLAYER
	
	# 从 GameStateManager 获取选择的角色ID
	var char_id = GameStateManager.selected_character_id
	if char_id.is_empty():
		char_id = "villager"  # 默认角色
	
	setup_from_data(char_id, false)
	
	# 连接交互检测区域信号
	if has_node("InteractArea"):
		$InteractArea.body_entered.connect(_on_interact_area_body_entered)
		$InteractArea.body_exited.connect(_on_interact_area_body_exited)
	
	# 连接攻击范围信号
	if has_node("AttackArea"):
		$AttackArea.body_entered.connect(_on_attack_area_body_entered)
		$AttackArea.body_exited.connect(_on_attack_area_body_exited)
	
	# 监听死亡事件以更新金币（击杀掉落）
	EventBus.entity_died.connect(_on_entity_died)
	
	# 初始化状态机
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
	
	# 更新攻击冷却
	if _attack_timer > 0:
		_attack_timer -= delta
	
	# 交互输入
	if Input.is_action_just_pressed("interact"):
		_try_interact()
	
	# 攻击输入
	if Input.is_action_just_pressed("attack") and _attack_timer <= 0:
		_try_attack()


func _physics_process(_delta: float) -> void:
	if not is_alive or not GameStateManager.is_playing():
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# 读取移动输入
	var input_dir = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	).normalized()
	
	velocity = input_dir * get_pixel_speed()
	
	if input_dir != Vector2.ZERO:
		update_facing(input_dir)
		# 通知状态机切换到移动状态
		if state_machine_node and state_machine_node.get_current_state_name() == "IdleState":
			state_machine_node.transition_to("MoveState")
	else:
		# 通知状态机切换到待机状态
		if state_machine_node and state_machine_node.get_current_state_name() == "MoveState":
			state_machine_node.transition_to("IdleState")
	
	move_and_slide()


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
	# 找到攻击范围内最近的敌人
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

## 监听实体死亡事件，处理掉落金币
func _on_entity_died(entity: Node, killer: Node) -> void:
	if killer != self:
		return
	
	if not entity is BaseCharacter:
		return
	
	# 掉落金币
	var char_data = DataManager.get_character(entity.character_id)
	if char_data.is_empty():
		return
	
	var gold_min = char_data.get("drop_gold_min", 0)
	var gold_max = char_data.get("drop_gold_max", 0)
	if gold_max > 0:
		var gold_drop = randi_range(gold_min, gold_max)
		GameStateManager.add_gold(gold_drop)
		print("[Player] 击杀 %s 获得 %d 金币" % [entity.display_name, gold_drop])
	
	# 如果击杀的是魔物，更新第一章任务进度
	if entity.faction == FactionSystem.Faction.MONSTER:
		GameStateManager.update_kill_count()


## 覆盖被攻击响应（玩家自己不需要处理，但这里可以播放受击特效）
func _react_to_being_attacked(attacker: BaseCharacter) -> void:
	# 触发受击特效/音效（TODO：添加特效节点后实现）
	pass
