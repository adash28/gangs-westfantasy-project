## MapGenerator.gd
## BSP（二叉空间分割）随机地图生成器
## 生成流程：
##   1. BSP 切割地图为若干房间
##   2. 在房间中放置固定预制建筑（酒馆/商店等锚点）
##   3. 用走廊连接相邻房间
##   4. 填充地形细节（树木/石头）
##   5. 生成 NPC 实体

extends Node
class_name MapGenerator

# ─────────────────────────────────────────────
# 地图参数
# ─────────────────────────────────────────────

## 地图网格尺寸（单位：格）
@export var map_width: int  = 60
@export var map_height: int = 60

## 单格像素大小
const TILE_SIZE := 32

## BSP 最小房间尺寸（格）
const MIN_ROOM_SIZE := 8
const MAX_ROOM_SIZE := 18

## 每个房间最大分割次数（递归深度）
const BSP_MAX_DEPTH := 5

# ─────────────────────────────────────────────
# Tile ID 定义（对应 TileSet 中的 source_id）
# ─────────────────────────────────────────────
enum TileType {
	EMPTY  = -1,  # 空（地图外）
	FLOOR  = 0,   # 草地/室内地板
	WALL   = 1,   # 墙壁/树木边界
	ROAD   = 2,   # 道路/走廊
	WATER  = 3,   # 水面（不可通行）
	TREE   = 4,   # 树木装饰
	STONE  = 5    # 石头装饰
}

# ─────────────────────────────────────────────
# 内部数据结构
# ─────────────────────────────────────────────

## 网格数组：存储每格的 TileType
var _grid: Array = []

## 所有生成的房间（Rect2i 列表）
var _rooms: Array = []

## BSP 叶子节点房间（用于连廊）
var _leaf_rooms: Array = []

## TileMapLayer 节点引用（由外部赋值）
var tilemap: TileMapLayer = null

## NPC 生成父节点（由外部赋值）
var npc_parent: Node2D = null

## 玩家出生点（格坐标）
var player_spawn: Vector2i = Vector2i(5, 5)

## 预设锚点建筑（type → rect 格坐标）
var anchor_buildings: Array = []


# ─────────────────────────────────────────────
# 公共接口
# ─────────────────────────────────────────────

## 主生成入口，返回玩家出生点（像素坐标）
func generate(seed_val: int = -1) -> Vector2:
	if seed_val >= 0:
		seed(seed_val)
	else:
		randomize()
	
	print("[MapGenerator] 开始生成地图，尺寸: %dx%d" % [map_width, map_height])
	
	_init_grid()
	_bsp_split(Rect2i(1, 1, map_width - 2, map_height - 2), 0)
	_connect_rooms()
	_place_anchor_buildings()
	_fill_details()
	_apply_to_tilemap()
	_spawn_npcs()
	
	print("[MapGenerator] 地图生成完成，共 %d 个房间" % _rooms.size())
	EventBus.level_loaded.emit("chapter1")
	
	# 返回像素坐标
	return Vector2(player_spawn) * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)


# ─────────────────────────────────────────────
# Step 0：初始化网格
# ─────────────────────────────────────────────

func _init_grid() -> void:
	_grid.clear()
	_rooms.clear()
	_leaf_rooms.clear()
	for y in range(map_height):
		var row: Array = []
		for x in range(map_width):
			row.append(TileType.WALL)
		_grid.append(row)


# ─────────────────────────────────────────────
# Step 1：BSP 递归切割
# ─────────────────────────────────────────────

func _bsp_split(rect: Rect2i, depth: int) -> void:
	# 终止条件：超过最大深度 或 房间已足够小
	if depth >= BSP_MAX_DEPTH or rect.size.x < MIN_ROOM_SIZE * 2 or rect.size.y < MIN_ROOM_SIZE * 2:
		_carve_room(rect)
		return
	
	# 决定切割方向（优先切割较长的边，加一点随机性）
	var split_horizontal: bool
	if rect.size.x > rect.size.y * 1.25:
		split_horizontal = false
	elif rect.size.y > rect.size.x * 1.25:
		split_horizontal = true
	else:
		split_horizontal = randi() % 2 == 0
	
	if split_horizontal:
		# 水平切割（切 y 轴）
		var min_y = rect.position.y + MIN_ROOM_SIZE
		var max_y = rect.position.y + rect.size.y - MIN_ROOM_SIZE
		if min_y >= max_y:
			_carve_room(rect)
			return
		var split_y = randi_range(min_y, max_y)
		var rect_a = Rect2i(rect.position.x, rect.position.y, rect.size.x, split_y - rect.position.y)
		var rect_b = Rect2i(rect.position.x, split_y, rect.size.x, rect.position.y + rect.size.y - split_y)
		_bsp_split(rect_a, depth + 1)
		_bsp_split(rect_b, depth + 1)
	else:
		# 垂直切割（切 x 轴）
		var min_x = rect.position.x + MIN_ROOM_SIZE
		var max_x = rect.position.x + rect.size.x - MIN_ROOM_SIZE
		if min_x >= max_x:
			_carve_room(rect)
			return
		var split_x = randi_range(min_x, max_x)
		var rect_a = Rect2i(rect.position.x, rect.position.y, split_x - rect.position.x, rect.size.y)
		var rect_b = Rect2i(split_x, rect.position.y, rect.position.x + rect.size.x - split_x, rect.size.y)
		_bsp_split(rect_a, depth + 1)
		_bsp_split(rect_b, depth + 1)


## 在 BSP 叶节点处挖出房间（加一些内边距让房间比 BSP 分区略小）
func _carve_room(bsp_rect: Rect2i) -> void:
	var padding = 1
	var rx = bsp_rect.position.x + padding + randi_range(0, 2)
	var ry = bsp_rect.position.y + padding + randi_range(0, 2)
	var rw = bsp_rect.size.x - padding * 2 - randi_range(0, 3)
	var rh = bsp_rect.size.y - padding * 2 - randi_range(0, 3)
	rw = max(rw, MIN_ROOM_SIZE - 2)
	rh = max(rh, MIN_ROOM_SIZE - 2)
	
	var room = Rect2i(rx, ry, rw, rh)
	_rooms.append(room)
	_leaf_rooms.append(room)
	
	# 挖空格子
	for y in range(ry, ry + rh):
		for x in range(rx, rx + rw):
			_set_tile(x, y, TileType.FLOOR)


# ─────────────────────────────────────────────
# Step 2：连接房间（走廊）
# ─────────────────────────────────────────────

func _connect_rooms() -> void:
	if _leaf_rooms.size() < 2:
		return
	# 简单策略：按顺序连接相邻房间中心，确保连通
	for i in range(_leaf_rooms.size() - 1):
		var room_a: Rect2i = _leaf_rooms[i]
		var room_b: Rect2i = _leaf_rooms[i + 1]
		var center_a = room_a.get_center()
		var center_b = room_b.get_center()
		_carve_corridor(center_a, center_b)


## L 形走廊：先横向后纵向（或随机选顺序）
func _carve_corridor(from: Vector2i, to: Vector2i) -> void:
	var cx = from.x
	var cy = from.y
	
	# 随机决定先横还是先纵
	if randi() % 2 == 0:
		# 先横向
		while cx != to.x:
			cx += sign(to.x - cx)
			_set_tile(cx, cy, TileType.ROAD)
			_set_tile(cx, cy - 1, TileType.ROAD)  # 走廊宽度2格
		# 再纵向
		while cy != to.y:
			cy += sign(to.y - cy)
			_set_tile(cx, cy, TileType.ROAD)
			_set_tile(cx + 1, cy, TileType.ROAD)
	else:
		# 先纵向
		while cy != to.y:
			cy += sign(to.y - cy)
			_set_tile(cx, cy, TileType.ROAD)
			_set_tile(cx + 1, cy, TileType.ROAD)
		# 再横向
		while cx != to.x:
			cx += sign(to.x - cx)
			_set_tile(cx, cy, TileType.ROAD)
			_set_tile(cx, cy - 1, TileType.ROAD)


# ─────────────────────────────────────────────
# Step 3：放置锚点建筑（酒馆/商店）
# ─────────────────────────────────────────────

func _place_anchor_buildings() -> void:
	anchor_buildings.clear()
	
	if _rooms.size() == 0:
		return
	
	# 选第一个足够大的房间放酒馆（3x3），设为玩家出生点附近
	var tavern_placed = false
	for room in _rooms:
		if room.size.x >= 6 and room.size.y >= 6 and not tavern_placed:
			var bx = room.position.x + 1
			var by = room.position.y + 1
			_mark_building(bx, by, 4, 4, "tavern")
			# 村长房屋旁边设定为第一章触发点
			player_spawn = Vector2i(bx + 5, by + 2)
			tavern_placed = true
	
	# 选另一个房间放商店
	if _rooms.size() >= 3:
		var shop_room: Rect2i = _rooms[_rooms.size() / 2]
		if shop_room.size.x >= 5 and shop_room.size.y >= 5:
			var bx = shop_room.position.x + 1
			var by = shop_room.position.y + 1
			_mark_building(bx, by, 3, 3, "shop")


## 标记建筑区域为 FLOOR，并记录元数据
func _mark_building(x: int, y: int, w: int, h: int, building_type: String) -> void:
	for gy in range(y, y + h):
		for gx in range(x, x + w):
			_set_tile(gx, gy, TileType.FLOOR)
	anchor_buildings.append({
		"type": building_type,
		"rect": Rect2i(x, y, w, h),
		"center": Vector2i(x + w / 2, y + h / 2)
	})
	print("[MapGenerator] 放置建筑: %s at (%d,%d)" % [building_type, x, y])


# ─────────────────────────────────────────────
# Step 4：填充细节（树/石头）
# ─────────────────────────────────────────────

func _fill_details() -> void:
	for y in range(1, map_height - 1):
		for x in range(1, map_width - 1):
			if _get_tile(x, y) != TileType.WALL:
				continue
			# WALL 格子随机变成树或石头（视觉装饰）
			var r = randf()
			if r < 0.55:
				_set_tile(x, y, TileType.TREE)
			elif r < 0.65:
				_set_tile(x, y, TileType.STONE)
			# else 保持 WALL（实心墙）


# ─────────────────────────────────────────────
# Step 5：写入 TileMapLayer
# ─────────────────────────────────────────────

func _apply_to_tilemap() -> void:
	if tilemap == null:
		push_warning("[MapGenerator] tilemap 未设置，跳过渲染")
		return
	
	tilemap.clear()
	
	for y in range(map_height):
		for x in range(map_width):
			var tile_type = _get_tile(x, y)
			var atlas_coords: Vector2i
			
			match tile_type:
				TileType.FLOOR:
					atlas_coords = Vector2i(0, 0)   # TileSet 中草地格子坐标
				TileType.ROAD:
					atlas_coords = Vector2i(1, 0)   # 道路格子
				TileType.WALL:
					atlas_coords = Vector2i(2, 0)   # 墙壁
				TileType.TREE:
					atlas_coords = Vector2i(3, 0)   # 树木
				TileType.STONE:
					atlas_coords = Vector2i(4, 0)   # 石头
				TileType.WATER:
					atlas_coords = Vector2i(5, 0)   # 水面
				_:
					continue
			
			# source_id=0 对应第一个 TileSet source
			tilemap.set_cell(Vector2i(x, y), 0, atlas_coords)


# ─────────────────────────────────────────────
# Step 6：生成 NPC 实体
# ─────────────────────────────────────────────

## NPC 预制体场景路径（由具体场景设置）
var npc_scene_path: String = "res://scenes/NPC.tscn"

func _spawn_npcs() -> void:
	if npc_parent == null:
		push_warning("[MapGenerator] npc_parent 未设置，跳过NPC生成")
		return
	
	var npc_scene = load(npc_scene_path)
	if npc_scene == null:
		push_warning("[MapGenerator] 无法加载NPC场景: " + npc_scene_path)
		return
	
	# 在各房间生成 NPC
	for i in range(_rooms.size()):
		var room: Rect2i = _rooms[i]
		
		# 前两个房间生成友好NPC（人类）
		if i < 2:
			_spawn_npc_in_room(npc_scene, room, "villager")
			if i == 1:
				_spawn_npc_in_room(npc_scene, room, "merchant")
		# 后续房间生成怪物
		elif i >= 2:
			var monster_count = randi_range(1, 3)
			for _j in range(monster_count):
				var monster_type = "goblin" if randf() > 0.4 else "undead"
				_spawn_npc_in_room(npc_scene, room, monster_type)
	
	# 在第一个房间额外生成神父
	if _rooms.size() > 0:
		_spawn_npc_in_room(npc_scene, _rooms[0], "priest")


func _spawn_npc_in_room(npc_scene: PackedScene, room: Rect2i, char_id: String) -> void:
	# 在房间内随机选一个 FLOOR 格子
	var attempts = 20
	while attempts > 0:
		attempts -= 1
		var gx = randi_range(room.position.x + 1, room.position.x + room.size.x - 2)
		var gy = randi_range(room.position.y + 1, room.position.y + room.size.y - 2)
		if _get_tile(gx, gy) == TileType.FLOOR:
			var npc_node = npc_scene.instantiate()
			npc_parent.add_child(npc_node)
			npc_node.global_position = Vector2(gx, gy) * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
			npc_node.init_npc(char_id)
			return


# ─────────────────────────────────────────────
# 网格工具方法
# ─────────────────────────────────────────────

func _set_tile(x: int, y: int, tile_type: int) -> void:
	if x < 0 or x >= map_width or y < 0 or y >= map_height:
		return
	_grid[y][x] = tile_type


func _get_tile(x: int, y: int) -> int:
	if x < 0 or x >= map_width or y < 0 or y >= map_height:
		return TileType.WALL
	return _grid[y][x]


## 判断某格子是否可行走（非 WALL/TREE/STONE/WATER）
func is_walkable(x: int, y: int) -> bool:
	var t = _get_tile(x, y)
	return t == TileType.FLOOR or t == TileType.ROAD


## 获取所有可行走格子（供 A* 寻路使用）
func get_walkable_cells() -> Array:
	var result: Array = []
	for y in range(map_height):
		for x in range(map_width):
			if is_walkable(x, y):
				result.append(Vector2i(x, y))
	return result


## 获取某类型建筑的中心像素坐标
func get_building_pixel_pos(building_type: String) -> Vector2:
	for b in anchor_buildings:
		if b["type"] == building_type:
			var c: Vector2i = b["center"]
			return Vector2(c) * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	return Vector2.ZERO
