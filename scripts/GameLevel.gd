## GameLevel.gd
## GameLevel 场景的主控脚本 v1.0.2 fixed
## 修复：NPC名称显示时序问题（等待init_npc完成）、射弹管理

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

## 射弹容器 (v1.0.2)
var _projectile_container: Node2D = null


func _ready() -> void:
	GameStateManager.change_state(GameStateManager.GameState.LOAD_LEVEL)
	
	# 创建射弹容器 (v1.0.2)
	_projectile_container = Node2D.new()
	_projectile_container.name = "ProjectileContainer"
	$World.add_child(_projectile_container)
	
	# 监听射弹事件 (v1.0.2)
	EventBus.projectile_fired.connect(_on_projectile_fired)
	
	if tilemap.tile_set == null:
		tilemap.tile_set = PlaceholderSpriteGenerator.create_placeholder_tileset()
	
	map_generator.tilemap = tilemap
	map_generator.npc_parent = npc_container
	map_generator.npc_scene_path = NPC_SCENE_PATH
	
	var spawn_pos: Vector2 = map_generator.generate()
	
	_spawn_player(spawn_pos)
	
	if chapter1_manager:
		chapter1_manager.player_node = player_node
		chapter1_manager.hud_node = hud
	
	GameStateManager.change_state(GameStateManager.GameState.PLAYING)
	
	print("[GameLevel] 关卡初始化完成，玩家出生于: ", spawn_pos)


func _spawn_player(spawn_pos: Vector2) -> void:
	var player_scene = load(PLAYER_SCENE_PATH)
	if player_scene == null:
		push_error("[GameLevel] 无法加载玩家场景: " + PLAYER_SCENE_PATH)
		return
	
	player_node = player_scene.instantiate() as Player
	player_container.add_child(player_node)
	player_node.global_position = spawn_pos
	player_node.add_to_group("player")
	
	# 摄像机跟随玩家
	camera.reparent(player_node)
	camera.position = Vector2.ZERO
	camera.zoom = Vector2(2.5, 2.5)
	
	# 等待 _ready 执行完毕，此时 setup_from_data 已经在 Player._ready 中调用
	await get_tree().process_frame
	
	var anim_sprite = player_node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var char_id = GameStateManager.selected_character_id
	if char_id.is_empty():
		char_id = "villager"
	PlaceholderSpriteGenerator.setup_sprite(anim_sprite, char_id)
	
	# 修复：名称标签显示玩家实际名称
	var name_lbl = player_node.get_node_or_null("NameLabel") as Label
	if name_lbl:
		name_lbl.text = player_node.display_name
		print("[GameLevel] 设置玩家名称标签: ", player_node.display_name)
	
	if hud and hud.has_method("init_for_player"):
		hud.init_for_player(player_node)
	
	print("[GameLevel] 玩家生成完成: %s (%s) at %s" % [
		player_node.display_name, char_id, str(spawn_pos)
	])


## NPC 生成后的精灵初始化
## 修复：child_entered_tree 时 init_npc 还未调用，需等待多帧后再设置名称
func _on_npc_container_child_entered_tree(npc_node: Node) -> void:
	if not npc_node is NPC:
		return
	# 等待两帧：第一帧等 NPC._ready() + init_npc() 执行完，第二帧确保 display_name 已赋值
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not is_instance_valid(npc_node):
		return
	
	# 设置精灵动画
	var anim_sprite = npc_node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var char_id: String = npc_node.character_id
	if char_id.is_empty():
		char_id = "villager"
	PlaceholderSpriteGenerator.setup_sprite(anim_sprite, char_id)
	
	# 修复：设置 NPC 名称标签
	var name_lbl = npc_node.get_node_or_null("NameLabel") as Label
	if name_lbl:
		# 确保 display_name 不是默认的 "未知"
		var display = npc_node.display_name
		if display.is_empty() or display == "未知":
			# 从数据中重新获取
			var data = DataManager.get_character(npc_node.character_id)
			display = data.get("display_name", npc_node.character_id)
		name_lbl.text = display
		name_lbl.visible = true
		print("[GameLevel] 设置NPC名称标签: %s -> '%s'" % [npc_node.character_id, display])
	
	# 设置血条脚本
	var hp_fill = npc_node.get_node_or_null("HPBarFill") as ColorRect
	if hp_fill and not hp_fill.get_script():
		var script = load("res://scripts/ui/NPCHealthBar.gd")
		if script:
			hp_fill.set_script(script)


## 射弹生成 (v1.0.2)
func _on_projectile_fired(from_pos: Vector2, direction: Vector2, weapon_data: Dictionary, shooter: BaseCharacter) -> void:
	if not is_instance_valid(_projectile_container):
		return
	var proj = Projectile.create(from_pos, direction, weapon_data, shooter)
	_projectile_container.add_child(proj)
