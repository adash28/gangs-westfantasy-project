## MoveState.gd
## 移动状态：角色根据 velocity 移动，播放 walk 动画

extends BaseState
class_name MoveState

func enter() -> void:
	var entity = state_machine.owner_entity
	if entity and entity.has_node("AnimatedSprite2D"):
		var anim: AnimatedSprite2D = entity.get_node("AnimatedSprite2D")
		if anim.sprite_frames and anim.sprite_frames.has_animation("walk"):
			anim.play("walk")


func exit() -> void:
	pass


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	# 根据面朝方向翻转 Sprite
	var entity = state_machine.owner_entity
	if not entity:
		return
	if entity.has_node("AnimatedSprite2D"):
		var anim: AnimatedSprite2D = entity.get_node("AnimatedSprite2D")
		match entity.facing_direction:
			BaseCharacter.Direction.LEFT:
				anim.flip_h = true
			BaseCharacter.Direction.RIGHT:
				anim.flip_h = false
