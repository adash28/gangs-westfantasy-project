## MapGenerator.gd  v1.1
## 增强版地图生成器
## 功能：
##   1. BSP切割房间
##   2. 封闭地图边界（实心墙）
##   3. 特殊房间：教堂、民宅、墓地
##   4. 障碍物：讲台、椅子、床、柜子、墓碑、围栏
##   5. 门（可用Q键开关）
##   6. NPC归属房间（神父→教堂，不死者→墓地）
##   7. 地形：树木、石头作为实心障碍物

extends Node
class_name MapGenerator

# ─────────────────────────────────────────────
# 地图参数
# ─────────────────────────────────────────────

@export var map_width: int  = 100
@export var map_height: int = 100

const TILE_SIZE := 32

const MIN_ROOM_SIZE := 10
const MAX_ROOM_SIZE := 22
const BSP_MAX_DEPTH := 5

# ─────────────────────────────────────────────
# Tile ID
# ─────────────────────────────────────────────
enum TileType {
	EMPTY  = -1,
	FLOOR  = 0,
	WALL   = 1,
	ROAD   = 2,
	WATER  = 3,
	TREE   = 4,
	STONE  = 5,
	OBSTACLE = 6,   # 室内障碍（讲台/椅子/床/柜子/墓碑）
	FENCE  = 7,     # 围栏（墓地）
	DOOR   = 8      # 门
}

# ─────────────────────────────────────────────
# 房间类型
# ─────────────────────────────────────────────
enum RoomType {
	OPEN   = 0,
	HOUSE  = 1,
	CHURCH = 2,
	GRAVEYARD = 3
}

# ─────────────────────────────────────────────
# 内部数据
# ─────────────────────────────────────────────

var _grid: Array = []
var _rooms: Array = []          # {rect, type, door_pos, npc_spawns}
var _leaf_rooms: Array = []

var tilemap: TileMapLayer = null
var npc_parent: Node2D = null
var player_spawn: Vector2i = Vector2i(5, 5)

var anchor_buildings: Array = []

# 记录各特殊房间位置（供NPC绑定）
var church_room: Dictionary = {}
var graveyard_room: Dictionary = {}
var house_rooms: Array = []

# 门的位置列表（给Door节点用）
var door_positions: Array = []

var npc_scene_path: String = "res://scenes/NPC.tscn"


# ─────────────────────────────────────────────
# 公共接口
# ─────────────────────────────────────────────

func generate(seed_val: int = -1) -> Vector2:
	if seed_val >= 0:
		seed(seed_val)
	else:
		randomize()
	
	print("[MapGenerator] 开始生成地图 %dx%d" % [map_width, map_height])
	
	_init_grid()
	_bsp_split(Rect2i(1, 1, map_width - 2, map_height - 2), 0)
	_assign_room_types()
	_carve_all_rooms()
	_connect_rooms()
	_place_border_walls()
	_place_room_structures()
	_fill_details()
	_apply_to_tilemap()
	_spawn_npcs()
	
	print("[MapGenerator] 完成！共 %d 个房间" % _rooms.size())
	EventBus.level_loaded.emit("chapter1")
	
	return Vector2(player_spawn) * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)


# ─────────────────────────────────────────────
# Step 0：初始化
# ─────────────────────────────────────────────

func _init_grid() -> void:
	_grid.clear()
	_rooms.clear()
	_leaf_rooms.clear()
	church_room = {}
	graveyard_room = {}
	house_rooms.clear()
	door_positions.clear()
	
	for y in range(map_height):
		var row: Array = []
		for x in range(map_width):
			row.append(TileType.WALL)
		_grid.append(row)


# ─────────────────────────────────────────────
# Step 1：BSP 切割（只记录分区，不挖房间）
# ─────────────────────────────────────────────

func _bsp_split(rect: Rect2i, depth: int) -> void:
	if depth >= BSP_MAX_DEPTH or rect.size.x < MIN_ROOM_SIZE * 2 or rect.size.y < MIN_ROOM_SIZE * 2:
		_leaf_rooms.append(rect)
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
			_leaf_rooms.append(rect)
			return
		var split_y = randi_range(min_y, max_y)
		_bsp_split(Rect2i(rect.position.x, rect.position.y, rect.size.x, split_y - rect.position.y), depth + 1)
		_bsp_split(Rect2i(rect.position.x, split_y, rect.size.x, rect.position.y + rect.size.y - split_y), depth + 1)
	else:
		var min_x = rect.position.x + MIN_ROOM_SIZE
		var max_x = rect.position.x + rect.size.x - MIN_ROOM_SIZE
		if min_x >= max_x:
			_leaf_rooms.append(rect)
			return
		var split_x = randi_range(min_x, max_x)
		_bsp_split(Rect2i(rect.position.x, rect.position.y, split_x - rect.position.x, rect.size.y), depth + 1)
		_bsp_split(Rect2i(split_x, rect.position.y, rect.position.x + rect.size.x - split_x, rect.size.y), depth + 1)


# ─────────────────────────────────────────────
# Step 2：分配房间类型
# ─────────────────────────────────────────────

func _assign_room_types() -> void:
	var total = _leaf_rooms.size()
	var church_idx = -1
	var graveyard_idx = -1
	
	# 找最大房间给教堂
	var max_area = 0
	for i in range(total):
		var r: Rect2i = _leaf_rooms[i]
		var area = r.size.x * r.size.y
		if area > max_area:
			max_area = area
			church_idx = i
	
	# 找最远（通常是另一角）给墓地
	if total > 2:
		var church_rect: Rect2i = _leaf_rooms[church_idx]
		var church_center = church_rect.get_center()
		var max_dist = 0.0
		for i in range(total):
			if i == church_idx:
				continue
			var r: Rect2i = _leaf_rooms[i]
			var dist = church_center.distance_to(r.get_center())
			if dist > max_dist:
				max_dist = dist
				graveyard_idx = i
	
	# 构建房间信息
	for i in range(total):
		var bsp_rect: Rect2i = _leaf_rooms[i]
		var padding = 1
		var rx = bsp_rect.position.x + padding + randi_range(0, 1)
		var ry = bsp_rect.position.y + padding + randi_range(0, 1)
		var rw = max(bsp_rect.size.x - padding * 2 - randi_range(0, 2), MIN_ROOM_SIZE - 2)
		var rh = max(bsp_rect.size.y - padding * 2 - randi_range(0, 2), MIN_ROOM_SIZE - 2)
		
		var room_rect = Rect2i(rx, ry, rw, rh)
		var room_type: int
		
		if i == church_idx:
			room_type = RoomType.CHURCH
		elif i == graveyard_idx:
			room_type = RoomType.GRAVEYARD
		elif randf() < 0.4 and total > 4:
			room_type = RoomType.HOUSE
		else:
			room_type = RoomType.OPEN
		
		var room_info = {
			"rect": room_rect,
			"type": room_type,
			"door_pos": Vector2i.ZERO,
			"npc_spawns": []
		}
		_rooms.append(room_info)
		
		if room_type == RoomType.CHURCH:
			church_room = room_info
		elif room_type == RoomType.GRAVEYARD:
			graveyard_room = room_info
		elif room_type == RoomType.HOUSE:
			house_rooms.append(room_info)


# ─────────────────────────────────────────────
# Step 3：挖空所有房间地板
# ─────────────────────────────────────────────

func _carve_all_rooms() -> void:
	for room_info in _rooms:
		var r: Rect2i = room_info["rect"]
		
		# 先挖室内地板（不包括墙边框）
		for y in range(r.position.y + 1, r.position.y + r.size.y - 1):
			for x in range(r.position.x + 1, r.position.x + r.size.x - 1):
				_set_tile(x, y, TileType.FLOOR)
		
		# 墙边框保持 WALL（在 _init_grid 时已经全部是 WALL）
		# 但需要确保边框格子是 WALL
		for x in range(r.position.x, r.position.x + r.size.x):
			_set_tile(x, r.position.y, TileType.WALL)
			_set_tile(x, r.position.y + r.size.y - 1, TileType.WALL)
		for y in range(r.position.y, r.position.y + r.size.y):
			_set_tile(r.position.x, y, TileType.WALL)
			_set_tile(r.position.x + r.size.x - 1, y, TileType.WALL)
		
		# 设置玩家出生点（第一个开放房间或教堂旁）
		if room_info["type"] == RoomType.OPEN and player_spawn == Vector2i(5, 5):
			player_spawn = r.get_center()


# ─────────────────────────────────────────────
# Step 4：连廊（打开房间墙壁并连接）
# ─────────────────────────────────────────────

func _connect_rooms() -> void:
	if _rooms.size() < 2:
		return
	
	for i in range(_rooms.size() - 1):
		var room_a: Rect2i = _rooms[i]["rect"]
		var room_b: Rect2i = _rooms[i + 1]["rect"]
		var center_a = room_a.get_center()
		var center_b = room_b.get_center()
		_carve_corridor(center_a, center_b)


func _carve_corridor(from: Vector2i, to: Vector2i) -> void:
	var cx = from.x
	var cy = from.y
	
	if randi() % 2 == 0:
		while cx != to.x:
			cx += sign(to.x - cx)
			if _get_tile(cx, cy) == TileType.WALL:
				_set_tile(cx, cy, TileType.ROAD)
			if _get_tile(cx, cy - 1) == TileType.WALL:
				_set_tile(cx, cy - 1, TileType.ROAD)
		while cy != to.y:
			cy += sign(to.y - cy)
			if _get_tile(cx, cy) == TileType.WALL:
				_set_tile(cx, cy, TileType.ROAD)
			if _get_tile(cx + 1, cy) == TileType.WALL:
				_set_tile(cx + 1, cy, TileType.ROAD)
	else:
		while cy != to.y:
			cy += sign(to.y - cy)
			if _get_tile(cx, cy) == TileType.WALL:
				_set_tile(cx, cy, TileType.ROAD)
			if _get_tile(cx + 1, cy) == TileType.WALL:
				_set_tile(cx + 1, cy, TileType.ROAD)
		while cx != to.x:
			cx += sign(to.x - cx)
			if _get_tile(cx, cy) == TileType.WALL:
				_set_tile(cx, cy, TileType.ROAD)
			if _get_tile(cx, cy - 1) == TileType.WALL:
				_set_tile(cx, cy - 1, TileType.ROAD)


# ─────────────────────────────────────────────
# Step 5：封闭地图边界
# ─────────────────────────────────────────────

func _place_border_walls() -> void:
	# 四条边设为 WALL（实心，不可进入）
	for x in range(map_width):
		_set_tile(x, 0, TileType.WALL)
		_set_tile(x, map_height - 1, TileType.WALL)
	for y in range(map_height):
		_set_tile(0, y, TileType.WALL)
		_set_tile(map_width - 1, y, TileType.WALL)


# ─────────────────────────────────────────────
# Step 6：放置房间内部结构（障碍物、门）
# ─────────────────────────────────────────────

func _place_room_structures() -> void:
	for room_info in _rooms:
		var r: Rect2i = room_info["rect"]
		var rtype: int = room_info["type"]
		
		match rtype:
			RoomType.CHURCH:
				_setup_church(room_info)
			RoomType.GRAVEYARD:
				_setup_graveyard(room_info)
			RoomType.HOUSE:
				_setup_house(room_info)
		
		# 为有围墙的房间添加门（教堂、民宅）
		if rtype == RoomType.CHURCH or rtype == RoomType.HOUSE:
			_add_door(room_info)


func _setup_church(room_info: Dictionary) -> void:
	var r: Rect2i = room_info["rect"]
	var cx = r.get_center().x
	var cy = r.get_center().y
	
	# 讲台（房间上方中央，2格宽1格高）
	_set_tile(cx - 1, r.position.y + 2, TileType.OBSTACLE)
	_set_tile(cx,     r.position.y + 2, TileType.OBSTACLE)
	_set_tile(cx + 1, r.position.y + 2, TileType.OBSTACLE)
	
	# 椅子（两列，各3把）
	var chair_y_start = r.position.y + 4
	for row in range(3):
		var gy = chair_y_start + row * 2
		if gy < r.position.y + r.size.y - 2:
			_set_tile(cx - 3, gy, TileType.OBSTACLE)
			_set_tile(cx + 3, gy, TileType.OBSTACLE)
	
	print("[MapGenerator] 教堂结构放置完成")


func _setup_graveyard(room_info: Dictionary) -> void:
	var r: Rect2i = room_info["rect"]
	
	# 内部围栏（距离外墙2格的内边框）
	for x in range(r.position.x + 2, r.position.x + r.size.x - 2):
		_set_tile(x, r.position.y + 2, TileType.FENCE)
		_set_tile(x, r.position.y + r.size.y - 3, TileType.FENCE)
	for y in range(r.position.y + 2, r.position.y + r.size.y - 2):
		_set_tile(r.position.x + 2, y, TileType.FENCE)
		_set_tile(r.position.x + r.size.x - 3, y, TileType.FENCE)
	
	# 围栏入口（南侧中央）
	var gate_x = r.get_center().x
	_set_tile(gate_x, r.position.y + r.size.y - 3, TileType.ROAD)
	_set_tile(gate_x - 1, r.position.y + r.size.y - 3, TileType.ROAD)
	
	# 墓碑（内部随机分布）
	for i in range(6):
		var attempts = 15
		while attempts > 0:
			attempts -= 1
			var tx = randi_range(r.position.x + 3, r.position.x + r.size.x - 4)
			var ty = randi_range(r.position.y + 3, r.position.y + r.size.y - 4)
			if _get_tile(tx, ty) == TileType.FLOOR:
				_set_tile(tx, ty, TileType.OBSTACLE)
				break
	
	print("[MapGenerator] 墓地结构放置完成")


func _setup_house(room_info: Dictionary) -> void:
	var r: Rect2i = room_info["rect"]
	
	# 床（右下角）
	var bed_x = r.position.x + r.size.x - 3
	var bed_y = r.position.y + r.size.y - 3
	if _get_tile(bed_x, bed_y) == TileType.FLOOR:
		_set_tile(bed_x, bed_y, TileType.OBSTACLE)
		_set_tile(bed_x - 1, bed_y, TileType.OBSTACLE)
	
	# 柜子（左下角）
	var cab_x = r.position.x + 2
	var cab_y = r.position.y + r.size.y - 3
	if _get_tile(cab_x, cab_y) == TileType.FLOOR:
		_set_tile(cab_x, cab_y, TileType.OBSTACLE)


func _add_door(room_info: Dictionary) -> void:
	var r: Rect2i = room_info["rect"]
	
	# 在南墙中央设置门
	var door_x = r.get_center().x
	var door_y = r.position.y + r.size.y - 1
	
	# 确保门位置在地图范围内且是墙壁
	if door_x >= 1 and door_x < map_width - 1 and door_y >= 1 and door_y < map_height - 1:
		_set_tile(door_x, door_y, TileType.DOOR)
		room_info["door_pos"] = Vector2i(door_x, door_y)
		door_positions.append(Vector2i(door_x, door_y))
		print("[MapGenerator] 门放置于 (%d,%d)" % [door_x, door_y])


# ─────────────────────────────────────────────
# Step 7：填充细节（树/石头）
# ─────────────────────────────────────────────

func _fill_details() -> void:
	for y in range(1, map_height - 1):
		for x in range(1, map_width - 1):
			if _get_tile(x, y) != TileType.WALL:
				continue
			var r = randf()
			if r < 0.45:
				_set_tile(x, y, TileType.TREE)
			elif r < 0.55:
				_set_tile(x, y, TileType.STONE)
			# else 保持 WALL


# ─────────────────────────────────────────────
# Step 8：写入 TileMapLayer
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
				TileType.OBSTACLE:
					atlas_coords = Vector2i(6, 0)
				TileType.FENCE:
					atlas_coords = Vector2i(7, 0)
				TileType.DOOR:
					atlas_coords = Vector2i(8, 0)
				_:
					continue
			
			tilemap.set_cell(Vector2i(x, y), 0, atlas_coords)


# ─────────────────────────────────────────────
# Step 9：生成 NPC
# ─────────────────────────────────────────────

func _spawn_npcs() -> void:
	if npc_parent == null:
		push_warning("[MapGenerator] npc_parent 未设置")
		return
	
	var npc_scene = load(npc_scene_path)
	if npc_scene == null:
		push_warning("[MapGenerator] 无法加载NPC场景")
		return
	
	# 1. 神父 → 教堂
	if not church_room.is_empty():
		var ch_rect: Rect2i = church_room["rect"]
		_spawn_npc_in_room_typed(npc_scene, ch_rect, "priest", true)
	
	# 2. 不死者 → 墓地（2~3只）
	if not graveyard_room.is_empty():
		var gv_rect: Rect2i = graveyard_room["rect"]
		var undead_count = randi_range(2, 3)
		for _i in range(undead_count):
			_spawn_npc_in_room_typed(npc_scene, gv_rect, "undead", false)
	
	# 3. 村民/商人 → 民宅房间
	var merchant_placed = false
	for house in house_rooms:
		var h_rect: Rect2i = house["rect"]
		if not merchant_placed:
			_spawn_npc_in_room_typed(npc_scene, h_rect, "merchant", true)
			merchant_placed = true
		else:
			_spawn_npc_in_room_typed(npc_scene, h_rect, "villager", true)
	
	# 如果没有民宅，在开放房间放村民/商人
	if house_rooms.is_empty():
		var open_rooms = _rooms.filter(func(r): return r["type"] == RoomType.OPEN)
		if open_rooms.size() >= 1:
			_spawn_npc_in_room_typed(npc_scene, open_rooms[0]["rect"], "villager", true)
		if open_rooms.size() >= 2:
			_spawn_npc_in_room_typed(npc_scene, open_rooms[1]["rect"], "merchant", true)
	
	# 4. 哥布林 → 开放地带（少量）
	var open_rooms = _rooms.filter(func(r): return r["type"] == RoomType.OPEN)
	var goblin_count = 0
	var max_goblins = min(3, open_rooms.size())
	for room in open_rooms:
		if goblin_count >= max_goblins:
			break
		if randf() < 0.5:
			_spawn_npc_in_room_typed(npc_scene, room["rect"], "goblin", false)
			goblin_count += 1


func _spawn_npc_in_room_typed(npc_scene: PackedScene, room_rect: Rect2i, char_id: String, is_friendly: bool) -> void:
	var attempts = 30
	while attempts > 0:
		attempts -= 1
		var gx = randi_range(room_rect.position.x + 2, room_rect.position.x + room_rect.size.x - 3)
		var gy = randi_range(room_rect.position.y + 2, room_rect.position.y + room_rect.size.y - 3)
		if _get_tile(gx, gy) == TileType.FLOOR:
			var npc_node = npc_scene.instantiate()
			npc_parent.add_child(npc_node)
			npc_node.global_position = Vector2(gx, gy) * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
			
			# 设置NPC所在房间信息（用于巡逻边界）
			if npc_node.has_method("init_npc_with_room"):
				npc_node.init_npc_with_room(char_id, room_rect)
			else:
				npc_node.init_npc(char_id)
			
			print("[MapGenerator] 生成 %s 于 (%d,%d)" % [char_id, gx, gy])
			return


# ─────────────────────────────────────────────
# 工具方法
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
	return t == TileType.FLOOR or t == TileType.ROAD


func is_solid(x: int, y: int) -> bool:
	var t = _get_tile(x, y)
	return t == TileType.WALL or t == TileType.TREE or t == TileType.STONE or t == TileType.OBSTACLE or t == TileType.FENCE or t == TileType.WATER


func get_walkable_cells() -> Array:
	var result: Array = []
	for y in range(map_height):
		for x in range(map_width):
			if is_walkable(x, y):
				result.append(Vector2i(x, y))
	return result


## A* 寻路（简化版，供NPC使用）
func find_path(from_tile: Vector2i, to_tile: Vector2i) -> Array:
	# 简单BFS（小地图用），返回格坐标路径
	if from_tile == to_tile:
		return [from_tile]
	
	var open_set = [from_tile]
	var came_from: Dictionary = {}
	var visited: Dictionary = {}
	visited[from_tile] = true
	
	var max_iterations = 500
	var iter = 0
	
	while open_set.size() > 0 and iter < max_iterations:
		iter += 1
		var current = open_set.pop_front()
		
		if current == to_tile:
			# 重建路径
			var path = [current]
			while came_from.has(current):
				current = came_from[current]
				path.push_front(current)
			return path
		
		var neighbors = [
			Vector2i(current.x + 1, current.y),
			Vector2i(current.x - 1, current.y),
			Vector2i(current.x, current.y + 1),
			Vector2i(current.x, current.y - 1)
		]
		
		for n in neighbors:
			if visited.has(n):
				continue
			if is_solid(n.x, n.y):
				continue
			visited[n] = true
			came_from[n] = current
			open_set.append(n)
	
	return []  # 无路径


func get_building_pixel_pos(building_type: String) -> Vector2:
	for b in anchor_buildings:
		if b["type"] == building_type:
			var c: Vector2i = b["center"]
			return Vector2(c) * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	return Vector2.ZERO


## 获取世界像素坐标对应的格坐标
func world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / TILE_SIZE), int(world_pos.y / TILE_SIZE))


## 格坐标转世界像素坐标（格中心）
func tile_to_world(tile_pos: Vector2i) -> Vector2:
	return Vector2(tile_pos) * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
