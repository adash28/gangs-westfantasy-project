## CharacterSelectUI.gd
## 角色选择界面：读取 DataManager 中所有可选角色，动态生成选择按钮

extends CanvasLayer

@onready var title_label: Label          = $Panel/VBox/TitleLabel
@onready var char_list: HBoxContainer    = $Panel/VBox/CharList
@onready var preview_name: Label         = $Panel/VBox/PreviewBox/NameLabel
@onready var preview_desc: Label         = $Panel/VBox/PreviewBox/DescLabel
@onready var preview_stats: Label        = $Panel/VBox/PreviewBox/StatsLabel
@onready var confirm_btn: Button         = $Panel/VBox/ConfirmBtn

var _selected_char_id: String = ""


func _ready() -> void:
	_populate_characters()
	if confirm_btn:
		confirm_btn.pressed.connect(_on_confirm_pressed)
		confirm_btn.disabled = true  # 未选择时禁用


func _populate_characters() -> void:
	var playable_ids = DataManager.get_playable_character_ids()
	
	for char_id in playable_ids:
		var data = DataManager.get_character(char_id)
		
		var btn = Button.new()
		btn.text = data.get("display_name", char_id)
		btn.custom_minimum_size = Vector2(120, 80)
		btn.pressed.connect(func(): _on_char_selected(char_id))
		char_list.add_child(btn)


func _on_char_selected(char_id: String) -> void:
	_selected_char_id = char_id
	var data = DataManager.get_character(char_id)
	
	if preview_name:
		preview_name.text = data.get("display_name", char_id)
	if preview_desc:
		preview_desc.text = data.get("description", "")
	if preview_stats:
		var weapon_data = DataManager.get_weapon(data.get("starting_weapon", "fist"))
		preview_stats.text = (
			"HP: %d  MP: %d\n" % [data.get("hp", 0), data.get("mp", 0)] +
			"攻击: %d  魔攻: %d\n" % [data.get("damage", 0), data.get("magic_damage", 0)] +
			"速度: %d\n" % data.get("move_speed", 0) +
			"武器: %s\n" % weapon_data.get("display_name", "拳头") +
			"技能: %s" % ", ".join(data.get("skills", ["无"]))
		)
	if confirm_btn:
		confirm_btn.disabled = false


func _on_confirm_pressed() -> void:
	if _selected_char_id.is_empty():
		return
	GameStateManager.select_character(_selected_char_id)
	# 切换到游戏场景
	get_tree().change_scene_to_file("res://scenes/GameLevel.tscn")
