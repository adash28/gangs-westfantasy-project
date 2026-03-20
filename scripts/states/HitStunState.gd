## HitStunState.gd
## 受击僵直状态：角色被攻击后短暂僵直，变红，被击退
## v1.0.2 新增

extends BaseState
class_name HitStunState

## 僵直持续时间（秒）
const HIT_STUN_DURATION := 0.3
## 击退衰减系数
const KNOCKBACK_DECAY := 0.85

var _stun_timer: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO


func enter() -> void:
	var entity = state_machine.owner_entity
	if not entity:
		return
	
	_stun_timer = 0.0
	
	# 从 meta 中读取击退速度（由 BaseCharacter.take_damage 设置）
	if entity.has_meta("knockback_velocity"):
		_knockback_velocity = entity.get_meta("knockback_velocity")
	else:
		_knockback_velocity = Vector2.ZERO
	
	# 变红效果
	if entity.has_node("AnimatedSprite2D"):
		var anim: AnimatedSprite2D = entity.get_node("AnimatedSprite2D")
		anim.modulate = Color(1.0, 0.3, 0.3, 1.0)
	
	# 播放受击动画（如果有）
	if entity.has_node("AnimatedSprite2D"):
		var anim: AnimatedSprite2D = entity.get_node("AnimatedSprite2D")
		if anim.sprite_frames and anim.sprite_frames.has_animation("hit"):
			anim.play("hit")


func exit() -> void:
	var entity = state_machine.owner_entity
	if not entity:
		return
	
	# 恢复颜色
	if entity.has_node("AnimatedSprite2D"):
		var anim: AnimatedSprite2D = entity.get_node("AnimatedSprite2D")
		anim.modulate = Color.WHITE
	
	# 清除击退
	_knockback_velocity = Vector2.ZERO
	entity.velocity = Vector2.ZERO
	
	# 清除 meta
	if entity.has_meta("knockback_velocity"):
		entity.remove_meta("knockback_velocity")


func update(delta: float) -> void:
	_stun_timer += delta
	if _stun_timer >= HIT_STUN_DURATION:
		# 僵直结束，恢复到 Idle 状态
		state_machine.transition_to("IdleState")


func physics_update(_delta: float) -> void:
	var entity = state_machine.owner_entity
	if not entity:
		return
	
	# 应用击退速度并衰减
	entity.velocity = _knockback_velocity
	_knockback_velocity *= KNOCKBACK_DECAY
	
	# 速度太小就停止
	if _knockback_velocity.length() < 5.0:
		_knockback_velocity = Vector2.ZERO
		entity.velocity = Vector2.ZERO
