## NPCHealthBar.gd
## 挂在 NPC 场景中 HPBarFill 节点上
## 监听 hp_changed 事件，自动更新头顶血条宽度

extends ColorRect

const BAR_FULL_WIDTH := 32.0  # 满血时宽度（像素）
var _owner_npc: NPC = null


func _ready() -> void:
	# 等父节点（NPC）初始化完成
	await owner.ready
	_owner_npc = get_parent() as NPC
	if _owner_npc == null:
		return
	EventBus.hp_changed.connect(_on_hp_changed)


func _on_hp_changed(entity: Node, new_hp: float, max_hp: float) -> void:
	if entity != _owner_npc:
		return
	var pct = new_hp / max_hp if max_hp > 0 else 0.0
	# 通过改变 size_x 模拟血条
	var new_width = BAR_FULL_WIDTH * pct
	size.x = new_width
	# 颜色根据血量变化：绿→黄→红
	if pct > 0.5:
		color = Color(0.1, 0.8, 0.1, 1.0)
	elif pct > 0.25:
		color = Color(0.9, 0.7, 0.0, 1.0)
	else:
		color = Color(0.9, 0.1, 0.1, 1.0)
