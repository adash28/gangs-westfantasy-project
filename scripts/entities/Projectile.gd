## Projectile.gd  v1.1
## 射弹：黄色像素格子，两种消失规则（时间/碰撞）

extends Area2D
class_name Projectile

const SPEED := 280.0
const LIFETIME := 3.0

var damage: float = 5.0
var shooter: BaseCharacter = null
var direction: Vector2 = Vector2.RIGHT

var _lifetime_timer: float = 0.0
var _is_active: bool = true

# 射弹精灵（黄色像素格子）
var _sprite: ColorRect = null
var _trail_points: Array = []


func _ready() -> void:
	# 创建黄色像素格子精灵
	_create_sprite()
	
	# 碰撞形状
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(6, 6)
	col.shape = shape
	add_child(col)
	
	# 设置碰撞层（射弹在layer 3）
	collision_layer = 4
	collision_mask = 3  # 检测layer 1(world) 和 layer 2(entities)
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _create_sprite() -> void:
	_sprite = ColorRect.new()
	_sprite.name = "ProjectileSprite"
	_sprite.size = Vector2(8, 8)
	_sprite.position = Vector2(-4, -4)
	_sprite.color = Color(1.0, 0.95, 0.1, 1.0)  # 明亮黄色
	add_child(_sprite)
	
	# 外发光效果（白色边框）
	var glow = ColorRect.new()
	glow.size = Vector2(10, 10)
	glow.position = Vector2(-5, -5)
	glow.color = Color(1.0, 1.0, 0.6, 0.5)
	glow.z_index = -1
	add_child(glow)


func set_direction(dir: Vector2, sh: BaseCharacter, dmg: float) -> void:
	direction = dir.normalized()
	shooter = sh
	damage = dmg
	
	# 旋转射弹朝向飞行方向
	rotation = direction.angle()


func _process(delta: float) -> void:
	if not _is_active:
		return
	
	# 移动
	global_position += direction * SPEED * delta
	
	# 生命时间
	_lifetime_timer += delta
	if _lifetime_timer >= LIFETIME:
		_despawn()
	
	# 随时间渐变（尾迹效果，逐渐变小）
	if _sprite:
		var life_pct = 1.0 - (_lifetime_timer / LIFETIME)
		_sprite.modulate.a = max(0.3, life_pct)


func _on_body_entered(body: Node) -> void:
	if not _is_active:
		return
	
	# 碰到墙壁（StaticBody2D或TileMapLayer）
	if body is TileMapLayer or body is StaticBody2D:
		_hit_wall()
		return
	
	# 碰到角色
	if body is BaseCharacter:
		if body == shooter:
			return
		if shooter and FactionSystem.is_hostile(shooter, body):
			body.take_damage(damage, shooter)
			EventBus.play_sound.emit("projectile_hit", global_position)
			_despawn()


func _on_area_entered(area: Node) -> void:
	if not _is_active:
		return
	
	if area.get_parent() is BaseCharacter:
		var target = area.get_parent() as BaseCharacter
		if target == shooter:
			return
		if shooter and FactionSystem.is_hostile(shooter, target):
			target.take_damage(damage, shooter)
			EventBus.play_sound.emit("projectile_hit", global_position)
			_despawn()


func _hit_wall() -> void:
	# 碰墙消失（带闪光效果）
	_spawn_hit_effect(Color(1.0, 1.0, 0.5, 0.8))
	_despawn()


func _despawn() -> void:
	if not _is_active:
		return
	_is_active = false
	
	# 碰撞消失特效（黄色闪光）
	_spawn_hit_effect(Color(1.0, 0.9, 0.0, 0.9))
	
	# 立刻隐藏射弹
	if _sprite:
		_sprite.visible = false
	
	queue_free()


func _spawn_hit_effect(color: Color) -> void:
	# 创建简单的黄色爆炸粒子效果
	var effect = Node2D.new()
	get_parent().add_child(effect)
	effect.global_position = global_position
	
	for i in range(5):
		var particle = ColorRect.new()
		particle.size = Vector2(4, 4)
		particle.position = Vector2(-2, -2)
		particle.color = color
		effect.add_child(particle)
		
		var tween = effect.create_tween()
		var angle = randf() * TAU
		var speed = randf_range(30, 80)
		var target_pos = Vector2(cos(angle), sin(angle)) * speed
		tween.tween_property(particle, "position", target_pos, 0.3)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.3)
	
	# 0.4秒后移除特效节点
	var cleanup_timer = get_tree().create_timer(0.4)
	cleanup_timer.timeout.connect(effect.queue_free)
