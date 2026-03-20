## DeadState.gd
## 死亡状态 v1.0.2
## 新增：死亡击飞效果、击退衰减

extends BaseState
class_name DeadState

var _death_velocity: Vector2 = Vector2.ZERO
const DEATH_DECAY := 0.9

func enter() -> void:
	var entity = state_machine.owner_entity
	if not entity:
		return
	
	# 读取死亡击退速度
	if entity.get("_death_knockback"):
		_death_velocity = entity._death_knockback
	else:
		_death_velocity = Vector2.ZERO
	
	entity.velocity = _death_velocity
	
	# 播放死亡动画
	if entity.has_node("AnimatedSprite2D"):
		var anim: AnimatedSprite2D = entity.get_node("AnimatedSprite2D")
		if anim.sprite_frames and anim.sprite_frames.has_animation("dead"):
			anim.play("dead")
		# 变灰色
		anim.modulate = Color(0.5, 0.5, 0.5, 0.8)
	
	# 禁用碰撞
	if entity.has_node("CollisionShape2D"):
		entity.get_node("CollisionShape2D").set_deferred("disabled", true)
	
	if entity.has_node("DetectionArea/CollisionShape2D"):
		entity.get_node("DetectionArea/CollisionShape2D").set_deferred("disabled", true)


func exit() -> void:
	pass


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	var entity = state_machine.owner_entity
	if not entity:
		return
	
	# 死亡击飞衰减 (v1.0.2)
	if _death_velocity.length() > 5.0:
		entity.velocity = _death_velocity
		_death_velocity *= DEATH_DECAY
	else:
		_death_velocity = Vector2.ZERO
		entity.velocity = Vector2.ZERO
