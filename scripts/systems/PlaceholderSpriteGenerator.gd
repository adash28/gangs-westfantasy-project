## PlaceholderSpriteGenerator.gd
## v1.0.2 - 使用 Kenney Roguelike Characters 精灵图
## 从 spritesheet 切割 16x16 角色帧，生成 SpriteFrames
## 回退机制：如果 spritesheet 加载失败，使用增强的纯色像素小人

extends RefCounted
class_name PlaceholderSpriteGenerator

## Kenney spritesheet 路径
const SPRITESHEET_PATH := "res://assets/sprites/roguelikeChar_transparent.png"

## 每帧尺寸（Kenney roguelike chars = 16x16, margin=1）
const FRAME_W := 16
const FRAME_H := 16
const MARGIN := 1

## 角色 → spritesheet 上的位置映射
## 每个角色定义多个帧：[idle_col, walk_col1, walk_col2, attack_col]
## row = 角色行号
const CHAR_SPRITE_MAP := {
	"villager":  { "row": 0, "idle": [0], "walk": [0, 1], "attack": [2], "dead": [3] },
	"merchant":  { "row": 1, "idle": [0], "walk": [0, 1], "attack": [2], "dead": [3] },
	"priest":    { "row": 2, "idle": [0], "walk": [0, 1], "attack": [2], "dead": [3] },
	"goblin":    { "row": 5, "idle": [0], "walk": [0, 1], "attack": [2], "dead": [3] },
	"undead":    { "row": 7, "idle": [0], "walk": [0, 1], "attack": [2], "dead": [3] },
}

## 回退颜色（用于无 spritesheet 时）
const CHAR_COLORS := {
	"villager":  Color(0.55, 0.75, 0.35),
	"merchant":  Color(0.9, 0.7, 0.1),
	"priest":    Color(0.9, 0.9, 0.9),
	"goblin":    Color(0.2, 0.65, 0.2),
	"undead":    Color(0.5, 0.2, 0.5),
	"player":    Color(0.2, 0.5, 0.9),
}

## 缓存的 spritesheet 图像
static var _spritesheet_img: Image = null
static var _spritesheet_loaded: bool = false
static var _spritesheet_tried: bool = false


## 尝试加载 spritesheet
static func _ensure_spritesheet() -> void:
	if _spritesheet_tried:
		return
	_spritesheet_tried = true
	
	if not FileAccess.file_exists(SPRITESHEET_PATH):
		print("[SpriteGen] Spritesheet 未找到: %s，使用像素小人回退" % SPRITESHEET_PATH)
		return
	
	var tex = load(SPRITESHEET_PATH) as Texture2D
	if tex == null:
		print("[SpriteGen] 无法加载 spritesheet，使用像素小人回退")
		return
	
	_spritesheet_img = tex.get_image()
	if _spritesheet_img == null:
		print("[SpriteGen] 无法获取 spritesheet 图像数据")
		return
	
	# 确保格式正确
	if _spritesheet_img.get_format() != Image.FORMAT_RGBA8:
		_spritesheet_img.convert(Image.FORMAT_RGBA8)
	
	_spritesheet_loaded = true
	print("[SpriteGen] Kenney spritesheet 加载成功: %dx%d" % [_spritesheet_img.get_width(), _spritesheet_img.get_height()])


## 从 spritesheet 切割一帧
static func _cut_frame(row: int, col: int) -> ImageTexture:
	if not _spritesheet_loaded or _spritesheet_img == null:
		return null
	
	var x = col * (FRAME_W + MARGIN)
	var y = row * (FRAME_H + MARGIN)
	
	if x + FRAME_W > _spritesheet_img.get_width() or y + FRAME_H > _spritesheet_img.get_height():
		return null
	
	var frame_img = _spritesheet_img.get_region(Rect2i(x, y, FRAME_W, FRAME_H))
	return ImageTexture.create_from_image(frame_img)


## 为指定角色节点生成 SpriteFrames
static func setup_sprite(animated_sprite: AnimatedSprite2D, char_id: String) -> void:
	if animated_sprite == null:
		return
	
	_ensure_spritesheet()
	
	var frames = SpriteFrames.new()
	
	if _spritesheet_loaded and CHAR_SPRITE_MAP.has(char_id):
		_setup_from_spritesheet(frames, char_id)
	else:
		_setup_from_pixels(frames, char_id)
	
	animated_sprite.sprite_frames = frames
	animated_sprite.play("idle")


## 从 Kenney spritesheet 生成帧
static func _setup_from_spritesheet(frames: SpriteFrames, char_id: String) -> void:
	var map = CHAR_SPRITE_MAP[char_id]
	var row = map["row"]
	
	# idle 动画
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 4.0)
	for col in map["idle"]:
		var tex = _cut_frame(row, col)
		if tex:
			frames.add_frame("idle", tex)
		else:
			frames.add_frame("idle", _create_colored_texture(CHAR_COLORS.get(char_id, Color.WHITE), Vector2i(FRAME_W, FRAME_H)))
	
	# walk 动画
	frames.add_animation("walk")
	frames.set_animation_loop("walk", true)
	frames.set_animation_speed("walk", 8.0)
	for col in map["walk"]:
		var tex = _cut_frame(row, col)
		if tex:
			frames.add_frame("walk", tex)
		else:
			frames.add_frame("walk", _create_colored_texture(CHAR_COLORS.get(char_id, Color.WHITE), Vector2i(FRAME_W, FRAME_H)))
	
	# attack 动画
	frames.add_animation("attack")
	frames.set_animation_loop("attack", false)
	frames.set_animation_speed("attack", 8.0)
	for col in map["attack"]:
		var tex = _cut_frame(row, col)
		if tex:
			frames.add_frame("attack", tex)
		else:
			frames.add_frame("attack", _create_colored_texture(CHAR_COLORS.get(char_id, Color.WHITE).lightened(0.5), Vector2i(FRAME_W, FRAME_H)))
	
	# dead 动画
	frames.add_animation("dead")
	frames.set_animation_loop("dead", false)
	frames.set_animation_speed("dead", 4.0)
	for col in map["dead"]:
		var tex = _cut_frame(row, col)
		if tex:
			frames.add_frame("dead", tex)
		else:
			frames.add_frame("dead", _create_colored_texture(CHAR_COLORS.get(char_id, Color.GRAY).darkened(0.5), Vector2i(FRAME_W, FRAME_H)))
	
	# hit 动画（使用 idle 帧 + 着红色，由 HitStunState 控制 modulate）
	frames.add_animation("hit")
	frames.set_animation_loop("hit", false)
	frames.set_animation_speed("hit", 4.0)
	var idle_col = map["idle"][0]
	var tex = _cut_frame(row, idle_col)
	if tex:
		frames.add_frame("hit", tex)
	else:
		frames.add_frame("hit", _create_colored_texture(Color(1.0, 0.3, 0.3), Vector2i(FRAME_W, FRAME_H)))


## 像素小人回退（增强版 - 更像人形）
static func _setup_from_pixels(frames: SpriteFrames, char_id: String) -> void:
	var color = CHAR_COLORS.get(char_id, Color(0.7, 0.3, 0.3))
	var size = Vector2i(16, 20)  # 长方形，更像人
	
	# idle 动画
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 4.0)
	frames.add_frame("idle", _create_humanoid_texture(color, size, 0))
	
	# walk 动画
	frames.add_animation("walk")
	frames.set_animation_loop("walk", true)
	frames.set_animation_speed("walk", 8.0)
	frames.add_frame("walk", _create_humanoid_texture(color, size, 1))
	frames.add_frame("walk", _create_humanoid_texture(color, size, 2))
	
	# attack 动画
	frames.add_animation("attack")
	frames.set_animation_loop("attack", false)
	frames.set_animation_speed("attack", 8.0)
	frames.add_frame("attack", _create_humanoid_texture(color.lightened(0.5), size, 3))
	
	# dead 动画
	frames.add_animation("dead")
	frames.set_animation_loop("dead", false)
	frames.set_animation_speed("dead", 4.0)
	frames.add_frame("dead", _create_humanoid_texture(color.darkened(0.7), size, 4))
	
	# hit 动画
	frames.add_animation("hit")
	frames.set_animation_loop("hit", false)
	frames.set_animation_speed("hit", 4.0)
	frames.add_frame("hit", _create_humanoid_texture(color, size, 0))


## 创建人形像素贴图
static func _create_humanoid_texture(color: Color, size: Vector2i, pose: int) -> ImageTexture:
	var img = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var skin = Color(0.9, 0.75, 0.6)
	var hair = color.darkened(0.3)
	
	# 头部 (行 0-5)
	for y in range(0, 6):
		for x in range(5, 11):
			img.set_pixel(x, y, skin)
	# 头发
	for x in range(5, 11):
		img.set_pixel(x, 0, hair)
	for x in range(5, 7):
		img.set_pixel(x, 1, hair)
	
	# 眼睛
	img.set_pixel(6, 3, Color.BLACK)
	img.set_pixel(9, 3, Color.BLACK)
	
	# 身体 (行 6-13)
	for y in range(6, 14):
		for x in range(4, 12):
			img.set_pixel(x, y, color)
	
	# 腿部 (行 14-19)
	var leg_offset = 0
	if pose == 1:
		leg_offset = 1
	elif pose == 2:
		leg_offset = -1
	
	for y in range(14, 20):
		# 左腿
		for x in range(5 + (leg_offset if y > 16 else 0), 8 + (leg_offset if y > 16 else 0)):
			if x >= 0 and x < size.x:
				img.set_pixel(x, y, color.darkened(0.2))
		# 右腿
		for x in range(8 + (-leg_offset if y > 16 else 0), 11 + (-leg_offset if y > 16 else 0)):
			if x >= 0 and x < size.x:
				img.set_pixel(x, y, color.darkened(0.2))
	
	# 攻击姿态：伸出手臂
	if pose == 3:
		for x in range(12, 16):
			if x < size.x:
				img.set_pixel(x, 8, skin)
				img.set_pixel(x, 9, skin)
	
	# 死亡姿态：变暗
	if pose == 4:
		# 躺倒效果（横向拉伸）
		img = img.duplicate()
	
	return ImageTexture.create_from_image(img)


## 创建纯色 ImageTexture（回退用）
static func _create_colored_texture(color: Color, size: Vector2i) -> ImageTexture:
	var img = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var eye_color = Color.WHITE
	img.set_pixel(size.x / 2 - 2, size.y / 3, eye_color)
	img.set_pixel(size.x / 2 + 2, size.y / 3, eye_color)
	return ImageTexture.create_from_image(img)


## 生成地图 TileSet（增强版，更好的视觉效果）
static func create_placeholder_tileset() -> TileSet:
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(32, 32)
	
	var source = TileSetAtlasSource.new()
	source.texture_region_size = Vector2i(32, 32)
	
	var tile_colors := [
		Color(0.35, 0.58, 0.25),  # 0: FLOOR  草地
		Color(0.62, 0.52, 0.35),  # 1: ROAD   路
		Color(0.35, 0.35, 0.38),  # 2: WALL   墙
		Color(0.15, 0.42, 0.12),  # 3: TREE   树
		Color(0.52, 0.48, 0.42),  # 4: STONE  石
		Color(0.15, 0.35, 0.65),  # 5: WATER  水
		Color(0.55, 0.35, 0.2),   # 6: DOOR   门
		Color(0.25, 0.25, 0.28),  # 7: FENCE  围栏
	]
	
	var total_tiles = tile_colors.size()
	var atlas_img = Image.create(32 * total_tiles, 32, false, Image.FORMAT_RGBA8)
	
	for i in range(total_tiles):
		var base_color = tile_colors[i]
		for py in range(32):
			for px in range(32):
				# 添加一些纹理变化
				var noise_val = randf() * 0.08 - 0.04
				var c = Color(
					clamp(base_color.r + noise_val, 0, 1),
					clamp(base_color.g + noise_val, 0, 1),
					clamp(base_color.b + noise_val, 0, 1),
					1.0
				)
				# 树木特殊处理：画树冠
				if i == 3:
					if py < 20 and px > 6 and px < 26:
						c = Color(0.12, 0.45 + randf() * 0.1, 0.1)
					elif py >= 20 and px > 12 and px < 20:
						c = Color(0.4, 0.28, 0.15)
					else:
						c = tile_colors[0]  # 草地背景
				# 石头：画圆形
				if i == 4:
					var cx = px - 16
					var cy = py - 16
					if cx * cx + cy * cy > 144:
						c = tile_colors[0]
				# 水面：波浪效果
				if i == 5:
					if (px + py) % 8 < 2:
						c = c.lightened(0.15)
				
				atlas_img.set_pixel(i * 32 + px, py, c)
	
	source.texture = ImageTexture.create_from_image(atlas_img)
	
	for i in range(total_tiles):
		source.create_tile(Vector2i(i, 0))
	
	tileset.add_source(source, 0)
	
	# 添加物理层用于碰撞 (v1.0.2)
	tileset.add_physics_layer()
	
	return tileset
