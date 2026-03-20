## StateMachine.gd
## 通用有限状态机 v1.0.2 fixed
## 修复：移除 await owner.ready（在 _ready 中会导致状态初始化延迟）

extends Node
class_name StateMachine

var current_state: BaseState = null
var states: Dictionary = {}
var owner_entity: Node = null


func _ready() -> void:
	# 修复：不使用 await owner.ready，直接在 _ready 中初始化
	# 在 Godot 4 中，子节点的 _ready 在父节点 _ready 之前调用（底部先）
	# owner_entity 直接赋值即可
	owner_entity = owner
	
	for child in get_children():
		if child is BaseState:
			states[child.name] = child
			child.state_machine = self
	
	print("[StateMachine] 已注册状态: ", states.keys(), " (拥有者: ", owner.name if owner else "未知", ")")


func init_state(initial_state: BaseState) -> void:
	if initial_state == null:
		push_warning("[StateMachine] 初始状态为null")
		return
	current_state = initial_state
	current_state.enter()


func transition_to(state_name: String) -> void:
	if not states.has(state_name):
		push_warning("[StateMachine] 找不到状态: " + state_name + " (拥有者: " + str(owner.name if owner else "未知") + ")")
		return
	
	if current_state:
		current_state.exit()
	
	current_state = states[state_name]
	current_state.enter()


func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


func get_current_state_name() -> String:
	if current_state:
		return current_state.name
	return "None"
