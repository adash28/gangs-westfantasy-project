## Projectile.gd
## 射弹系统 v1.0.2
## 由远程武器发射，碰撞到目标造成伤害后消失，或超时消失

extends Node2D
class_name Projectile

var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var lifetime: float = 1.5
var damage: float = 5.0
var shooter: BaseCharacter = null
var _timer: float = 0.0
var _sprite: Sprite2D = null
var _hit_area: Area2D = null


func _ready() -> void:
	# 创建射弹视觉
	_sprite = Sprite2D.new()
	var img = Image.create(6, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 0.9, 0.2, 1.0))  # 黄色像素格
	_sprite.texture = ImageTexture.create_from_image(img)
	add_child(_sprite)
	
	# 创建碰撞检测区域
	_hit_area = Area2D.new()
	_hit_area.collision_layer = 0
	_hit_area.collision_mask = 7  # 检测所有物体
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	_hit_area.add_child(shape)
	add_child(_hit_area)
	
	_hit_area.body_entered.connect(_on_body_entered)
	
	z_index = 5


static func create(from_pos: Vector2, dir: Vector2, weapon_data: Dictionary, shooter_ref: BaseCharacter) -> Projectile:
	var proj = Projectile.new()
	# 注意：global_position 需要在加入场景树后才能生效
	# 使用 position 而非 global_position（因为 ProjectileContainer 位于 World 下）
	proj.position = from_pos
	proj.direction = dir.normalized()
	proj.speed = float(weapon_data.get("projectile_speed", 300))
	proj.lifetime = float(weapon_data.get("projectile_lifetime", 1.5))
	proj.damage = float(weapon_data.get("extra_damage", 3))
	proj.shooter = shooter_ref
	
	return proj


func _process(delta: float) -> void:
	_timer += delta
	
	# 移动
	global_position += direction * speed * delta
	
	# 拖尾效果（渐变透明）
	if _sprite:
		var alpha = 1.0 - (_timer / lifetime) * 0.5
		_sprite.modulate.a = alpha
	
	# 超时消失
	if _timer >= lifetime:
		_destroy()


func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return  # 不打自己
	
	if body is BaseCharacter:
		# 检查是否为敌对目标
		if shooter and FactionSystem.is_hostile(shooter, body):
			body.take_damage(damage, shooter)
			_destroy()
			return
	
	# 碰到其他实心物体也消失
	_destroy()


func _destroy() -> void:
	# 小爆炸效果
	if _sprite:
		var tween = create_tween()
		tween.tween_property(_sprite, "scale", Vector2(2, 2), 0.1)
		tween.parallel().tween_property(_sprite, "modulate:a", 0.0, 0.1)
		tween.tween_callback(queue_free)
	else:
		queue_free()
