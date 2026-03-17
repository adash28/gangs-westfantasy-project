## AttackState.gd
## 攻击状态：播放 attack 动画，攻击由 NPC._ai_tick() 实际触发
## 此状态主要用于动画控制和攻击动作的视觉反馈

extends BaseState
class_name AttackState

func enter() -> void:
	var entity = state_machine.owner_entity
	if entity and entity.has_node("AnimatedSprite2D"):
		var anim: AnimatedSprite2D = entity.get_node("AnimatedSprite2D")
		if anim.sprite_frames and anim.sprite_frames.has_animation("attack"):
			anim.play("attack")
	# 攻击时停止移动
	if entity:
		entity.velocity = Vector2.ZERO


func exit() -> void:
	pass


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	# 攻击时原地静止
	var entity = state_machine.owner_entity
	if entity:
		entity.velocity = Vector2.ZERO
