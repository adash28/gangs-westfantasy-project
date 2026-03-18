## DroppedItem.gd
## 掉落在地面上的物品，玩家靠近后按F/interact键拾取

extends Area2D
class_name DroppedItem

var item_data: Dictionary = {}

@onready var sprite: ColorRect = $ColorRect if has_node("ColorRect") else null
@onready var label: Label = $Label if has_node("Label") else null

var _float_timer: float = 0.0
var _initial_y: float = 0.0


func _ready() -> void:
	_initial_y = position.y
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func setup(data: Dictionary) -> void:
	item_data = data.duplicate(true)
	_build_visual()


func _build_visual() -> void:
	# 动态创建视觉节点
	var cr = ColorRect.new()
	cr.name = "ColorRect"
	cr.size = Vector2(12, 12)
	cr.position = Vector2(-6, -6)
	
	# 根据物品类型设置颜色
	match item_data.get("icon_color", ""):
		"red":   cr.color = Color(0.9, 0.1, 0.1)
		"blue":  cr.color = Color(0.1, 0.2, 0.9)
		"yellow": cr.color = Color(1.0, 0.85, 0.1)
		_:       cr.color = Color(0.6, 0.6, 0.6)
	add_child(cr)
	
	# 名称标签（悬浮在物品上方）
	var lbl = Label.new()
	lbl.name = "Label"
	lbl.text = item_data.get("display_name", "物品")
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.position = Vector2(-20, -18)
	lbl.size = Vector2(52, 12)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)
	
	# 碰撞形状
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 14.0
	col.shape = shape
	add_child(col)
	
	collision_layer = 0
	collision_mask = 1  # 只检测玩家


func _process(delta: float) -> void:
	# 轻微上下浮动效果
	_float_timer += delta * 2.0
	position.y = _initial_y + sin(_float_timer) * 2.0


func _on_body_entered(body: Node) -> void:
	if body is Player:
		body.nearby_items.append(self)


func _on_body_exited(body: Node) -> void:
	if body is Player:
		body.nearby_items.erase(self)


## 被玩家拾取
func pickup(player: Player) -> void:
	if player.inventory_ui and player.inventory_ui._inventory:
		var added = player.inventory_ui._inventory.add_item(item_data)
		if added:
			player.inventory_ui.refresh_display()
			EventBus.item_picked_up.emit(item_data)
			print("[DroppedItem] 拾取: %s" % item_data.get("display_name", "?"))
			queue_free()
		else:
			print("[DroppedItem] 背包已满，无法拾取")
