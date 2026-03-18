## PlaceholderSpriteGenerator.gd
## 生成更大的像素角色精灵（16x24的人形像素小人）
## 通过 Image API 在运行时动态生成，无需外部资源

extends Node
class_name PlaceholderSpriteGenerator


## 生成角色像素小人图像（16×24），颜色可配置
## 格式：[头部颜色(皮肤), 身体颜色(衣服), 腿部颜色(裤子)]
static func generate_character_texture(body_color: Color, cloth_color: Color, pants_color: Color) -> ImageTexture:
	var img = Image.create(16, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))  # 透明底
	
	var skin = body_color
	var cloth = cloth_color
	var pants = pants_color
	var outline = Color(0.1, 0.05, 0.05, 1.0)
	var eyes = Color(0.1, 0.1, 0.8, 1.0)
	var hair = Color(0.3, 0.2, 0.1, 1.0)
	
	# === 头部 (4x5, 居中) ===
	# 头发 (row 0)
	for x in range(6, 10):
		img.set_pixel(x, 0, hair)
	# 头部 (row 1-4)
	for y in range(1, 5):
		for x in range(5, 11):
			img.set_pixel(x, y, skin)
	# 眼睛 (row 2)
	img.set_pixel(6, 2, eyes)
	img.set_pixel(9, 2, eyes)
	# 嘴巴 (row 4)
	img.set_pixel(7, 4, outline)
	img.set_pixel(8, 4, outline)
	# 头部轮廓
	img.set_pixel(5, 1, outline)
	img.set_pixel(10, 1, outline)
	img.set_pixel(5, 4, outline)
	img.set_pixel(10, 4, outline)
	
	# === 颈部 (row 5) ===
	img.set_pixel(7, 5, skin)
	img.set_pixel(8, 5, skin)
	
	# === 身体（衣服）(row 6-13, 宽6格) ===
	for y in range(6, 14):
		for x in range(5, 11):
			img.set_pixel(x, y, cloth)
	# 身体轮廓
	for y in range(6, 14):
		img.set_pixel(5, y, outline)
		img.set_pixel(10, y, outline)
	img.set_pixel(5, 13, outline)
	img.set_pixel(10, 13, outline)
	
	# === 手臂 (row 6-12) ===
	# 左臂
	for y in range(6, 13):
		img.set_pixel(3, y, skin)
		img.set_pixel(4, y, cloth)
	# 右臂
	for y in range(6, 13):
		img.set_pixel(11, y, cloth)
		img.set_pixel(12, y, skin)
	
	# === 腿部 (row 14-23, 宽3格/腿) ===
	for y in range(14, 24):
		# 左腿
		for x in range(5, 8):
			img.set_pixel(x, y, pants)
		# 右腿
		for x in range(8, 11):
			img.set_pixel(x, y, pants)
	# 腿部分隔线
	for y in range(14, 24):
		img.set_pixel(7, y, outline)
	# 鞋子（最后2行颜色加深）
	var shoe = outline
	for x in range(5, 8):
		img.set_pixel(x, 22, shoe)
		img.set_pixel(x, 23, shoe)
	for x in range(8, 11):
		img.set_pixel(x, 22, shoe)
		img.set_pixel(x, 23, shoe)
	
	var tex = ImageTexture.create_from_image(img)
	return tex


## 根据角色ID生成对应颜色的纹理
static func generate_for_character(char_id: String) -> ImageTexture:
	match char_id:
		"villager":
			# 村民：棕皮肤，灰衣服，深棕裤子
			return generate_character_texture(
				Color(0.9, 0.7, 0.5),   # 皮肤
				Color(0.5, 0.5, 0.5),   # 衣服
				Color(0.35, 0.25, 0.15) # 裤子
			)
		"merchant":
			# 商人：中等皮肤，黄色外套，深绿裤子
			return generate_character_texture(
				Color(0.85, 0.65, 0.45),
				Color(0.9, 0.75, 0.1),
				Color(0.15, 0.35, 0.15)
			)
		"priest":
			# 神父：浅皮肤，白色长袍，浅灰裤子
			return generate_character_texture(
				Color(0.95, 0.85, 0.75),
				Color(0.95, 0.95, 1.0),
				Color(0.75, 0.75, 0.85)
			)
		"goblin":
			# 哥布林：绿皮肤，褐色破衣，深绿裤子
			return generate_character_texture(
				Color(0.2, 0.7, 0.2),
				Color(0.45, 0.3, 0.1),
				Color(0.1, 0.45, 0.1)
			)
		"undead":
			# 不死者：灰白皮肤，破黑袍，深灰裤子
			return generate_character_texture(
				Color(0.75, 0.78, 0.82),
				Color(0.2, 0.2, 0.25),
				Color(0.3, 0.3, 0.35)
			)
		_:
			# 默认：普通村民外观
			return generate_character_texture(
				Color(0.8, 0.6, 0.4),
				Color(0.5, 0.5, 0.5),
				Color(0.3, 0.2, 0.1)
			)


## 生成武器图标纹理（8x8小图标）
static func generate_weapon_icon(weapon_id: String) -> ImageTexture:
	var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	match weapon_id:
		"axe":
			# 斧头：灰色柄+银色斧刃
			for y in range(2, 7):
				img.set_pixel(4, y, Color(0.6, 0.4, 0.2))  # 柄
			img.set_pixel(3, 2, Color(0.7, 0.7, 0.75))
			img.set_pixel(5, 2, Color(0.7, 0.7, 0.75))
			img.set_pixel(3, 3, Color(0.8, 0.8, 0.85))
			img.set_pixel(5, 3, Color(0.8, 0.8, 0.85))
			img.set_pixel(3, 4, Color(0.7, 0.7, 0.75))
			img.set_pixel(5, 4, Color(0.7, 0.7, 0.75))
		"cleaver":
			# 砍刀：宽刀
			for y in range(1, 7):
				img.set_pixel(3, y, Color(0.75, 0.75, 0.8))
				img.set_pixel(4, y, Color(0.85, 0.85, 0.9))
			img.set_pixel(5, 3, Color(0.6, 0.4, 0.2))
			img.set_pixel(5, 4, Color(0.6, 0.4, 0.2))
		"holy_staff":
			# 圣杖：黄色光芒
			for y in range(1, 7):
				img.set_pixel(4, y, Color(0.6, 0.5, 0.3))  # 杖
			img.set_pixel(4, 1, Color(1.0, 0.9, 0.1))  # 黄色顶部
			img.set_pixel(3, 1, Color(1.0, 0.8, 0.0))
			img.set_pixel(5, 1, Color(1.0, 0.8, 0.0))
			img.set_pixel(4, 0, Color(1.0, 1.0, 0.3))
		"dagger":
			# 匕首：细长刀
			for y in range(1, 6):
				img.set_pixel(4, y, Color(0.85, 0.85, 0.9))
			img.set_pixel(4, 6, Color(0.6, 0.4, 0.2))
		"sword":
			# 剑：长刀
			for y in range(0, 6):
				img.set_pixel(4, y, Color(0.8, 0.8, 0.85))
			img.set_pixel(3, 5, Color(0.7, 0.7, 0.75))
			img.set_pixel(5, 5, Color(0.7, 0.7, 0.75))
			img.set_pixel(4, 6, Color(0.6, 0.4, 0.2))
			img.set_pixel(4, 7, Color(0.6, 0.4, 0.2))
		_:
			# 拳头/默认
			img.set_pixel(3, 3, Color(0.9, 0.7, 0.5))
			img.set_pixel(4, 3, Color(0.9, 0.7, 0.5))
			img.set_pixel(3, 4, Color(0.9, 0.7, 0.5))
			img.set_pixel(4, 4, Color(0.9, 0.7, 0.5))
	
	return ImageTexture.create_from_image(img)


## 生成药水图标（6x8小图标）
static func generate_potion_icon(potion_type: String) -> ImageTexture:
	var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	var liquid_color = Color.RED if potion_type == "health" else Color.BLUE
	
	# 瓶颈
	img.set_pixel(3, 1, Color(0.7, 0.9, 0.7, 0.9))
	img.set_pixel(4, 1, Color(0.7, 0.9, 0.7, 0.9))
	img.set_pixel(3, 0, Color(0.6, 0.6, 0.6))
	img.set_pixel(4, 0, Color(0.6, 0.6, 0.6))
	# 瓶身
	for y in range(2, 8):
		for x in range(2, 6):
			img.set_pixel(x, y, liquid_color * 0.9 + Color(0.1, 0.1, 0.1, 0))
	# 高光
	img.set_pixel(2, 3, Color(1, 1, 1, 0.6))
	img.set_pixel(2, 4, Color(1, 1, 1, 0.4))
	
	return ImageTexture.create_from_image(img)


## 生成金币图标
static func generate_coin_icon() -> ImageTexture:
	var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	# 金色圆形
	for y in range(1, 7):
		for x in range(1, 7):
			var dx = x - 3.5
			var dy = y - 3.5
			if dx * dx + dy * dy < 10.0:
				img.set_pixel(x, y, Color(1.0, 0.85, 0.1))
	img.set_pixel(3, 2, Color(1.0, 1.0, 0.4))
	
	return ImageTexture.create_from_image(img)
