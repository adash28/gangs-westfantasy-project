## GameLevel.gd
## GameLevel 场景的主控脚本
## 职责：
##   1. 调用 MapGenerator 生成地图（含占位TileSet注入）
##   2. 生成玩家节点并放置到出生点
##   3. 绑定摄像机跟随玩家
##   4. 初始化 HUD
##   5. 传递引用给 Chapter1Manager

extends Node2D

# 节点引用
@onready var tilemap: TileMapLayer       = $World/TileMapLayer
@onready var npc_container: Node2D       = $World/NPCContainer
@onready var player_container: Node2D    = $World/PlayerContainer
@onready var map_generator: MapGenerator = $MapGenerator
@onready var camera: Camera2D            = $Camera2D
@onready var chapter1_manager: Node      = $Chapter1Manager
@onready var hud: Node                   = $HUD

# 玩家场景路径
const PLAYER_SCENE_PATH := "res://scenes/Player.tscn"
const NPC_SCENE_PATH     := "res://scenes/NPC.tscn"

var player_node: Player = null


func _ready() -> void:
	# 确保游戏状态正确
	GameStateManager.change_state(GameStateManager.GameState.LOAD_LEVEL)
	
	# ── 注入占位 TileSet（无美术资源时也能渲染地图）──
	if tilemap.tile_set == null:
		tilemap.tile_set = PlaceholderSpriteGenerator.create_placeholder_tileset()
	
	# 配置地图生成器
	map_generator.tilemap = tilemap
	map_generator.npc_parent = npc_container
	map_generator.npc_scene_path = NPC_SCENE_PATH
	
	# 生成地图，获取玩家出生点像素坐标
	var spawn_pos: Vector2 = map_generator.generate()
	
	# 生成玩家
	_spawn_player(spawn_pos)
	
	# 传递引用给第一章管理器（chapter1_manager._ready 会在 Node 加入树时自动调用）
	if chapter1_manager:
		chapter1_manager.player_node = player_node
		chapter1_manager.hud_node = hud
	
	# 切换到游玩状态
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
	
	# 将玩家加入 group，方便其他脚本查找
	player_node.add_to_group("player")
	
	# 摄像机跟随玩家
	camera.reparent(player_node)
	camera.position = Vector2.ZERO
	
	# 为玩家生成占位精灵
	await get_tree().process_frame   # 等 Player._ready() 完成
	var anim_sprite = player_node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	PlaceholderSpriteGenerator.setup_sprite(anim_sprite, GameStateManager.selected_character_id)
	
	# 设置名称标签
	var name_lbl = player_node.get_node_or_null("NameLabel") as Label
	if name_lbl:
		name_lbl.text = player_node.display_name
	
	# 初始化 HUD
	if hud and hud.has_method("init_for_player"):
		hud.init_for_player(player_node)
	
	print("[GameLevel] 玩家生成完成: %s at %s" % [
		GameStateManager.selected_character_id, str(spawn_pos)
	])


## NPC 生成后的精灵初始化（MapGenerator 调用 init_npc 时触发）
## 通过连接 NPCContainer 的 child_entered_tree 信号批量处理
func _on_npc_container_child_entered_tree(npc_node: Node) -> void:
	if not npc_node is NPC:
		return
	# 等待 init_npc 完成后才能读到 character_id
	await get_tree().process_frame
	var anim_sprite = npc_node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	PlaceholderSpriteGenerator.setup_sprite(anim_sprite, npc_node.character_id)
	# 设置名称标签
	var name_lbl = npc_node.get_node_or_null("NameLabel") as Label
	if name_lbl:
		name_lbl.text = npc_node.display_name
	# 设置 NPC 头顶血条脚本
	var hp_fill = npc_node.get_node_or_null("HPBarFill") as ColorRect
	if hp_fill and not hp_fill.get_script():
		var script = load("res://scripts/ui/NPCHealthBar.gd")
		hp_fill.set_script(script)
