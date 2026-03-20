## MapGenerator.gd
## BSP 随机地图生成器 v1.0.2
## 更新：封闭边界、建筑系统(教堂/民宅/墓地)、实心障碍物、
##       减少怪物生成、河流、门系统、围栏

extends Node
class_name MapGenerator

# ─────────────────────────────────────────────
# 地图参数（扩大地图）
# ─────────────────────────────────────────────
@export var map_width: int  = 80
@export var map_height: int = 80

const TILE_SIZE := 32

## BSP 参数
const MIN_ROOM_SIZE := 10
const MAX_ROOM_SIZE := 22
const BSP_MAX_DEPTH := 5

# ─────────────────────────────────────────────
# Tile ID
# ─────────────────────────────────────────────
enum TileType {
	EMPTY  = -1,
	FLOOR  = 0,   # 草地/室内地板
	WALL   = 1,   # 墙壁（实心，不可通行）
	ROAD   = 2,   # 道路/走廊
	WATER  = 3,   # 水面（不可通行）
	TREE   = 4,   # 树木（实心，不可通行）
	STONE  = 5,   # 石头（实心，不可通行）
	DOOR   = 6,   # 门（可交互打开）
	FENCE  = 7,   # 围栏（墓地用，实心）
}

# 实心块集合（不可通行）
const SOLID_TILES := [TileType.WALL, TileType.TREE, TileType.STONE, TileType.WATER, TileType.FENCE]

# ─────────────────────────────────────────────
# 内部数据
# ─────────────────────────────────────────────
var _grid: Array = []
var _rooms: Array = []
var _leaf_rooms: Array = []
var tilemap: TileMapLayer = null
var npc_parent: Node2D = null
var player_spawn: Vector2i = Vector2i(5, 5)
var anchor_buildings: Array = []

## 建筑类型记录
var _church_rect: Rect2i = Rect2i()
var _graveyard_rect: Rect2i = Rect2i()
var _house_rects: Array = []  # 民宅区域列表


# ─────────────────────────────────────────────
# 公共接口
# ─────────────────────────────────────────────

func generate(seed_val: int = -1) -> Vector2:
	if seed_val >= 0:
		seed(seed_val)
	else:
		randomize()
	
	print("[MapGenerator] 开始生成地图，尺寸: %dx%d" % [map_width, map_height])
	
	_init_grid()
	_bsp_split(Rect2i(2, 2, map_width - 4, map_height - 4), 0)
	_connect_rooms()
	_place_buildings()
	_add_river()
	_fill_details()
	_enforce_boundary()
	_apply_to_tilemap()
	_spawn_npcs()
	
	print("[MapGenerator] 地图生成完成，共 %d 个房间" % _rooms.size())
	EventBus.level_loaded.emit("chapter1")
	
	return Vector2(player_spawn) * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)


# ─────────────────────────────────────────────
# Step 0：初始化网格（全部填充为墙）
# ─────────────────────────────────────────────

func _init_grid() -> void:
	_grid.clear()
	_rooms.clear()
	_leaf_rooms.clear()
	anchor_buildings.clear()
	_house_rects.clear()
	for y in range(map_height):
		var row: Array = []
		for x in range(map_width):
			row.append(TileType.WALL)
		_grid.append(row)


# ─────────────────────────────────────────────
# Step 1：BSP 递归切割
# ─────────────────────────────────────────────

func _bsp_split(rect: Rect2i, depth: int) -> void:
	if depth >= BSP_MAX_DEPTH or rect.size.x < MIN_ROOM_SIZE * 2 or rect.size.y < MIN_ROOM_SIZE * 2:
		_carve_room(rect)
		return
	
	var split_horizontal: bool
	if rect.size.x > rect.size.y * 1.25:
		split_horizontal = false
	elif rect.size.y > rect.size.x * 1.25:
		split_horizontal = true
	else:
		split_horizontal = randi() % 2 == 0
	
	if split_horizontal:
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


func _carve_room(bsp_rect: Rect2i) -> void:
	var padding = 2
	var rx = bsp_rect.position.x + padding + randi_range(0, 2)
	var ry = bsp_rect.position.y + padding + randi_range(0, 2)
	var rw = bsp_rect.size.x - padding * 2 - randi_range(0, 3)
	var rh = bsp_rect.size.y - padding * 2 - randi_range(0, 3)
	rw = max(rw, MIN_ROOM_SIZE - 2)
	rh = max(rh, MIN_ROOM_SIZE - 2)
	
	var room = Rect2i(rx, ry, rw, rh)
	_rooms.append(room)
	_leaf_rooms.append(room)
	
	for y in range(ry, ry + rh):
		for x in range(rx, rx + rw):
			_set_tile(x, y, TileType.FLOOR)


# ─────────────────────────────────────────────
# Step 2：连接房间（走廊）
# ─────────────────────────────────────────────

func _connect_rooms() -> void:
	if _leaf_rooms.size() < 2:
		return
	for i in range(_leaf_rooms.size() - 1):
		var room_a: Rect2i = _leaf_rooms[i]
		var room_b: Rect2i = _leaf_rooms[i + 1]
		var center_a = room_a.get_center()
		var center_b = room_b.get_center()
		_carve_corridor(center_a, center_b)


func _carve_corridor(from: Vector2i, to: Vector2i) -> void:
	var cx = from.x
	var cy = from.y
	
	if randi() % 2 == 0:
		while cx != to.x:
			cx += sign(to.x - cx)
			_set_tile(cx, cy, TileType.ROAD)
			_set_tile(cx, cy - 1, TileType.ROAD)
		while cy != to.y:
			cy += sign(to.y - cy)
			_set_tile(cx, cy, TileType.ROAD)
			_set_tile(cx + 1, cy, TileType.ROAD)
	else:
		while cy != to.y:
			cy += sign(to.y - cy)
			_set_tile(cx, cy, TileType.ROAD)
			_set_tile(cx + 1, cy, TileType.ROAD)
		while cx != to.x:
			cx += sign(to.x - cx)
			_set_tile(cx, cy, TileType.ROAD)
			_set_tile(cx, cy - 1, TileType.ROAD)


# ─────────────────────────────────────────────
# Step 3：放置建筑 (v1.0.2 重写)
# ─────────────────────────────────────────────

func _place_buildings() -> void:
	if _rooms.size() < 4:
		return
	
	# 第一个大房间 → 村长酒馆 + 玩家出生点
	var tavern_room = _rooms[0]
	_build_house(tavern_room, "tavern", true)
	player_spawn = Vector2i(tavern_room.position.x + tavern_room.size.x / 2 + 3, 
		tavern_room.position.y + tavern_room.size.y / 2)
	
	# 第二个房间 → 教堂
	if _rooms.size() > 1:
		var church_room = _rooms[1]
		_build_church(church_room)
	
	# 第三个房间 → 商店民宅
	if _rooms.size() > 2:
		var shop_room = _rooms[2]
		_build_house(shop_room, "shop", true)
	
	# 后续房间中选一个 → 墓地
	if _rooms.size() > 4:
		var grave_room = _rooms[_rooms.size() - 2]
		_build_graveyard(grave_room)
	
	# 其他房间 → 民宅
	for i in range(3, min(_rooms.size() - 2, 6)):
		if i != _rooms.size() - 2:  # 跳过墓地房间
			_build_house(_rooms[i], "house", true)


## 建造带墙壁和门的房屋
func _build_house(room: Rect2i, building_type: String, has_door: bool) -> void:
	var bx = room.position.x + 1
	var by = room.position.y + 1
	var bw = min(room.size.x - 2, 8)
	var bh = min(room.size.y - 2, 8)
	
	# 画墙壁
	for x in range(bx, bx + bw):
		_set_tile(x, by, TileType.WALL)
		_set_tile(x, by + bh - 1, TileType.WALL)
	for y in range(by, by + bh):
		_set_tile(bx, y, TileType.WALL)
		_set_tile(bx + bw - 1, y, TileType.WALL)
	
	# 内部地板
	for y in range(by + 1, by + bh - 1):
		for x in range(bx + 1, bx + bw - 1):
			_set_tile(x, y, TileType.FLOOR)
	
	# 门
	if has_door:
		var door_x = bx + bw / 2
		var door_y = by + bh - 1
		_set_tile(door_x, door_y, TileType.DOOR)
	
	# 内部障碍物
	if building_type == "house":
		# 床
		_set_tile(bx + 1, by + 1, TileType.STONE)
		# 柜子
		_set_tile(bx + bw - 2, by + 1, TileType.STONE)
	
	_house_rects.append(Rect2i(bx, by, bw, bh))
	
	anchor_buildings.append({
		"type": building_type,
		"rect": Rect2i(bx, by, bw, bh),
		"center": Vector2i(bx + bw / 2, by + bh / 2)
	})
	print("[MapGenerator] 建造%s at (%d,%d) %dx%d" % [building_type, bx, by, bw, bh])


## 建造教堂
func _build_church(room: Rect2i) -> void:
	var bx = room.position.x + 1
	var by = room.position.y + 1
	var bw = min(room.size.x - 2, 12)
	var bh = min(room.size.y - 2, 10)
	
	# 墙壁
	for x in range(bx, bx + bw):
		_set_tile(x, by, TileType.WALL)
		_set_tile(x, by + bh - 1, TileType.WALL)
	for y in range(by, by + bh):
		_set_tile(bx, y, TileType.WALL)
		_set_tile(bx + bw - 1, y, TileType.WALL)
	
	# 内部地板
	for y in range(by + 1, by + bh - 1):
		for x in range(bx + 1, bx + bw - 1):
			_set_tile(x, y, TileType.FLOOR)
	
	# 门（底部中间）
	_set_tile(bx + bw / 2, by + bh - 1, TileType.DOOR)
	
	# 讲台（顶部中间，实心）
	_set_tile(bx + bw / 2, by + 1, TileType.STONE)
	_set_tile(bx + bw / 2 - 1, by + 1, TileType.STONE)
	_set_tile(bx + bw / 2 + 1, by + 1, TileType.STONE)
	
	# 椅子（中间区域，实心）
	for row_offset in range(3, bh - 2):
		if row_offset % 2 == 1:
			_set_tile(bx + 2, by + row_offset, TileType.STONE)
			_set_tile(bx + bw - 3, by + row_offset, TileType.STONE)
	
	_church_rect = Rect2i(bx, by, bw, bh)
	
	anchor_buildings.append({
		"type": "church",
		"rect": Rect2i(bx, by, bw, bh),
		"center": Vector2i(bx + bw / 2, by + bh / 2)
	})
	print("[MapGenerator] 建造教堂 at (%d,%d) %dx%d" % [bx, by, bw, bh])


## 建造墓地
func _build_graveyard(room: Rect2i) -> void:
	var bx = room.position.x + 1
	var by = room.position.y + 1
	var bw = min(room.size.x - 2, 12)
	var bh = min(room.size.y - 2, 10)
	
	# 围栏（使用 FENCE）
	for x in range(bx, bx + bw):
		_set_tile(x, by, TileType.FENCE)
		_set_tile(x, by + bh - 1, TileType.FENCE)
	for y in range(by, by + bh):
		_set_tile(bx, y, TileType.FENCE)
		_set_tile(bx + bw - 1, y, TileType.FENCE)
	
	# 内部地板
	for y in range(by + 1, by + bh - 1):
		for x in range(bx + 1, bx + bw - 1):
			_set_tile(x, y, TileType.FLOOR)
	
	# 入口（围栏中间）
	_set_tile(bx + bw / 2, by + bh - 1, TileType.FLOOR)
	
	# 墓碑（障碍物，用 STONE 表示）
	for row_offset in range(2, bh - 2, 2):
		for col_offset in range(2, bw - 2, 3):
			_set_tile(bx + col_offset, by + row_offset, TileType.STONE)
	
	_graveyard_rect = Rect2i(bx, by, bw, bh)
	
	anchor_buildings.append({
		"type": "graveyard",
		"rect": Rect2i(bx, by, bw, bh),
		"center": Vector2i(bx + bw / 2, by + bh / 2)
	})
	print("[MapGenerator] 建造墓地 at (%d,%d) %dx%d" % [bx, by, bw, bh])


# ─────────────────────────────────────────────
# Step 3.5：添加河流 (v1.0.2)
# ─────────────────────────────────────────────

func _add_river() -> void:
	# 随机蜿蜒的河流
	var river_x = map_width / 2 + randi_range(-10, 10)
	var width = randi_range(2, 3)
	
	for y in range(5, map_height - 5):
		river_x += randi_range(-1, 1)
		river_x = clampi(river_x, 5, map_width - 5)
		for dx in range(-width, width + 1):
			var tx = river_x + dx
			# 不要覆盖建筑区域
			if not _is_in_any_building(tx, y):
				_set_tile(tx, y, TileType.WATER)
	
	# 在河上放桥（在走廊交叉处）
	for y in range(5, map_height - 5):
		for dx in range(-width - 1, width + 2):
			var tx = river_x + dx
			if _get_tile(tx, y) == TileType.WATER:
				# 检查上下是否有路
				if (_get_tile(tx, y - 1) == TileType.ROAD or _get_tile(tx, y + 1) == TileType.ROAD):
					_set_tile(tx, y, TileType.ROAD)


func _is_in_any_building(x: int, y: int) -> bool:
	for b in anchor_buildings:
		var rect: Rect2i = b["rect"]
		if x >= rect.position.x and x < rect.position.x + rect.size.x:
			if y >= rect.position.y and y < rect.position.y + rect.size.y:
				return true
	return false


# ─────────────────────────────────────────────
# Step 4：填充细节
# ─────────────────────────────────────────────

func _fill_details() -> void:
	for y in range(2, map_height - 2):
		for x in range(2, map_width - 2):
			if _get_tile(x, y) != TileType.WALL:
				continue
			if _is_in_any_building(x, y):
				continue
			var r = randf()
			if r < 0.50:
				_set_tile(x, y, TileType.TREE)
			elif r < 0.60:
				_set_tile(x, y, TileType.STONE)


# ─────────────────────────────────────────────
# Step 4.5：封闭边界 (v1.0.2)
# ─────────────────────────────────────────────

func _enforce_boundary() -> void:
	# 确保地图四周是不可通行的墙壁
	for x in range(map_width):
		_set_tile(x, 0, TileType.WALL)
		_set_tile(x, 1, TileType.WALL)
		_set_tile(x, map_height - 1, TileType.WALL)
		_set_tile(x, map_height - 2, TileType.WALL)
	for y in range(map_height):
		_set_tile(0, y, TileType.WALL)
		_set_tile(1, y, TileType.WALL)
		_set_tile(map_width - 1, y, TileType.WALL)
		_set_tile(map_width - 2, y, TileType.WALL)


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
					atlas_coords = Vector2i(0, 0)
				TileType.ROAD:
					atlas_coords = Vector2i(1, 0)
				TileType.WALL:
					atlas_coords = Vector2i(2, 0)
				TileType.TREE:
					atlas_coords = Vector2i(3, 0)
				TileType.STONE:
					atlas_coords = Vector2i(4, 0)
				TileType.WATER:
					atlas_coords = Vector2i(5, 0)
				TileType.DOOR:
					atlas_coords = Vector2i(6, 0)
				TileType.FENCE:
					atlas_coords = Vector2i(7, 0)
				_:
					continue
			
			tilemap.set_cell(Vector2i(x, y), 0, atlas_coords)


# ─────────────────────────────────────────────
# Step 6：生成 NPC (v1.0.2 调整)
# ─────────────────────────────────────────────

var npc_scene_path: String = "res://scenes/NPC.tscn"

func _spawn_npcs() -> void:
	if npc_parent == null:
		push_warning("[MapGenerator] npc_parent 未设置，跳过NPC生成")
		return
	
	var npc_scene = load(npc_scene_path)
	if npc_scene == null:
		push_warning("[MapGenerator] 无法加载NPC场景: " + npc_scene_path)
		return
	
	# 在第一个房间生成村民
	if _rooms.size() > 0:
		_spawn_npc_in_room(npc_scene, _rooms[0], "villager")
	
	# 在教堂生成神父（限制在教堂内）
	if _church_rect.size.x > 0:
		var priest_npc = _spawn_npc_in_rect(npc_scene, _church_rect, "priest")
		if priest_npc:
			var pixel_rect = Rect2(
				Vector2(_church_rect.position) * TILE_SIZE,
				Vector2(_church_rect.size) * TILE_SIZE
			)
			priest_npc.confine_to_area(pixel_rect)
	
	# 在商店房间生成商人
	if _rooms.size() > 2:
		_spawn_npc_in_room(npc_scene, _rooms[2], "merchant")
	
	# 在其他民宅生成村民（近房活动）
	for i in range(3, min(_rooms.size() - 2, 6)):
		if i != _rooms.size() - 2:
			_spawn_npc_in_room(npc_scene, _rooms[i], "villager")
	
	# 在墓地生成不死者 (v1.0.2)
	if _graveyard_rect.size.x > 0:
		var undead_count = randi_range(1, 2)
		for _j in range(undead_count):
			_spawn_npc_in_rect(npc_scene, _graveyard_rect, "undead")
	
	# 在空旷地带生成哥布林（减少数量 v1.0.2）
	var goblin_count = randi_range(2, 4)  # 减少至2-4个
	for _j in range(goblin_count):
		# 选择后半部分的房间
		if _rooms.size() > 3:
			var room_idx = randi_range(_rooms.size() / 2, _rooms.size() - 1)
			_spawn_npc_in_room(npc_scene, _rooms[room_idx], "goblin")


func _spawn_npc_in_room(npc_scene: PackedScene, room: Rect2i, char_id: String) -> NPC:
	return _spawn_npc_in_rect(npc_scene, room, char_id)


func _spawn_npc_in_rect(npc_scene: PackedScene, rect: Rect2i, char_id: String) -> NPC:
	var attempts = 30
	while attempts > 0:
		attempts -= 1
		var gx = randi_range(rect.position.x + 1, rect.position.x + rect.size.x - 2)
		var gy = randi_range(rect.position.y + 1, rect.position.y + rect.size.y - 2)
		if _get_tile(gx, gy) == TileType.FLOOR:
			var npc_node = npc_scene.instantiate()
			npc_parent.add_child(npc_node)
			npc_node.global_position = Vector2(gx, gy) * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
			npc_node.init_npc(char_id)
			return npc_node
	return null


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


func is_walkable(x: int, y: int) -> bool:
	var t = _get_tile(x, y)
	return t == TileType.FLOOR or t == TileType.ROAD or t == TileType.DOOR


func get_walkable_cells() -> Array:
	var result: Array = []
	for y in range(map_height):
		for x in range(map_width):
			if is_walkable(x, y):
				result.append(Vector2i(x, y))
	return result


func get_building_pixel_pos(building_type: String) -> Vector2:
	for b in anchor_buildings:
		if b["type"] == building_type:
			var c: Vector2i = b["center"]
			return Vector2(c) * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	return Vector2.ZERO


## 判断世界像素坐标是否为实心块 (v1.0.2 供碰撞检测用)
func is_solid_at_pixel(pixel_pos: Vector2) -> bool:
	var gx = int(pixel_pos.x) / TILE_SIZE
	var gy = int(pixel_pos.y) / TILE_SIZE
	var t = _get_tile(gx, gy)
	return t in SOLID_TILES
