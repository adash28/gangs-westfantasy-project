## ShopUI.gd  v1.1
## 修复：只有选择商人角色时才有折扣
## 修复：购买的药水放入背包，而不是立即使用

extends CanvasLayer

@onready var panel: Panel           = $Panel
@onready var shop_title: Label      = $Panel/VBox/TitleLabel
@onready var item_list: VBoxContainer = $Panel/VBox/ScrollContainer/ItemList
@onready var gold_label: Label      = $Panel/VBox/BottomRow/GoldLabel
@onready var close_btn: Button      = $Panel/VBox/BottomRow/CloseBtn

var _merchant: NPC = null
var _has_discount: bool = false
const DISCOUNT_RATE := 0.7


func _ready() -> void:
	panel.visible = false
	
	EventBus.shop_opened.connect(_on_shop_opened)
	EventBus.shop_closed.connect(_on_shop_closed)
	EventBus.gold_changed.connect(_on_gold_changed)
	
	if close_btn:
		close_btn.pressed.connect(_close_shop)


func _on_shop_opened(merchant: Node) -> void:
	_merchant = merchant as NPC
	panel.visible = true
	
	# ─── Bug修复：折扣只给选择了"商人"角色的玩家 ───
	_has_discount = false
	var selected_char = GameStateManager.selected_character_id
	if selected_char == "merchant":
		# 玩家选择的是商人角色，享有老谋深算折扣
		_has_discount = true
	
	var title = _merchant.display_name + " 的商店" if _merchant else "商店"
	if _has_discount:
		title += " (折扣 70%)"
	shop_title.text = title
	
	_populate_items()
	_on_gold_changed(GameStateManager.player_gold)


func _populate_items() -> void:
	for child in item_list.get_children():
		child.queue_free()
	
	var items = DataManager.shop_items
	for item_id in items:
		var item_data: Dictionary = items[item_id].duplicate(true)
		var base_price: int = item_data.get("base_price", 10)
		var final_price: int = int(base_price * DISCOUNT_RATE) if _has_discount else base_price
		
		var row = HBoxContainer.new()
		
		# 物品颜色图标
		var icon = ColorRect.new()
		icon.custom_minimum_size = Vector2(16, 16)
		icon.size = Vector2(16, 16)
		match item_data.get("icon_color", ""):
			"red":  icon.color = Color(0.9, 0.1, 0.1)
			"blue": icon.color = Color(0.1, 0.2, 0.9)
			_:      icon.color = Color(0.6, 0.6, 0.6)
		
		var name_lbl = Label.new()
		name_lbl.text = item_data.get("display_name", item_id)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var desc_lbl = Label.new()
		desc_lbl.text = item_data.get("description", "")
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		desc_lbl.add_theme_font_size_override("font_size", 11)
		
		var price_lbl = Label.new()
		if _has_discount:
			price_lbl.text = "%d金 (折)" % final_price
			price_lbl.add_theme_color_override("font_color", Color.YELLOW)
		else:
			price_lbl.text = "%d金" % final_price
		
		var buy_btn = Button.new()
		buy_btn.text = "购买→背包"
		buy_btn.pressed.connect(func(): _buy_item(item_id, item_data, final_price))
		
		row.add_child(icon)
		row.add_child(name_lbl)
		row.add_child(desc_lbl)
		row.add_child(price_lbl)
		row.add_child(buy_btn)
		item_list.add_child(row)


func _buy_item(item_id: String, item_data: Dictionary, price: int) -> void:
	if not GameStateManager.spend_gold(price):
		EventBus.dialogue_triggered.emit("商店", ["金币不足，无法购买！"])
		return
	
	# ─── 修复：购买的药水放入背包，而不是立即使用 ───
	var player = _find_player()
	if player and player.inventory_ui and player.inventory_ui._inventory:
		var added = player.inventory_ui._inventory.add_item(item_data)
		if added:
			player.inventory_ui.refresh_display()
			print("[ShopUI] 购买 %s 放入背包，花费 %d 金币" % [item_data.get("display_name", item_id), price])
		else:
			# 背包满：直接使用
			_apply_item_effect(player, item_data)
			print("[ShopUI] 背包满，直接使用 %s" % item_data.get("display_name", item_id))
	elif player:
		# 没有背包时直接使用
		_apply_item_effect(player, item_data)
	
	EventBus.item_picked_up.emit(item_data)


func _apply_item_effect(player: Player, item_data: Dictionary) -> void:
	var effect = item_data.get("effect", "")
	var value = float(item_data.get("effect_value", 0))
	match effect:
		"heal":
			player.heal(value)
		"restore_mp":
			player.change_mp(value)


func _find_player() -> Player:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Player
	return null


func _on_gold_changed(amount: int) -> void:
	if gold_label:
		gold_label.text = "持有金币: %d" % amount


func _close_shop() -> void:
	panel.visible = false
	GameStateManager.change_state(GameStateManager.GameState.PLAYING)
	EventBus.shop_closed.emit()


func _on_shop_closed() -> void:
	panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible:
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		get_viewport().set_input_as_handled()
		_close_shop()
