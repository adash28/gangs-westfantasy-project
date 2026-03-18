## InventoryUI.gd
## 背包界面：5x5方格，E键开关，点击使用/装备物品
## 显示物品图标、名称，支持药水使用

extends CanvasLayer
class_name InventoryUI

# ─────────────────────────────────────────────
# 常量
# ─────────────────────────────────────────────

const SLOT_SIZE = 52      # 格子大小（像素）
const SLOT_PADDING = 4    # 格间距
const GRID_COLS = 5
const GRID_ROWS = 5

# ─────────────────────────────────────────────
# 节点引用
# ─────────────────────────────────────────────

var _panel: Panel = null
var _grid_container: GridContainer = null
var _title_label: Label = null
var _tooltip_label: Label = null
var _close_btn: Button = null

var _slot_buttons: Array = []  # 25个格子按钮

# ─────────────────────────────────────────────
# 状态
# ─────────────────────────────────────────────

var _inventory: InventorySystem = null
var _player: Player = null
var _is_open: bool = false


# ─────────────────────────────────────────────
# 初始化
# ─────────────────────────────────────────────

func _ready() -> void:
	_build_ui()
	visible = false
	
	EventBus.item_picked_up.connect(_on_item_picked_up)


func _build_ui() -> void:
	# 主面板
	_panel = Panel.new()
	_panel.name = "InventoryPanel"
	var panel_width = GRID_COLS * (SLOT_SIZE + SLOT_PADDING) + SLOT_PADDING + 20
	var panel_height = GRID_ROWS * (SLOT_SIZE + SLOT_PADDING) + SLOT_PADDING + 80
	_panel.custom_minimum_size = Vector2(panel_width, panel_height)
	_panel.size = Vector2(panel_width, panel_height)
	_panel.position = Vector2(60, 60)
	add_child(_panel)
	
	# 面板背景样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.06, 0.95)
	style.border_color = Color(0.6, 0.5, 0.2, 1)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	_panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(10, 10)
	vbox.size = Vector2(panel_width - 20, panel_height - 20)
	_panel.add_child(vbox)
	
	# 标题
	_title_label = Label.new()
	_title_label.text = "背包  [E键关闭]"
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	_title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_title_label)
	
	# 分隔线
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	# 网格
	_grid_container = GridContainer.new()
	_grid_container.columns = GRID_COLS
	_grid_container.add_theme_constant_override("h_separation", SLOT_PADDING)
	_grid_container.add_theme_constant_override("v_separation", SLOT_PADDING)
	vbox.add_child(_grid_container)
	
	# 创建25个格子
	_slot_buttons.clear()
	for i in range(GRID_COLS * GRID_ROWS):
		var slot_btn = _create_slot_button(i)
		_grid_container.add_child(slot_btn)
		_slot_buttons.append(slot_btn)
	
	# 工具提示
	_tooltip_label = Label.new()
	_tooltip_label.text = "点击物品使用/装备"
	_tooltip_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_tooltip_label.add_theme_font_size_override("font_size", 12)
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_tooltip_label)


func _create_slot_button(index: int) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	btn.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	
	# 格子样式
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.2, 0.18, 0.14, 0.9)
	style_normal.border_color = Color(0.5, 0.4, 0.2, 0.8)
	style_normal.border_width_left = 1
	style_normal.border_width_right = 1
	style_normal.border_width_top = 1
	style_normal.border_width_bottom = 1
	btn.add_theme_stylebox_override("normal", style_normal)
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.35, 0.3, 0.2, 0.95)
	style_hover.border_color = Color(0.9, 0.8, 0.3, 1.0)
	style_hover.border_width_left = 2
	style_hover.border_width_right = 2
	style_hover.border_width_top = 2
	style_hover.border_width_bottom = 2
	btn.add_theme_stylebox_override("hover", style_hover)
	
	btn.pressed.connect(func(): _on_slot_clicked(index))
	btn.mouse_entered.connect(func(): _on_slot_hovered(index))
	return btn


# ─────────────────────────────────────────────
# 公共方法
# ─────────────────────────────────────────────

func init_with_player(player: Player) -> void:
	_player = player
	_inventory = InventorySystem.new()
	_player.add_child(_inventory)
	# 将初始武器加入背包/武器列表
	if not _player.weapon_data.is_empty():
		_inventory.weapon_list.append(_player.weapon_data.duplicate(true))


func open() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	refresh_display()
	get_viewport().set_input_as_handled()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func is_open() -> bool:
	return _is_open


## 刷新所有格子显示
func refresh_display() -> void:
	if _inventory == null:
		return
	
	for i in range(min(_slot_buttons.size(), InventorySystem.MAX_SLOTS)):
		var btn: Button = _slot_buttons[i]
		var item = _inventory.get_item(i)
		_update_slot_display(btn, item)


func _update_slot_display(btn: Button, item: Dictionary) -> void:
	# 清除旧子节点
	for child in btn.get_children():
		child.queue_free()
	
	btn.text = ""
	
	if item.is_empty():
		return
	
	# 创建图标
	var icon_rect = ColorRect.new()
	icon_rect.size = Vector2(28, 28)
	icon_rect.position = Vector2(SLOT_SIZE/2 - 14, 4)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 根据物品类型设置颜色
	var item_id = item.get("id", "")
	match item.get("icon_color", ""):
		"red":
			icon_rect.color = Color(0.9, 0.1, 0.1, 0.9)
		"blue":
			icon_rect.color = Color(0.1, 0.2, 0.9, 0.9)
		"yellow":
			icon_rect.color = Color(1.0, 0.85, 0.1, 0.9)
		"gray":
			icon_rect.color = Color(0.5, 0.5, 0.5, 0.9)
		_:
			icon_rect.color = Color(0.6, 0.6, 0.6, 0.9)
	btn.add_child(icon_rect)
	
	# 物品名称（小字）
	var name_lbl = Label.new()
	name_lbl.text = item.get("display_name", "?")
	name_lbl.add_theme_font_size_override("font_size", 8)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.position = Vector2(2, SLOT_SIZE - 16)
	name_lbl.size = Vector2(SLOT_SIZE - 4, 14)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_child(name_lbl)


# ─────────────────────────────────────────────
# 输入处理
# ─────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_just_pressed("open_inventory"):
		toggle()
		get_viewport().set_input_as_handled()


# ─────────────────────────────────────────────
# 格子交互
# ─────────────────────────────────────────────

func _on_slot_clicked(index: int) -> void:
	if _inventory == null or _player == null:
		return
	
	var item = _inventory.get_item(index)
	if item.is_empty():
		return
	
	var item_type = item.get("type", "")
	var item_id = item.get("id", "")
	
	match item_type:
		"consumable":
			# 药水：使用并移除
			var effect = item.get("effect", "")
			var value = float(item.get("effect_value", 0))
			match effect:
				"heal":
					_player.heal(value)
					_inventory.remove_item(index)
					print("[InventoryUI] 使用治疗药水，恢复 %.0f HP" % value)
				"restore_mp":
					_player.change_mp(value)
					_inventory.remove_item(index)
					print("[InventoryUI] 使用魔力药水，恢复 %.0f MP" % value)
			refresh_display()
		
		"weapon", _:
			# 武器：装备（切换到该武器）
			if item.has("weapon_type") or item.has("extra_damage"):
				_player.equip_weapon_from_inventory(item)
				print("[InventoryUI] 装备武器: %s" % item.get("display_name", "?"))


func _on_slot_hovered(index: int) -> void:
	if _inventory == null:
		return
	var item = _inventory.get_item(index)
	if item.is_empty():
		_tooltip_label.text = "空格子"
	else:
		var desc = item.get("description", item.get("display_name", ""))
		var effect = item.get("effect", "")
		var hint = ""
		match effect:
			"heal": hint = " [点击使用]"
			"restore_mp": hint = " [点击使用]"
			_: hint = " [点击装备]" if (item.has("weapon_type") or item.has("extra_damage")) else ""
		_tooltip_label.text = desc + hint


# ─────────────────────────────────────────────
# 事件回调
# ─────────────────────────────────────────────

func _on_item_picked_up(item_data: Dictionary) -> void:
	# 商店购买的物品也会触发此事件
	if _inventory == null:
		return
	# 注意：商店购买时 ShopUI 已直接调用 apply_item_effect
	# 这里只处理放入背包的逻辑（由 DroppedItem 触发）
	refresh_display()
