## StateMachine.gd
## 通用有限状态机（FSM）基类
## 使用方法：挂载到角色节点上，在 _ready() 中调用 init_state(初始状态节点)
##
## 状态节点需继承 BaseState，并实现：
##   enter() - 进入状态时调用一次
##   exit()  - 退出状态时调用一次
##   update(delta) - 每帧调用
##   physics_update(delta) - 每物理帧调用

extends Node
class_name StateMachine

## 当前运行的状态节点
var current_state: BaseState = null

## 所有注册的状态（字符串名 → 节点）
var states: Dictionary = {}

## 拥有此状态机的角色实体
var owner_entity: Node = null


func _ready() -> void:
	# 等一帧，让所有子节点完成 _ready()
	await owner.ready
	
	# 自动收集所有 BaseState 子节点注册进字典
	for child in get_children():
		if child is BaseState:
			states[child.name] = child
			child.state_machine = self
	
	owner_entity = owner


## 初始化状态机，进入起始状态
func init_state(initial_state: BaseState) -> void:
	current_state = initial_state
	current_state.enter()


## 切换到指定名称的状态
func transition_to(state_name: String) -> void:
	if not states.has(state_name):
		push_error("[StateMachine] 找不到状态: " + state_name + "（拥有者: " + str(owner.name) + "）")
		return
	
	if current_state:
		current_state.exit()
	
	current_state = states[state_name]
	current_state.enter()
	# print("[StateMachine] %s 切换到状态: %s" % [owner.name, state_name])


func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


## 获取当前状态名
func get_current_state_name() -> String:
	if current_state:
		return current_state.name
	return "None"
