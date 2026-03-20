## NPC.gd
## NPC 基类 v1.0.2
## 更新：减少怪物生成量、A*寻路基础、修复同盟关系

extends BaseCharacter
class_name NPC

# ─────────────────────────────────────────────
# AI 感知参数
# ─────────────────────────────────────────────
@export var detection_range: float = 160.0
@export var attack_range: float = 48.0

const ATTACK_COOLDOWN := 1.5
var _attack_timer: float = 0.0

var attack_target: BaseCharacter = null
var follow_target: BaseCharacter = null

var patrol_origin: Vector2 = Vector2.ZERO
var patrol_target: Vector2 = Vector2.ZERO
const PATROL_RADIUS := 80.0
const PATROL_WAIT_TIME := 2.5
var _patrol_wait_timer: float = 0.0

var entities_in_detection: Array = []

## 建筑限制区域（如果非空，NPC只在该区域内活动）
var confined_rect: Rect2 = Rect2()
var is_confined: bool = false


# ─────────────────────────────────────────────
# 初始化
# ─────────────────────────────────────────────

func _ready() -> void:
	super._ready()


func init_npc(char_id: String) -> void:
	setup_from_data(char_id, true)
	patrol_origin = global_position
	patrol_target = _random_patrol_point()
	
	if has_node("DetectionArea"):
		$DetectionArea.body_entered.connect(_on_detection_body_entered)
		$DetectionArea.body_exited.connect(_on_detection_body_exited)
	
	EventBus.entity_attacked.connect(_on_entity_attacked_globally)
	
	if state_machine_node:
		state_machine_node.init_state(state_machine_node.states.get("IdleState"))


## 限制NPC在某个区域内活动
func confine_to_area(rect: Rect2) -> void:
	confined_rect = rect
	is_confined = true
	patrol_origin = rect.get_center()


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
	move_and_slide()
	
	# 限制在围栏内 (v1.0.2)
	if is_confined and is_alive:
		global_position.x = clamp(global_position.x, confined_rect.position.x, confined_rect.end.x)
		global_position.y = clamp(global_position.y, confined_rect.position.y, confined_rect.end.y)


# ─────────────────────────────────────────────
# AI 决策核心
# ─────────────────────────────────────────────

func _ai_tick(_delta: float) -> void:
	if not state_machine_node:
		return
	var sm = state_machine_node
	
	if not is_alive:
		return
	
	# 1. Attack
	if attack_target and is_instance_valid(attack_target) and attack_target.is_alive:
		var dist = global_position.distance_to(attack_target.global_position)
		if dist <= attack_range:
			if sm.get_current_state_name() != "AttackState":
				sm.transition_to("AttackState")
			if _attack_timer <= 0:
				attack(attack_target)
				_attack_timer = ATTACK_COOLDOWN
		else:
			if sm.get_current_state_name() != "MoveState":
				sm.transition_to("MoveState")
			_move_toward(attack_target.global_position)
		return
	else:
		# 清除无效目标
		if attack_target and (not is_instance_valid(attack_target) or not attack_target.is_alive):
			attack_target = null
	
	# 2. Follow
	if follow_target and is_instance_valid(follow_target) and follow_target.is_alive:
		var dist = global_position.distance_to(follow_target.global_position)
		if dist > 96.0:
			if sm.get_current_state_name() != "MoveState":
				sm.transition_to("MoveState")
			_move_toward(follow_target.global_position)
		else:
			if sm.get_current_state_name() == "MoveState":
				sm.transition_to("IdleState")
		return
	
	# 3. Patrol
	_patrol_tick(_delta)


func _patrol_tick(delta: float) -> void:
	var sm = state_machine_node
	var dist = global_position.distance_to(patrol_target)
	
	if dist < 8.0:
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
	var point = patrol_origin + Vector2(cos(angle), sin(angle)) * radius
	
	# 如果限制了区域，clamp到区域内
	if is_confined:
		point.x = clamp(point.x, confined_rect.position.x + 16, confined_rect.end.x - 16)
		point.y = clamp(point.y, confined_rect.position.y + 16, confined_rect.end.y - 16)
	
	return point


# ─────────────────────────────────────────────
# 感知区域回调
# ─────────────────────────────────────────────

func _on_detection_body_entered(body: Node) -> void:
	if not body is BaseCharacter or body == self:
		return
	entities_in_detection.append(body)
	
	var rel = FactionSystem.get_relation(self, body)
	match rel:
		FactionSystem.Relation.HOSTILE:
			_set_attack_target(body)
		FactionSystem.Relation.LOYAL, FactionSystem.Relation.ALLIED:
			if body is Player:
				follow_target = body


func _on_detection_body_exited(body: Node) -> void:
	entities_in_detection.erase(body)
	if attack_target == body:
		attack_target = null
	if follow_target == body:
		follow_target = null


# ─────────────────────────────────────────────
# 全局攻击事件监听
# ─────────────────────────────────────────────

func _on_entity_attacked_globally(attacker: Node, target: Node, _damage: float) -> void:
	if not is_alive:
		return
	
	var rel_to_attacker = FactionSystem.get_relation(self, attacker)
	if rel_to_attacker == FactionSystem.Relation.LOYAL:
		if target is BaseCharacter and FactionSystem.is_friendly(self, target):
			_set_attack_target(attacker)
			return
	
	if target is BaseCharacter and FactionSystem.is_friendly(self, target as BaseCharacter):
		if attacker is BaseCharacter and FactionSystem.is_hostile(self, attacker as BaseCharacter):
			_set_attack_target(attacker)


func _set_attack_target(target: Node) -> void:
	if target is BaseCharacter and target.is_alive:
		attack_target = target
		FactionSystem.set_individual_relation(self, target, FactionSystem.Relation.HOSTILE, true)


# ─────────────────────────────────────────────
# 被攻击响应
# ─────────────────────────────────────────────

func _react_to_being_attacked(attacker: BaseCharacter) -> void:
	_set_attack_target(attacker)
	EventBus.entity_attacked.emit(attacker, self, 0)


# ─────────────────────────────────────────────
# 交互接口
# ─────────────────────────────────────────────

func interact(player: Player) -> void:
	var data = DataManager.get_character(character_id)
	var interaction_type = data.get("interaction_type", "none")
	
	match interaction_type:
		"hire":
			_interact_hire(player, data)
		"shop":
			_interact_shop(player)
		"none":
			pass


func _interact_hire(player: Player, data: Dictionary) -> void:
	var cost = data.get("hire_cost", 20)
	if GameStateManager.spend_gold(cost):
		faction = FactionSystem.Faction.ALLY
		follow_target = player
		attack_target = null
		is_confined = false  # 雇佣后解除区域限制
		FactionSystem.set_individual_relation(self, player, FactionSystem.Relation.LOYAL)
		EventBus.npc_hired.emit(self, player)
		print("[NPC] %s 被雇佣！花费 %d 金币" % [display_name, cost])
		EventBus.dialogue_triggered.emit(display_name, ["好的，我愿意为你效劳！", "（%s 加入了你的队伍）" % display_name])
	else:
		print("[NPC] 金币不足，无法雇佣 %s（需要 %d 金币）" % [display_name, cost])
		EventBus.dialogue_triggered.emit(display_name, ["你的金币不够，我可是要价 %d 金币的！" % cost])


func _interact_shop(_player: Player) -> void:
	GameStateManager.change_state(GameStateManager.GameState.SHOP)
	EventBus.shop_opened.emit(self)


# ─────────────────────────────────────────────
# 死亡处理
# ─────────────────────────────────────────────

func die(killer: BaseCharacter = null) -> void:
	if EventBus.entity_attacked.is_connected(_on_entity_attacked_globally):
		EventBus.entity_attacked.disconnect(_on_entity_attacked_globally)
	super.die(killer)
	await get_tree().create_timer(3.0).timeout
	if not is_inside_tree():
		return
	queue_free()
