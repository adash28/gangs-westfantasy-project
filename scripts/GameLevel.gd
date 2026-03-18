## GameLevel.gd  v1.1
## 关卡主控脚本
## 新增：InventoryUI创建、MapGenerator加入组、玩家精灵更新

extends Node2D

@onready var tilemap: TileMapLayer       = $World/TileMapLayer
@onready var npc_container: Node2D       = $World/NPCContainer
@onready var player_container: Node2D    = $World/PlayerContainer
@onready var map_generator: MapGenerator = $MapGenerator
@onready var camera: Camera2D            = $Camera2D
@onready var chapter1_manager: Node      = $Chapter1Manager
@onready var hud: Node                   = $HUD

const PLAYER_SCENE_PATH := "res://scenes/Player.tscn"
const NPC_SCENE_PATH     := "res://scenes/NPC.tscn"

var player_node: Player = null
var inventory_ui_node: InventoryUI = null
var door_controller: DoorController = null


func _ready() -> void:
	GameStateManager.change_state(GameStateManager.GameState.LOAD_LEVEL)
	
	# 注入占位 TileSet
	if tilemap.tile_set == null:
		tilemap.tile_set = _create_placeholder_tileset()
	
	# 将 MapGenerator 加入组（NPC可通过组找到它进行A*寻路）
	map_generator.add_to_group("map_generator")
	
	# 配置地图生成器
	map_generator.tilemap = tilemap
	map_generator.npc_parent = npc_container
	map_generator.npc_scene_path = NPC_SCENE_PATH
	
	# 生成地图
	var spawn_pos: Vector2 = map_generator.generate()
	
	# 创建背包UI节点（放在根节点下，持久化）
	_create_inventory_ui()
	
	# 创建门控制器
	_create_door_controller()
	
	# 生成玩家
	_spawn_player(spawn_pos)
	
	# 将门控制器绑定玩家
	if door_controller:
		door_controller.set_player(player_node)
	
	if chapter1_manager:
		chapter1_manager.player_node = player_node
		chapter1_manager.hud_node = hud
	
	GameStateManager.change_state(GameStateManager.GameState.PLAYING)
	
	print("[GameLevel] 关卡初始化完成，玩家出生于: ", spawn_pos)


func _create_door_controller() -> void:
	door_controller = DoorController.new()
	door_controller.name = "DoorController"
	add_child(door_controller)
	door_controller.setup(map_generator, tilemap)


func _create_inventory_ui() -> void:
	inventory_ui_node = InventoryUI.new()
	inventory_ui_node.name = "InventoryUI"
	inventory_ui_node.add_to_group("inventory_ui")
	add_child(inventory_ui_node)


func _spawn_player(spawn_pos: Vector2) -> void:
	var player_scene = load(PLAYER_SCENE_PATH)
	if player_scene == null:
		push_error("[GameLevel] 无法加载玩家场景: " + PLAYER_SCENE_PATH)
		return
	
	player_node = player_scene.instantiate() as Player
	player_container.add_child(player_node)
	player_node.global_position = spawn_pos
	player_node.add_to_group("player")
	
	# 摄像机跟随
	camera.reparent(player_node)
	camera.position = Vector2.ZERO
	
	# 等待 _ready() 完成后再初始化精灵
	await get_tree().process_frame
	
	# 设置玩家精灵（在 setup_from_data 后 sprite 已经更新了，这里是保险）
	if player_node.sprite:
		var tex = PlaceholderSpriteGenerator.generate_for_character(GameStateManager.selected_character_id)
		player_node.sprite.texture = tex
		player_node.sprite.scale = Vector2(2.0, 2.0)
		player_node.sprite.position = Vector2(0, -8)
	
	# 初始化 HUD
	if hud and hud.has_method("init_for_player"):
		hud.init_for_player(player_node)
	
	print("[GameLevel] 玩家生成完成: %s at %s" % [
		GameStateManager.selected_character_id, str(spawn_pos)
	])


## NPC 进入场景树时初始化精灵
func _on_npc_container_child_entered_tree(npc_node: Node) -> void:
	if not npc_node is NPC:
		return
	await get_tree().process_frame
	
	# 设置NPC精灵
	if npc_node.sprite:
		var tex = PlaceholderSpriteGenerator.generate_for_character(npc_node.character_id)
		if tex:
			npc_node.sprite.texture = tex
			npc_node.sprite.scale = Vector2(1.5, 1.5)
			npc_node.sprite.position = Vector2(0, -6)
	
	# 设置 NPC 血条
	var hp_fill = npc_node.get_node_or_null("HPBarFill") as ColorRect
	if hp_fill and not hp_fill.get_script():
		var script = load("res://scripts/ui/NPCHealthBar.gd")
		hp_fill.set_script(script)


## 创建占位 TileSet（12种类型格子，用颜色区分）
func _create_placeholder_tileset() -> TileSet:
	var ts = TileSet.new()
	ts.tile_size = Vector2i(32, 32)
	
	var source = TileSetAtlasSource.new()
	
	# 创建一个 512x64 的颜色图集（每种格子32x32）
	var tile_colors = [
		Color(0.3, 0.5, 0.2),   # 0: FLOOR（草地，绿色）
		Color(0.5, 0.4, 0.2),   # 1: ROAD（道路，棕黄）
		Color(0.25, 0.22, 0.2), # 2: WALL（墙，深灰）
		Color(0.15, 0.35, 0.1), # 3: TREE（树，深绿）
		Color(0.4, 0.38, 0.36), # 4: STONE（石头，灰）
		Color(0.1, 0.3, 0.7),   # 5: WATER（水，蓝）
		Color(0.5, 0.35, 0.2),  # 6: OBSTACLE（障碍物，棕）
		Color(0.4, 0.4, 0.4),   # 7: FENCE（围栏，灰白）
		Color(0.6, 0.35, 0.1),  # 8: DOOR（门，木色）
	]
	
	var img = Image.create(512, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	for i in range(tile_colors.size()):
		var base_color = tile_colors[i]
		var x_off = i * 32
		
		for py in range(32):
			for px in range(32):
				var variation = randf_range(-0.03, 0.03)
				var c = Color(
					clamp(base_color.r + variation, 0, 1),
					clamp(base_color.g + variation, 0, 1),
					clamp(base_color.b + variation, 0, 1)
				)
				# 边框效果
				if px == 0 or px == 31 or py == 0 or py == 31:
					c = c.darkened(0.2)
				img.set_pixel(x_off + px, py, c)
		
		# 特殊格子额外装饰
		match i:
			3:  # 树：中央深色点
				for py in range(8, 24):
					for px in range(8, 24):
						img.set_pixel(x_off + px, py, Color(0.1, 0.25, 0.05))
			7:  # 围栏：交叉图案
				for j in range(32):
					img.set_pixel(x_off + j, j, Color(0.6, 0.6, 0.6))
					img.set_pixel(x_off + j, 31 - j, Color(0.6, 0.6, 0.6))
			8:  # 门：竖条纹
				for py in range(32):
					img.set_pixel(x_off + 10, py, Color(0.4, 0.25, 0.08))
					img.set_pixel(x_off + 21, py, Color(0.4, 0.25, 0.08))
	
	var tex = ImageTexture.create_from_image(img)
	source.texture = tex
	source.texture_region_size = Vector2i(32, 32)
	
	for i in range(tile_colors.size()):
		source.create_tile(Vector2i(i, 0))
	
	ts.add_source(source, 0)
	
	# 设置碰撞（WALL, TREE, STONE, OBSTACLE, FENCE, WATER 不可通过）
	var solid_types = [2, 3, 4, 6, 7, 5]  # 对应atlas列
	for col_idx in solid_types:
		var tile_data = source.get_tile_data(Vector2i(col_idx, 0), 0)
		if tile_data:
			tile_data.set_collision_polygons_count(0, 1)
			var polygon = PackedVector2Array([
				Vector2(0, 0), Vector2(32, 0), Vector2(32, 32), Vector2(0, 32)
			])
			tile_data.set_collision_polygon_points(0, 0, polygon)
	
	return ts
