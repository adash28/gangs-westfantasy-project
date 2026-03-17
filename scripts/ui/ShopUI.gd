## ShopUI.gd
## 商店界面：显示商品列表，支持购买，商人"老谋深算"技能自动打折

extends CanvasLayer

# ─────────────────────────────────────────────
# 节点引用
# ─────────────────────────────────────────────
@onready var panel: Panel           = $Panel
@onready var shop_title: Label      = $Panel/VBox/TitleLabel
@onready var item_list: VBoxContainer = $Panel/VBox/ScrollContainer/ItemList
@onready var gold_label: Label      = $Panel/VBox/BottomRow/GoldLabel
@onready var close_btn: Button      = $Panel/VBox/BottomRow/CloseBtn

## 商品按钮场景（动态生成）
var _item_button_template: PackedScene = null

## 当前开店的商人节点
var _merchant: NPC = null

## 是否有老谋深算折扣
var _has_discount: bool = false
const DISCOUNT_RATE := 0.7  # 折后价格 = 原价 × 0.7


# ─────────────────────────────────────────────
# 初始化
# ─────────────────────────────────────────────

func _ready() -> void:
	panel.visible = false
	
	EventBus.shop_opened.connect(_on_shop_opened)
	EventBus.shop_closed.connect(_on_shop_closed)
	EventBus.gold_changed.connect(_on_gold_changed)
	
	if close_btn:
		close_btn.pressed.connect(_close_shop)


# ─────────────────────────────────────────────
# 商店逻辑
# ─────────────────────────────────────────────

func _on_shop_opened(merchant: Node) -> void:
	_merchant = merchant as NPC
	panel.visible = true
	
	# 检查商人是否有老谋深算技能
	_has_discount = false
	if _merchant and _merchant.skills.has("shrewd_dealer"):
		_has_discount = true
	
	var title = _merchant.display_name + " 的商店" if _merchant else "商店"
	shop_title.text = title
	
	_populate_items()
	_on_gold_changed(GameStateManager.player_gold)


func _populate_items() -> void:
	# 清空旧列表
	for child in item_list.get_children():
		child.queue_free()
	
	# 填充商品（从 DataManager 读取）
	var items = DataManager.shop_items
	for item_id in items:
		var item_data: Dictionary = items[item_id].duplicate(true)
		var base_price: int = item_data.get("base_price", 10)
		var final_price: int = int(base_price * DISCOUNT_RATE) if _has_discount else base_price
		
		# 动态创建商品按钮行
		var row = HBoxContainer.new()
		
		var name_lbl = Label.new()
		name_lbl.text = item_data.get("display_name", item_id)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var desc_lbl = Label.new()
		desc_lbl.text = item_data.get("description", "")
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		
		var price_lbl = Label.new()
		if _has_discount:
			price_lbl.text = "%d金 (折扣)" % final_price
			price_lbl.add_theme_color_override("font_color", Color.YELLOW)
		else:
			price_lbl.text = "%d金" % final_price
		
		var buy_btn = Button.new()
		buy_btn.text = "购买"
		# 使用 lambda 绑定 item_id 和 price（Godot 4 闭包）
		buy_btn.pressed.connect(func(): _buy_item(item_id, item_data, final_price))
		
		row.add_child(name_lbl)
		row.add_child(desc_lbl)
		row.add_child(price_lbl)
		row.add_child(buy_btn)
		item_list.add_child(row)


func _buy_item(item_id: String, item_data: Dictionary, price: int) -> void:
	if not GameStateManager.spend_gold(price):
		# 金币不足：显示提示
		EventBus.dialogue_triggered.emit("商店", ["金币不足，无法购买！"])
		return
	
	# 应用物品效果
	var player = _find_player()
	if player:
		_apply_item_effect(player, item_data)
	
	print("[ShopUI] 购买: %s 花费 %d 金币" % [item_data.get("display_name", item_id), price])
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
	# 通过 group 找玩家（玩家节点需加入 "player" group）
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
