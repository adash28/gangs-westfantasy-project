## IdleState.gd
extends BaseState
class_name IdleState

func enter() -> void:
	if state_machine.owner_entity:
		state_machine.owner_entity.velocity = Vector2.ZERO
	var entity = state_machine.owner_entity
	if entity and entity.has_node("AnimatedSprite2D"):
		var anim: AnimatedSprite2D = entity.get_node("AnimatedSprite2D")
		if anim.sprite_frames and anim.sprite_frames.has_animation("idle"):
			anim.play("idle")

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	var entity = state_machine.owner_entity
	if entity and not entity is Player:
		entity.velocity = Vector2.ZERO
