## GameStateManager.gd
## 全局游戏状态管理器（单例）
## 控制游戏的整体状态流转（主菜单→选角→加载→游玩→对话→结算）

extends Node

# ─────────────────────────────────────────────
# 游戏状态枚举
# ─────────────────────────────────────────────
enum GameState {
	MAIN_MENU,    # 标题/主菜单界面
	CHARACTER_SELECT,  # 角色选择界面
	LOAD_LEVEL,   # 加载/生成地图中
	PLAYING,      # 正常游玩状态
	DIALOGUE,     # 对话/剧情状态（时间冻结）
	SHOP,         # 商店界面
	GAME_OVER,    # 游戏结束（角色死亡）
	CHAPTER_CLEAR # 章节通关
}

# 当前游戏状态
var current_state: GameState = GameState.MAIN_MENU

# 玩家选择的角色ID
var selected_character_id: String = ""

# 玩家当前金币数量
var player_gold: int = 50

# 第一章进度变量
var chapter1_vars: Dictionary = {
	"is_started": false,
	"talked_to_village_chief": false,
	"quest_accepted": false,
	"kill_count": 0,
	"kill_target": 5,
	"chapter_complete": false
}


# ─────────────────────────────────────────────
# 状态切换
# ─────────────────────────────────────────────

func change_state(new_state: GameState) -> void:
	var old_state = current_state
	current_state = new_state
	
	print("[GameStateManager] 状态切换: %s → %s" % [
		GameState.keys()[old_state], 
		GameState.keys()[new_state]
	])
	
	EventBus.game_state_changed.emit(old_state, new_state)
	_on_state_entered(new_state)


func _on_state_entered(state: GameState) -> void:
	match state:
		GameState.PLAYING:
			# 恢复游戏时间
			Engine.time_scale = 1.0
		GameState.DIALOGUE:
			# 对话时冻结游戏逻辑（但UI仍然响应）
			Engine.time_scale = 0.0
		GameState.SHOP:
			Engine.time_scale = 0.0
		GameState.GAME_OVER:
			Engine.time_scale = 0.0
		GameState.CHAPTER_CLEAR:
			Engine.time_scale = 0.0
			EventBus.chapter_completed.emit(1)


# ─────────────────────────────────────────────
# 便捷判断方法
# ─────────────────────────────────────────────

func is_playing() -> bool:
	return current_state == GameState.PLAYING

func is_in_dialogue() -> bool:
	return current_state == GameState.DIALOGUE

func is_in_shop() -> bool:
	return current_state == GameState.SHOP


# ─────────────────────────────────────────────
# 角色选择
# ─────────────────────────────────────────────

func select_character(char_id: String) -> void:
	selected_character_id = char_id
	print("[GameStateManager] 玩家选择角色: " + char_id)
	change_state(GameState.LOAD_LEVEL)


# ─────────────────────────────────────────────
# 金币管理
# ─────────────────────────────────────────────

func add_gold(amount: int) -> void:
	player_gold += amount
	EventBus.gold_changed.emit(player_gold)

func spend_gold(amount: int) -> bool:
	if player_gold >= amount:
		player_gold -= amount
		EventBus.gold_changed.emit(player_gold)
		return true
	return false  # 金币不足


# ─────────────────────────────────────────────
# 第一章进度管理
# ─────────────────────────────────────────────

func update_kill_count() -> void:
	chapter1_vars["kill_count"] += 1
	var count = chapter1_vars["kill_count"]
	var target = chapter1_vars["kill_target"]
	EventBus.quest_updated.emit("kill_monsters", {"count": count, "target": target})
	
	if count >= target and not chapter1_vars["chapter_complete"]:
		chapter1_vars["chapter_complete"] = true
		change_state(GameState.CHAPTER_CLEAR)


func set_chapter1_var(key: String, value) -> void:
	chapter1_vars[key] = value
