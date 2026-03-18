## DoorController.gd
## 门控制：Q键交互开/关门
## 挂载在 GameLevel 节点，监控玩家与门的距离

extends Node
class_name DoorController

const DOOR_INTERACT_RANGE := 40.0  # 互动范围（像素）
const TILE_SIZE := 32

var _map_gen: MapGenerator = null
var _tilemap: TileMapLayer = null
var _player: Player = null

## 门状态（格坐标 → 是否开启）
var _door_states: Dictionary = {}

## 已打开的门的视觉节点
var _door_visuals: Dictionary = {}


func setup(map_gen: MapGenerator, tilemap: TileMapLayer) -> void:
	_map_gen = map_gen
	_tilemap = tilemap
	
	# 记录所有门的初始状态（关闭）
	for door_pos in map_gen.door_positions:
		_door_states[door_pos] = false  # false = 关闭


func set_player(player: Player) -> void:
	_player = player


func _process(_delta: float) -> void:
	if not _player or not _player.is_alive:
		return
	
	if Input.is_action_just_pressed("open_door"):
		_try_toggle_nearest_door()


func _try_toggle_nearest_door() -> void:
	var player_pos = _player.global_position
	var player_tile = Vector2i(int(player_pos.x / TILE_SIZE), int(player_pos.y / TILE_SIZE))
	
	# 搜索附近的门
	for door_tile in _door_states.keys():
		var door_world = Vector2(door_tile) * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
		var dist = player_pos.distance_to(door_world)
		
		if dist <= DOOR_INTERACT_RANGE:
			_toggle_door(door_tile)
			return


func _toggle_door(door_tile: Vector2i) -> void:
	var is_open: bool = _door_states.get(door_tile, false)
	is_open = not is_open
	_door_states[door_tile] = is_open
	
	if _tilemap:
		if is_open:
			# 打开门：将门格子改为ROAD（可通行）
			_tilemap.set_cell(door_tile, 0, Vector2i(1, 0))
			print("[DoorController] 门打开 at ", door_tile)
		else:
			# 关闭门：恢复为DOOR格子
			_tilemap.set_cell(door_tile, 0, Vector2i(8, 0))
			print("[DoorController] 门关闭 at ", door_tile)
