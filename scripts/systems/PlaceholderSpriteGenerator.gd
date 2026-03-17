## PlaceholderSpriteGenerator.gd
## 工具脚本：在没有美术资源时，用纯色方块作为占位精灵
## 在 GameLevel._ready() 调用前运行一次，为所有角色生成 SpriteFrames
## 
## 使用方式：在 GameLevel.gd 中 call PlaceholderSpriteGenerator.setup_all()

extends RefCounted
class_name PlaceholderSpriteGenerator

## 角色颜色配置（角色ID → Color）
const CHAR_COLORS := {
	"villager":  Color(0.6, 0.8, 0.4),   # 绿色（村民）
	"merchant":  Color(0.9, 0.7, 0.1),   # 金色（商人）
	"priest":    Color(0.9, 0.9, 0.9),   # 白色（神父）
	"goblin":    Color(0.2, 0.7, 0.2),   # 深绿（哥布林）
	"undead":    Color(0.5, 0.2, 0.5),   # 紫色（不死者）
	"player":    Color(0.2, 0.5, 0.9),   # 蓝色（玩家默认）
}

## 每帧尺寸（像素）
const FRAME_SIZE := Vector2i(16, 16)


## 为指定角色节点生成占位 SpriteFrames 并赋值
static func setup_sprite(animated_sprite: AnimatedSprite2D, char_id: String) -> void:
	if animated_sprite == null:
		return
	
	var color = CHAR_COLORS.get(char_id, Color(0.7, 0.3, 0.3))
	var frames = SpriteFrames.new()
	
	# 生成 idle 动画（1帧静止）
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 4.0)
	frames.add_frame("idle", _create_colored_texture(color, FRAME_SIZE))
	
	# 生成 walk 动画（2帧简单闪烁）
	frames.add_animation("walk")
	frames.set_animation_loop("walk", true)
	frames.set_animation_speed("walk", 8.0)
	frames.add_frame("walk", _create_colored_texture(color, FRAME_SIZE))
	frames.add_frame("walk", _create_colored_texture(color.lightened(0.3), FRAME_SIZE))
	
	# 生成 attack 动画（1帧加亮）
	frames.add_animation("attack")
	frames.set_animation_loop("attack", false)
	frames.set_animation_speed("attack", 8.0)
	frames.add_frame("attack", _create_colored_texture(color.lightened(0.5), FRAME_SIZE))
	
	# 生成 dead 动画（1帧变暗）
	frames.add_animation("dead")
	frames.set_animation_loop("dead", false)
	frames.set_animation_speed("dead", 4.0)
	frames.add_frame("dead", _create_colored_texture(color.darkened(0.7), FRAME_SIZE))
	
	animated_sprite.sprite_frames = frames
	animated_sprite.play("idle")


## 创建纯色 ImageTexture
static func _create_colored_texture(color: Color, size: Vector2i) -> ImageTexture:
	var img = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(color)
	# 画一个简单的眼睛（让方块看起来有方向感）
	var eye_color = Color.WHITE
	img.set_pixel(size.x / 2 - 2, size.y / 3, eye_color)
	img.set_pixel(size.x / 2 + 2, size.y / 3, eye_color)
	return ImageTexture.create_from_image(img)


## 生成地图 TileSet 用的占位纹理（供 TileMapLayer 使用）
static func create_placeholder_tileset() -> TileSet:
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(32, 32)
	
	var source = TileSetAtlasSource.new()
	source.texture_region_size = Vector2i(32, 32)
	
	# 创建一张 6×1 的颜色条纹图（每列对应一种 TileType）
	var tile_colors := [
		Color(0.3, 0.6, 0.2),   # 0: FLOOR  草地
		Color(0.6, 0.5, 0.3),   # 1: ROAD   路
		Color(0.3, 0.3, 0.3),   # 2: WALL   墙
		Color(0.1, 0.4, 0.1),   # 3: TREE   树
		Color(0.5, 0.45, 0.4),  # 4: STONE  石
		Color(0.1, 0.3, 0.7),   # 5: WATER  水
	]
	
	var atlas_img = Image.create(32 * tile_colors.size(), 32, false, Image.FORMAT_RGBA8)
	for i in range(tile_colors.size()):
		var rect = Rect2i(i * 32, 0, 32, 32)
		for py in range(32):
			for px in range(32):
				atlas_img.set_pixel(i * 32 + px, py, tile_colors[i])
	
	source.texture = ImageTexture.create_from_image(atlas_img)
	
	# 添加每个格子
	for i in range(tile_colors.size()):
		source.create_tile(Vector2i(i, 0))
	
	tileset.add_source(source, 0)
	return tileset
