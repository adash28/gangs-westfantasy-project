## NPCHealthBar.gd
## v1.0.2 修复：血条按百分比正确显示红色填充，剩余用白色背景
## 修复：移除 await owner.ready，改为直接初始化

extends ColorRect

const BAR_FULL_WIDTH := 32.0
var _owner_npc: NPC = null
var _bg_rect: ColorRect = null


func _ready() -> void:
	# 修复：不使用 await owner.ready，直接获取父节点
	# HPBarFill 的父节点就是 NPC
	_owner_npc = get_parent() as NPC
	if _owner_npc == null:
		# 尝试从 owner 获取
		_owner_npc = owner as NPC
	if _owner_npc == null:
		push_warning("[NPCHealthBar] 无法找到 NPC 父节点")
		return
	
	# 确保背景条（HPBarBG）正确显示
	_bg_rect = _owner_npc.get_node_or_null("HPBarBG") as ColorRect
	if _bg_rect:
		_bg_rect.color = Color(0.2, 0.05, 0.05, 0.8)  # 深红色背景（表示损失的血量）
		_bg_rect.size.x = BAR_FULL_WIDTH
	
	# 初始化血条为满血状态（红色表示当前血量）
	size.x = BAR_FULL_WIDTH
	color = Color(0.85, 0.15, 0.15, 1.0)
	
	# 延迟一帧再连接事件，确保 NPC 的 HP 已经初始化
	EventBus.hp_changed.connect(_on_hp_changed)
	
	# 进行初始更新
	call_deferred("_initial_update")


func _initial_update() -> void:
	if _owner_npc and _owner_npc.max_hp > 0:
		_on_hp_changed(_owner_npc, _owner_npc.current_hp, _owner_npc.max_hp)


func _on_hp_changed(entity: Node, new_hp: float, max_hp: float) -> void:
	if entity != _owner_npc:
		return
	
	var pct = new_hp / max_hp if max_hp > 0 else 0.0
	pct = clamp(pct, 0.0, 1.0)
	
	# 红色填充部分按血量百分比缩放
	size.x = BAR_FULL_WIDTH * pct
	
	# 根据血量调整颜色
	if pct > 0.5:
		color = Color(0.85, 0.15, 0.15, 1.0)  # 正常红色
	elif pct > 0.25:
		color = Color(0.9, 0.5, 0.1, 1.0)     # 橙色（中等血量）
	else:
		color = Color(1.0, 0.1, 0.1, 1.0)     # 亮红（低血量警告）
	
	# 背景始终满宽（深色，表示已损失血量）
	if _bg_rect:
		_bg_rect.size.x = BAR_FULL_WIDTH
