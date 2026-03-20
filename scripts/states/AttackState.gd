## AttackState.gd
## v1.0.2 - 增加武器挥动视觉反馈

extends BaseState
class_name AttackState

func enter() -> void:
	var entity = state_machine.owner_entity
	if entity and entity.has_node("AnimatedSprite2D"):
		var anim: AnimatedSprite2D = entity.get_node("AnimatedSprite2D")
		if anim.sprite_frames and anim.sprite_frames.has_animation("attack"):
			anim.play("attack")
	if entity:
		entity.velocity = Vector2.ZERO

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	var entity = state_machine.owner_entity
	if entity:
		entity.velocity = Vector2.ZERO
