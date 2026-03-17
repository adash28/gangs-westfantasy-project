## BaseState.gd
## 状态机中所有状态的基类
## 具体状态（IdleState, MoveState等）需继承此类

extends Node
class_name BaseState

## 反向引用到所在的状态机
var state_machine: StateMachine = null


## 进入此状态时调用（Override 这个方法）
func enter() -> void:
	pass


## 退出此状态时调用（Override 这个方法）
func exit() -> void:
	pass


## 每帧逻辑更新（Override 这个方法处理非物理逻辑）
func update(_delta: float) -> void:
	pass


## 每物理帧更新（Override 这个方法处理移动、碰撞等）
func physics_update(_delta: float) -> void:
	pass
