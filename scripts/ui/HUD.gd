## HUD.gd
## 游戏内抬头显示 v1.0.2
## 新增：药水数量显示、背包切换提示

extends CanvasLayer

@onready var hp_bar: ProgressBar         = $MarginContainer/VBox/HPRow/HPBar
@onready var hp_label: Label             = $MarginContainer/VBox/HPRow/HPLabel
@onready var mp_bar: ProgressBar         = $MarginContainer/VBox/MPRow/MPBar
@onready var mp_label: Label             = $MarginContainer/VBox/MPRow/MPLabel
@onready var gold_label: Label           = $MarginContainer/VBox/GoldRow/GoldLabel
@onready var weapon_bar: ProgressBar     = $MarginContainer/VBox/WeaponRow/WeaponDurBar
@onready var weapon_label: Label         = $MarginContainer/VBox/WeaponRow/WeaponLabel
@onready var potion_label: Label         = $MarginContainer/VBox/PotionRow/PotionLabel
@onready var quest_label: Label          = $QuestPanel/QuestLabel
@onready var interact_hint: Label        = $InteractHint


func _ready() -> void:
	EventBus.hp_changed.connect(_on_hp_changed)
	EventBus.mp_changed.connect(_on_mp_changed)
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.weapon_durability_changed.connect(_on_weapon_durability_changed)
	EventBus.weapon_broken.connect(_on_weapon_broken)
	EventBus.quest_updated.connect(_on_quest_updated)
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.weapon_switched.connect(_on_weapon_switched)
	
	_on_gold_changed(GameStateManager.player_gold)
	
	if interact_hint:
		interact_hint.visible = false
	
	if quest_label:
		quest_label.text = "任务：击败魔物 0 / 5"


func _on_hp_changed(entity: Node, new_hp: float, max_hp: float) -> void:
	if not entity is Player:
		return
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = new_hp
	if hp_label:
		hp_label.text = "HP: %d / %d" % [int(new_hp), int(max_hp)]


func _on_mp_changed(entity: Node, new_mp: float, max_mp: float) -> void:
	if not entity is Player:
		return
	if mp_bar:
		mp_bar.max_value = max_mp if max_mp > 0 else 1
		mp_bar.value = new_mp
	if mp_label:
		mp_label.text = "MP: %d / %d" % [int(new_mp), int(max_mp)]


func _on_gold_changed(amount: int) -> void:
	if gold_label:
		gold_label.text = "金币: %d" % amount


func _on_weapon_durability_changed(entity: Node, durability: float, max_durability: float) -> void:
	if not entity is Player:
		return
	if weapon_bar:
		if max_durability <= 0:
			weapon_bar.max_value = 1
			weapon_bar.value = 1
		else:
			weapon_bar.max_value = max_durability
			weapon_bar.value = durability
	if weapon_label:
		var weapon_name = entity.weapon_data.get("display_name", "拳头")
		if max_durability <= 0:
			weapon_label.text = "%s (∞)" % weapon_name
		else:
			weapon_label.text = "%s (%d/%d)" % [weapon_name, int(durability), int(max_durability)]


func _on_weapon_broken(entity: Node, _weapon_id: String) -> void:
	if not entity is Player:
		return
	if weapon_label:
		weapon_label.text = "武器损坏！（拳头）"
		var tween = create_tween()
		tween.tween_property(weapon_label, "modulate", Color.RED, 0.2)
		tween.tween_property(weapon_label, "modulate", Color.WHITE, 0.2)
		tween.set_loops(3)


func _on_weapon_switched(entity: Node, weapon_data: Dictionary) -> void:
	if not entity is Player:
		return
	var dur = float(weapon_data.get("durability", -1))
	var max_dur = dur
	_on_weapon_durability_changed(entity, dur, max_dur)


func _on_quest_updated(quest_id: String, data: Dictionary) -> void:
	if quest_id == "kill_monsters" and quest_label:
		var count = data.get("count", 0)
		var target = data.get("target", 5)
		quest_label.text = "任务：击败魔物 %d / %d" % [count, target]


func _on_game_state_changed(_old: int, new_state: int) -> void:
	if new_state == GameStateManager.GameState.GAME_OVER:
		visible = false


## v1.0.2: 更新药水显示
func _on_inventory_changed() -> void:
	_update_potion_display()


func _update_potion_display() -> void:
	var player = _find_player()
	if player == null:
		return
	if potion_label:
		potion_label.text = "血瓶:%d  蓝瓶:%d  背包:%d/%d" % [
			player.health_potions, player.mana_potions,
			player.inventory.size(), player.INVENTORY_SIZE
		]


func _find_player() -> Player:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Player
	return null


# ─────────────────────────────────────────────
# 公共方法
# ─────────────────────────────────────────────

func show_interact_hint(text: String = "按 [F] 交互") -> void:
	if interact_hint:
		interact_hint.text = text
		interact_hint.visible = true

func hide_interact_hint() -> void:
	if interact_hint:
		interact_hint.visible = false


func init_for_player(player: Player) -> void:
	_on_hp_changed(player, player.current_hp, player.max_hp)
	_on_mp_changed(player, player.current_mp, player.max_mp)
	_on_gold_changed(GameStateManager.player_gold)
	if player.weapon_data.get("durability", -1) == -1:
		_on_weapon_durability_changed(player, -1, -1)
	else:
		_on_weapon_durability_changed(player, player.weapon_durability, player.weapon_data.get("durability", 100))
	_update_potion_display()
