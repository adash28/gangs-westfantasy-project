## DeadState.gd
## 死亡状态：播放死亡动画，禁用碰撞

extends BaseState
class_name DeadState

func enter() -> void:
	var entity = state_machine.owner_entity
	if not entity:
		return
	
	# 停止移动
	entity.velocity = Vector2.ZERO
	
	# 播放死亡动画
	if entity.has_node("AnimatedSprite2D"):
		var anim: AnimatedSprite2D = entity.get_node("AnimatedSprite2D")
		if anim.sprite_frames and anim.sprite_frames.has_animation("dead"):
			anim.play("dead")
	
	# 禁用碰撞（让尸体不再阻挡其他实体）
	if entity.has_node("CollisionShape2D"):
		entity.get_node("CollisionShape2D").set_deferred("disabled", true)
	
	# 禁用感知区域
	if entity.has_node("DetectionArea/CollisionShape2D"):
		entity.get_node("DetectionArea/CollisionShape2D").set_deferred("disabled", true)


func exit() -> void:
	pass  # Dead 状态不应该被退出


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	# 死亡后不移动
	var entity = state_machine.owner_entity
	if entity:
		entity.velocity = Vector2.ZERO
