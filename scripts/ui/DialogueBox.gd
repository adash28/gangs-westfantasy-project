## DialogueBox.gd
## 对话框 UI：支持逐字打印效果，多行对话翻页
## 对话期间游戏时间暂停（GameStateManager 处理）

extends CanvasLayer

# ─────────────────────────────────────────────
# 节点引用
# ─────────────────────────────────────────────
@onready var panel: Panel             = $Panel
@onready var speaker_label: Label     = $Panel/VBox/SpeakerLabel
@onready var text_label: RichTextLabel = $Panel/VBox/TextLabel
@onready var continue_hint: Label     = $Panel/VBox/ContinueHint

# ─────────────────────────────────────────────
# 对话状态
# ─────────────────────────────────────────────

## 当前对话行列表
var _lines: Array = []
## 当前显示到第几行
var _current_line: int = 0
## 是否正在打字特效中
var _is_typing: bool = false
## 打字速度（字符/秒）
const TYPE_SPEED := 30.0

var _type_timer: float = 0.0
var _full_text: String = ""
var _displayed_chars: int = 0


# ─────────────────────────────────────────────
# 初始化
# ─────────────────────────────────────────────

func _ready() -> void:
	panel.visible = false
	# 设置为始终处理（对话时 time_scale=0，需要不受影响）
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 订阅对话触发事件
	EventBus.dialogue_triggered.connect(_on_dialogue_triggered)


# ─────────────────────────────────────────────
# 事件触发
# ─────────────────────────────────────────────

func _on_dialogue_triggered(speaker_name: String, lines: Array) -> void:
	if lines.is_empty():
		return
	_lines = lines
	_current_line = 0
	speaker_label.text = speaker_name
	panel.visible = true
	GameStateManager.change_state(GameStateManager.GameState.DIALOGUE)
	_show_line(_lines[0])


# ─────────────────────────────────────────────
# 对话逻辑
# ─────────────────────────────────────────────

func _show_line(text: String) -> void:
	_full_text = text
	_displayed_chars = 0
	_is_typing = true
	_type_timer = 0.0
	text_label.text = ""
	if continue_hint:
		continue_hint.text = "..."


func _process(delta: float) -> void:
	if not _is_typing:
		return
	
	# 使用真实时间（PROCESS_MODE_ALWAYS 确保 time_scale=0 时仍然更新）
	_type_timer += delta
	var chars_to_show = int(_type_timer * TYPE_SPEED)
	
	if chars_to_show > _displayed_chars:
		_displayed_chars = min(chars_to_show, _full_text.length())
		text_label.text = _full_text.substr(0, _displayed_chars)
	
	if _displayed_chars >= _full_text.length():
		_is_typing = false
		if continue_hint:
			continue_hint.text = "按 [空格/Enter] 继续"


func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible:
		return
	
	var is_advance = (event is InputEventKey and 
		(event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_F) and
		event.pressed)
	
	if not is_advance:
		return
	
	get_viewport().set_input_as_handled()
	
	if _is_typing:
		# 快速完成当前行
		_displayed_chars = _full_text.length()
		text_label.text = _full_text
		_is_typing = false
		if continue_hint:
			continue_hint.text = "按 [空格/Enter] 继续"
		return
	
	# 前进到下一行
	_current_line += 1
	if _current_line < _lines.size():
		_show_line(_lines[_current_line])
	else:
		_close_dialogue()


func _close_dialogue() -> void:
	panel.visible = false
	_lines.clear()
	GameStateManager.change_state(GameStateManager.GameState.PLAYING)
	EventBus.dialogue_finished.emit()
