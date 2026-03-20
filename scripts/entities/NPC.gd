## NPC.gd  v1.1
## NPC基类：A*寻路、房间限制巡逻、神父留在教堂

extends BaseCharacter
class_name NPC

# ─────────────────────────────────────────────
# AI 参数
# ─────────────────────────────────────────────

@export var detection_range: float = 160.0
@export var attack_range: float = 48.0

const ATTACK_COOLDOWN := 1.5
var _attack_timer: float = 0.0

var attack_target: BaseCharacter = null
var follow_target: BaseCharacter = null

## 巡逻
var patrol_origin: Vector2 = Vector2.ZERO
var patrol_target: Vector2 = Vector2.ZERO
const PATROL_RADIUS := 80.0
const PATROL_WAIT_TIME := 2.5
var _patrol_wait_timer: float = 0.0

## 绑定房间（神父绑定教堂，不死者绑定墓地等）
var bound_room: Rect2i = Rect2i()
var is_room_bound: bool = false  # 是否被限制在房间内

var entities_in_detection: Array = []

## A*路径（格坐标列表）
var _current_path: Array = []
var _path_update_timer: float = 0.0
const PATH_UPDATE_INTERVAL := 0.5  # 每0.5秒重新寻路

## MapGenerator引用（用于A*寻路）
var _map_gen: MapGenerator = null


# ─────────────────────────────────────────────
# 初始化
# ─────────────────────────────────────────────

func _ready() -> void:
	pass


## 标准初始化
func init_npc(char_id: String) -> void:
	setup_from_data(char_id, true)
	patrol_origin = global_position
	patrol_target = _random_patrol_point()
	_connect_signals()


## 带房间绑定的初始化（由MapGenerator调用）
func init_npc_with_room(char_id: String, room_rect: Rect2i) -> void:
	setup_from_data(char_id, true)
	patrol_origin = global_position
	bound_room = room_rect
	
	# 神父和友好NPC被限制在房间内巡逻
	var data = DataManager.get_character(char_id)
	var faction_str = data.get("faction", "NEUTRAL")
	if faction_str == "HUMAN" and char_id == "priest":
		is_room_bound = true
		patrol_target = _random_room_patrol_point()
	else:
		patrol_target = _random_patrol_point()
	
	_connect_signals()


func _connect_signals() -> void:
	if has_node("DetectionArea"):
		$DetectionArea.body_entered.connect(_on_detection_body_entered)
		$DetectionArea.body_exited.connect(_on_detection_body_exited)
	
	EventBus.entity_attacked.connect(_on_entity_attacked_globally)
	
	if state_machine_node:
		state_machine_node.init_state(state_machine_node.states.get("IdleState"))
	
	# 找地图生成器
	await get_tree().process_frame
	var map_gens = get_tree().get_nodes_in_group("map_generator")
	if map_gens.size() > 0:
		_map_gen = map_gens[0] as MapGenerator


# ─────────────────────────────────────────────
# 每帧更新
# ─────────────────────────────────────────────

func _process(delta: float) -> void:
	super._process(delta)
	if not is_alive:
		return
	if _attack_timer > 0:
		_attack_timer -= delta
	_path_update_timer += delta
	_ai_tick(delta)


func _physics_process(_delta: float) -> void:
	if not is_alive:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	move_and_slide()


# ─────────────────────────────────────────────
# AI 决策
# ─────────────────────────────────────────────

func _ai_tick(_delta: float) -> void:
	if not state_machine_node or not is_alive:
		return
	var sm = state_machine_node
	
	# 1. 攻击目标
	if attack_target and attack_target.is_alive:
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
			_move_toward_with_pathfinding(attack_target.global_position)
		return
	
	# 2. 跟随目标
	if follow_target and follow_target.is_alive:
		var dist = global_position.distance_to(follow_target.global_position)
		if dist > 96.0:
			if sm.get_current_state_name() != "MoveState":
				sm.transition_to("MoveState")
			_move_toward_with_pathfinding(follow_target.global_position)
		else:
			if sm.get_current_state_name() == "MoveState":
				sm.transition_to("IdleState")
		return
	
	# 3. 巡逻
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
			patrol_target = _pick_next_patrol_point()
	else:
		if sm.get_current_state_name() != "MoveState":
			sm.transition_to("MoveState")
		_move_toward_simple(patrol_target)


func _pick_next_patrol_point() -> Vector2:
	if is_room_bound and bound_room.size.x > 0:
		return _random_room_patrol_point()
	return _random_patrol_point()


## A* 辅助移动（有地图时用寻路，没有时直接移动）
func _move_toward_with_pathfinding(target_pos: Vector2) -> void:
	if _map_gen == null or _path_update_timer < PATH_UPDATE_INTERVAL:
		_move_toward_simple(target_pos)
		return
	
	_path_update_timer = 0.0
	
	var from_tile = _map_gen.world_to_tile(global_position)
	var to_tile = _map_gen.world_to_tile(target_pos)
	
	_current_path = _map_gen.find_path(from_tile, to_tile)
	
	if _current_path.size() > 1:
		# 跟随路径第二个节点（第一个是当前位置）
		var next_tile: Vector2i = _current_path[1]
		var next_world = _map_gen.tile_to_world(next_tile)
		_move_toward_simple(next_world)
	else:
		_move_toward_simple(target_pos)


func _move_toward_simple(target_pos: Vector2) -> void:
	var dir = (target_pos - global_position).normalized()
	velocity = dir * get_pixel_speed()
	update_facing(dir)


func _random_patrol_point() -> Vector2:
	var angle = randf() * TAU
	var radius = randf() * PATROL_RADIUS
	return patrol_origin + Vector2(cos(angle), sin(angle)) * radius


func _random_room_patrol_point() -> Vector2:
	if bound_room.size.x == 0:
		return _random_patrol_point()
	
	# 在房间内部（去掉边框）随机一点
	var rx = float(bound_room.position.x + 2) * 32 + randf() * float((bound_room.size.x - 4)) * 32
	var ry = float(bound_room.position.y + 2) * 32 + randf() * float((bound_room.size.y - 4)) * 32
	return Vector2(rx, ry)


# ─────────────────────────────────────────────
# 感知
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
			# 使用组检测代替直接类型检测，避免循环依赖
			if body.is_in_group("player"):
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


func _react_to_being_attacked(attacker: BaseCharacter) -> void:
	_set_attack_target(attacker)
	EventBus.entity_attacked.emit(attacker, self, 0)


# ─────────────────────────────────────────────
# 交互
# ─────────────────────────────────────────────

func interact(player) -> void:
	var data = DataManager.get_character(character_id)
	var interaction_type = data.get("interaction_type", "none")
	
	match interaction_type:
		"hire":
			_interact_hire(player, data)
		"shop":
			_interact_shop(player)


func _interact_hire(player, data: Dictionary) -> void:
	var cost = data.get("hire_cost", 20)
	if GameStateManager.spend_gold(cost):
		faction = FactionSystem.Faction.ALLY
		follow_target = player
		attack_target = null
		is_room_bound = false  # 雇佣后可离开房间
		FactionSystem.set_individual_relation(self, player, FactionSystem.Relation.LOYAL)
		EventBus.npc_hired.emit(self, player)
		EventBus.dialogue_triggered.emit(display_name, ["好的，我愿意为你效劳！", "（%s 加入了你的队伍）" % display_name])
	else:
		EventBus.dialogue_triggered.emit(display_name, ["你的金币不够，我可是要价 %d 金币的！" % cost])


func _interact_shop(_player) -> void:
	GameStateManager.change_state(GameStateManager.GameState.SHOP)
	EventBus.shop_opened.emit(self)


# ─────────────────────────────────────────────
# 死亡
# ─────────────────────────────────────────────

func die(killer: BaseCharacter = null) -> void:
	if EventBus.entity_attacked.is_connected(_on_entity_attacked_globally):
		EventBus.entity_attacked.disconnect(_on_entity_attacked_globally)
	super.die(killer)
	await get_tree().create_timer(1.5).timeout
	queue_free()
