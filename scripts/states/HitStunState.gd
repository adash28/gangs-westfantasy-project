## HitStunState.gd  v1.1
## 受击僵直状态：变红、击退、碰撞弹回

extends BaseState
class_name HitStunState

const HIT_STUN_DURATION := 0.3
const KNOCKBACK_DECAY := 0.88

var _stun_timer: float = 0.0
var _knockback_direction: Vector2 = Vector2.ZERO
var _knockback_speed: float = 0.0


func enter() -> void:
	var entity = state_machine.owner_entity
	if not entity:
		return
	
	_stun_timer = HIT_STUN_DURATION
	
	if entity.has_meta("hit_knockback_direction") and entity.has_meta("hit_knockback_speed"):
		_knockback_direction = entity.get_meta("hit_knockback_direction")
		_knockback_speed = entity.get_meta("hit_knockback_speed")
		entity.remove_meta("hit_knockback_direction")
		entity.remove_meta("hit_knockback_speed")
	else:
		_knockback_direction = Vector2.ZERO
		_knockback_speed = 0.0
	
	# 变红效果
	if entity.has_node("Sprite2D"):
		entity.get_node("Sprite2D").modulate = Color(1, 0.4, 0.4, 1)
	
	EventBus.play_sound.emit("hit", entity.global_position)


func exit() -> void:
	var entity = state_machine.owner_entity
	if not entity:
		return
	
	# 恢复正常颜色
	if entity.has_node("Sprite2D"):
		entity.get_node("Sprite2D").modulate = Color(1, 1, 1, 1)
	
	_knockback_direction = Vector2.ZERO
	_knockback_speed = 0.0
	
	if entity.has_method("clear_knockback"):
		entity.clear_knockback()


func update(delta: float) -> void:
	_stun_timer -= delta
	if _stun_timer <= 0:
		state_machine.transition_to("IdleState")


func physics_update(_delta: float) -> void:
	var entity = state_machine.owner_entity
	if not entity:
		return
	
	if _knockback_speed > 8.0:
		entity.velocity = _knockback_direction * _knockback_speed
		_knockback_speed *= KNOCKBACK_DECAY
		
		# 移动后检查碰撞弹回
		if entity.has_method("apply_bounce_on_collision"):
			entity.apply_bounce_on_collision()
			# 获取弹回后的速度
			if entity._knockback_velocity.length() > 8.0:
				_knockback_direction = entity._knockback_velocity.normalized()
				_knockback_speed = entity._knockback_velocity.length()
	else:
		entity.velocity = Vector2.ZERO
