## NPCHealthBar.gd  v1.2
## 修复：await get_parent().ready; 白色前景（当前血量）+ 暗红色背景（总血量）
## 安装在 NPC 节点下的 HPBarFill 子节点

extends ColorRect

const BAR_FULL_WIDTH := 32.0
const BAR_HEIGHT := 4.0

var _owner_npc = null
var _background_bar: ColorRect = null


func _ready() -> void:
	# 等待父节点初始化完成
	var parent = get_parent()
	if parent and not parent.is_node_ready():
		await parent.ready

	_owner_npc = get_parent()
	if _owner_npc == null:
		return

	# 设置本节点为前景（白色，当前血量）
	size = Vector2(BAR_FULL_WIDTH, BAR_HEIGHT)
	color = Color(1, 1, 1, 1.0)  # 白色前景
	z_index = 2

	# 创建背景血条（暗红色，始终满格）
	_create_background_bar()

	EventBus.hp_changed.connect(_on_hp_changed)

	# 初始化显示
	call_deferred("_initial_update")


func _initial_update() -> void:
	if _owner_npc and _owner_npc.has_method("get_hp_percent"):
		var hp = _owner_npc.get("current_hp")
		var mhp = _owner_npc.get("max_hp")
		if hp != null and mhp != null:
			_on_hp_changed(_owner_npc, float(hp), float(mhp))


func _create_background_bar() -> void:
	_background_bar = ColorRect.new()
	_background_bar.name = "HPBarBackground"
	_background_bar.size = Vector2(BAR_FULL_WIDTH, BAR_HEIGHT)
	_background_bar.color = Color(0.4, 0.05, 0.05, 0.9)  # 暗红色背景
	_background_bar.position = position  # 与前景条对齐
	_background_bar.z_index = 1

	# 添加到同父节点
	get_parent().add_child(_background_bar)

	# 确保前景在背景上方
	move_to_front()


func _on_hp_changed(entity, new_hp: float, max_hp: float) -> void:
	# 确保只更新自己的 NPC
	if entity != _owner_npc:
		return

	var pct = clamp(new_hp / max_hp, 0.0, 1.0) if max_hp > 0 else 0.0

	# 更新前景（白色部分，代表当前血量）
	size.x = BAR_FULL_WIDTH * pct

	# 背景始终是满格暗红
	if _background_bar:
		_background_bar.size.x = BAR_FULL_WIDTH

	# 血量低时变黄，极低时变橙
	if pct > 0.5:
		color = Color(1, 1, 1, 1.0)      # 白色（血量充足）
	elif pct > 0.25:
		color = Color(1, 0.9, 0.1, 1.0)  # 黄色（血量一般）
	else:
		color = Color(1, 0.4, 0.1, 1.0)  # 橙红色（血量危险）
