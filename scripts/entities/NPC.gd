## NPC.gd
## NPC 基类：继承 BaseCharacter，添加 AI 行为、阵营响应、交互逻辑
## 所有 NPC（村民/商人/神父/哥布林/不死者）都继承此类

extends BaseCharacter
class_name NPC

# ─────────────────────────────────────────────
# AI 感知参数
# ─────────────────────────────────────────────

## 视野范围（像素）
@export var detection_range: float = 160.0

## 攻击范围（像素）
@export var attack_range: float = 48.0

## 攻击冷却
const ATTACK_COOLDOWN := 1.2
var _attack_timer: float = 0.0

## 当前攻击目标
var attack_target: BaseCharacter = null

## 当前跟随目标（同盟/忠诚状态）
var follow_target: BaseCharacter = null

## 巡逻原点与随机目标
var patrol_origin: Vector2 = Vector2.ZERO
var patrol_target: Vector2 = Vector2.ZERO
const PATROL_RADIUS := 80.0
const PATROL_WAIT_TIME := 2.5
var _patrol_wait_timer: float = 0.0

## 视野范围内的其他实体（由 DetectionArea 维护）
var entities_in_detection: Array = []


# ─────────────────────────────────────────────
# 初始化
# ─────────────────────────────────────────────

func _ready() -> void:
	# 子类应先设置 character_id，再调用 super._ready()
	pass


## 由外部（MapGenerator 或场景）调用，完成初始化
func init_npc(char_id: String) -> void:
	setup_from_data(char_id, true)   # NPC血量1/3
	patrol_origin = global_position
	patrol_target = _random_patrol_point()
	
	# 连接感知范围信号
	if has_node("DetectionArea"):
		$DetectionArea.body_entered.connect(_on_detection_body_entered)
		$DetectionArea.body_exited.connect(_on_detection_body_exited)
	
	# 监听攻击事件（用于同盟响应）
	EventBus.entity_attacked.connect(_on_entity_attacked_globally)
	
	# 初始化状态机
	if state_machine_node:
		state_machine_node.init_state(state_machine_node.states.get("IdleState"))


# ─────────────────────────────────────────────
# 每帧更新
# ─────────────────────────────────────────────

func _process(delta: float) -> void:
	super._process(delta)
	if not is_alive:
		return
	if _attack_timer > 0:
		_attack_timer -= delta
	_ai_tick(delta)


func _physics_process(_delta: float) -> void:
	if not is_alive:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	# 移动由状态机中各 State 控制 velocity，这里统一执行
	move_and_slide()


# ─────────────────────────────────────────────
# AI 决策核心（Tick）
# ─────────────────────────────────────────────

func _ai_tick(_delta: float) -> void:
	if not state_machine_node:
		return
	var sm = state_machine_node
	
	# 优先级：Dead > Attack > Follow > Patrol/Idle
	if not is_alive:
		return
	
	# 1. 有仇恨目标且目标存活 → Attack
	if attack_target and attack_target.is_alive:
		var dist = global_position.distance_to(attack_target.global_position)
		if dist <= attack_range:
			# 在攻击范围内：切换 Attack 状态，执行攻击
			if sm.get_current_state_name() != "AttackState":
				sm.transition_to("AttackState")
			if _attack_timer <= 0:
				attack(attack_target)
				_attack_timer = ATTACK_COOLDOWN
		else:
			# 超出攻击距离：追击（Move 状态）
			if sm.get_current_state_name() != "MoveState":
				sm.transition_to("MoveState")
			_move_toward(attack_target.global_position)
		return
	
	# 2. 有跟随目标（忠诚/同盟）→ Follow
	if follow_target and follow_target.is_alive:
		var dist = global_position.distance_to(follow_target.global_position)
		if dist > 96.0:  # 超过3格距离才跟上
			if sm.get_current_state_name() != "MoveState":
				sm.transition_to("MoveState")
			_move_toward(follow_target.global_position)
		else:
			if sm.get_current_state_name() == "MoveState":
				sm.transition_to("IdleState")
		return
	
	# 3. 默认：巡逻
	_patrol_tick(_delta)


func _patrol_tick(delta: float) -> void:
	var sm = state_machine_node
	var dist = global_position.distance_to(patrol_target)
	
	if dist < 8.0:
		# 到达巡逻目标点，等待一段时间
		velocity = Vector2.ZERO
		if sm.get_current_state_name() != "IdleState":
			sm.transition_to("IdleState")
		_patrol_wait_timer += delta
		if _patrol_wait_timer >= PATROL_WAIT_TIME:
			_patrol_wait_timer = 0.0
			patrol_target = _random_patrol_point()
	else:
		if sm.get_current_state_name() != "MoveState":
			sm.transition_to("MoveState")
		_move_toward(patrol_target)


func _move_toward(target_pos: Vector2) -> void:
	var dir = (target_pos - global_position).normalized()
	velocity = dir * get_pixel_speed()
	update_facing(dir)


func _random_patrol_point() -> Vector2:
	var angle = randf() * TAU
	var radius = randf() * PATROL_RADIUS
	return patrol_origin + Vector2(cos(angle), sin(angle)) * radius


# ─────────────────────────────────────────────
# 感知区域回调
# ─────────────────────────────────────────────

func _on_detection_body_entered(body: Node) -> void:
	if not body is BaseCharacter or body == self:
		return
	entities_in_detection.append(body)
	
	# 立即判断关系，决定初始行为
	var rel = FactionSystem.get_relation(self, body)
	match rel:
		FactionSystem.Relation.HOSTILE:
			_set_attack_target(body)
		FactionSystem.Relation.LOYAL, FactionSystem.Relation.ALLIED:
			# 如果是玩家，设为跟随目标
			if body is Player:
				follow_target = body


func _on_detection_body_exited(body: Node) -> void:
	entities_in_detection.erase(body)
	if attack_target == body:
		attack_target = null
	if follow_target == body:
		follow_target = null


# ─────────────────────────────────────────────
# 全局攻击事件监听（同盟响应逻辑）
# ─────────────────────────────────────────────

func _on_entity_attacked_globally(attacker: Node, target: Node, _damage: float) -> void:
	if not is_alive:
		return
	
	# 规则1：忠诚 - 玩家对任何人造成伤害或被攻击，立刻仇恨攻击者
	var rel_to_attacker = FactionSystem.get_relation(self, attacker)
	if rel_to_attacker == FactionSystem.Relation.LOYAL:
		# 攻击了我忠诚的对象的目标
		if target is BaseCharacter and FactionSystem.is_friendly(self, target):
			_set_attack_target(attacker)
			return
	
	# 规则2：同盟 - 被同盟的玩家/队友受到攻击时，转而仇恨攻击者
	if target is BaseCharacter and FactionSystem.is_friendly(self, target as BaseCharacter):
		if attacker is BaseCharacter and FactionSystem.is_hostile(self, attacker as BaseCharacter):
			_set_attack_target(attacker)


func _set_attack_target(target: Node) -> void:
	if target is BaseCharacter and target.is_alive:
		attack_target = target
		# 将个体关系设置为仇恨（覆盖默认矩阵）
		FactionSystem.set_individual_relation(self, target, FactionSystem.Relation.HOSTILE, true)


# ─────────────────────────────────────────────
# 被攻击响应（覆盖 BaseCharacter）
# ─────────────────────────────────────────────

func _react_to_being_attacked(attacker: BaseCharacter) -> void:
	# 无论之前关系如何，被攻击时立刻转为仇恨
	_set_attack_target(attacker)
	
	# 如果是同盟状态，通知周围同盟NPC
	EventBus.entity_attacked.emit(attacker, self, 0)


# ─────────────────────────────────────────────
# 交互接口（村民/商人/神父 Override）
# ─────────────────────────────────────────────

## 玩家按 F 键时调用
func interact(player: Player) -> void:
	var data = DataManager.get_character(character_id)
	var interaction_type = data.get("interaction_type", "none")
	
	match interaction_type:
		"hire":
			_interact_hire(player, data)
		"shop":
			_interact_shop(player)
		"none":
			pass  # 魔物无交互


func _interact_hire(player: Player, data: Dictionary) -> void:
	var cost = data.get("hire_cost", 20)
	if GameStateManager.spend_gold(cost):
		# 雇佣成功：阵营改为 ALLY，设置为跟随玩家
		faction = FactionSystem.Faction.ALLY
		follow_target = player
		attack_target = null
		FactionSystem.set_individual_relation(self, player, FactionSystem.Relation.LOYAL)
		EventBus.npc_hired.emit(self, player)
		print("[NPC] %s 被雇佣！花费 %d 金币" % [display_name, cost])
		# 触发对话
		EventBus.dialogue_triggered.emit(display_name, ["好的，我愿意为你效劳！", "（%s 加入了你的队伍）" % display_name])
	else:
		print("[NPC] 金币不足，无法雇佣 %s（需要 %d 金币）" % [display_name, cost])
		EventBus.dialogue_triggered.emit(display_name, ["你的金币不够，我可是要价 %d 金币的！" % cost])


func _interact_shop(_player: Player) -> void:
	GameStateManager.change_state(GameStateManager.GameState.SHOP)
	EventBus.shop_opened.emit(self)


# ─────────────────────────────────────────────
# 死亡处理（覆盖）
# ─────────────────────────────────────────────

func die(killer: BaseCharacter = null) -> void:
	# 断开全局事件监听，避免死后仍响应
	if EventBus.entity_attacked.is_connected(_on_entity_attacked_globally):
		EventBus.entity_attacked.disconnect(_on_entity_attacked_globally)
	super.die(killer)
	# 延迟移除节点
	await get_tree().create_timer(1.5).timeout
	queue_free()
