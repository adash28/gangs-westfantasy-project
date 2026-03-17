## HUD.gd
## 游戏内抬头显示（血条、魔力条、金币、任务进度、武器耐久）
## 挂载在 HUD.tscn 场景根节点上

extends CanvasLayer

# ─────────────────────────────────────────────
# 节点引用
# ─────────────────────────────────────────────
@onready var hp_bar: ProgressBar         = $MarginContainer/VBox/HPRow/HPBar
@onready var hp_label: Label             = $MarginContainer/VBox/HPRow/HPLabel
@onready var mp_bar: ProgressBar         = $MarginContainer/VBox/MPRow/MPBar
@onready var mp_label: Label             = $MarginContainer/VBox/MPRow/MPLabel
@onready var gold_label: Label           = $MarginContainer/VBox/GoldRow/GoldLabel
@onready var weapon_bar: ProgressBar     = $MarginContainer/VBox/WeaponRow/WeaponDurBar
@onready var weapon_label: Label         = $MarginContainer/VBox/WeaponRow/WeaponLabel
@onready var quest_label: Label          = $QuestPanel/QuestLabel
@onready var interact_hint: Label        = $InteractHint

# ─────────────────────────────────────────────
# 初始化
# ─────────────────────────────────────────────

func _ready() -> void:
	# 订阅 EventBus 事件
	EventBus.hp_changed.connect(_on_hp_changed)
	EventBus.mp_changed.connect(_on_mp_changed)
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.weapon_durability_changed.connect(_on_weapon_durability_changed)
	EventBus.weapon_broken.connect(_on_weapon_broken)
	EventBus.quest_updated.connect(_on_quest_updated)
	EventBus.game_state_changed.connect(_on_game_state_changed)
	
	# 初始化金币显示
	_on_gold_changed(GameStateManager.player_gold)
	
	# 默认隐藏交互提示
	if interact_hint:
		interact_hint.visible = false
	
	# 初始化任务文本
	if quest_label:
		quest_label.text = "任务：击败魔物 0 / 5"


# ─────────────────────────────────────────────
# 事件回调
# ─────────────────────────────────────────────

func _on_hp_changed(entity: Node, new_hp: float, max_hp: float) -> void:
	# 只更新玩家的血条
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
			# 无限耐久
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
		# 闪烁警告
		var tween = create_tween()
		tween.tween_property(weapon_label, "modulate", Color.RED, 0.2)
		tween.tween_property(weapon_label, "modulate", Color.WHITE, 0.2)
		tween.set_loops(3)


func _on_quest_updated(quest_id: String, data: Dictionary) -> void:
	if quest_id == "kill_monsters" and quest_label:
		var count = data.get("count", 0)
		var target = data.get("target", 5)
		quest_label.text = "任务：击败魔物 %d / %d" % [count, target]


func _on_game_state_changed(_old: int, new_state: int) -> void:
	# 游戏结束 → 隐藏 HUD（GameOver 界面会接管）
	if new_state == GameStateManager.GameState.GAME_OVER:
		visible = false


# ─────────────────────────────────────────────
# 公共方法
# ─────────────────────────────────────────────

## 显示/隐藏交互提示（F 键提示）
func show_interact_hint(text: String = "按 [F] 交互") -> void:
	if interact_hint:
		interact_hint.text = text
		interact_hint.visible = true


func hide_interact_hint() -> void:
	if interact_hint:
		interact_hint.visible = false


## 玩家首次初始化时调用，刷新所有 UI
func init_for_player(player: Player) -> void:
	_on_hp_changed(player, player.current_hp, player.max_hp)
	_on_mp_changed(player, player.current_mp, player.max_mp)
	_on_gold_changed(GameStateManager.player_gold)
	if player.weapon_data.get("durability", -1) == -1:
		_on_weapon_durability_changed(player, -1, -1)
	else:
		_on_weapon_durability_changed(player, player.weapon_durability, player.weapon_data.get("durability", 100))
