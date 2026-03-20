## Chapter1Manager.gd
## 第一章剧情管理器：包含触发器系统 + 第一章全部业务逻辑
## 挂载在 GameLevel 场景中，通过 Area2D 触发器驱动
##
## 第一章流程：
##   1. 玩家进入村庄 → 村长对话 → 接受任务（消灭5个魔物）
##   2. 玩家可雇佣村民、在商人/神父处购物
##   3. 击杀足够魔物 → 触发通关对话 → 章节结束

extends Node

# ─────────────────────────────────────────────
# 触发器记录（防止重复触发）
# ─────────────────────────────────────────────
var _triggered: Dictionary = {}

# GameLevel 中的关键节点引用（由 GameLevel._ready() 赋值）
var player_node: Player = null
var hud_node: Node = null


# ─────────────────────────────────────────────
# 初始化
# ─────────────────────────────────────────────

func _ready() -> void:
	EventBus.quest_updated.connect(_on_quest_updated)
	EventBus.npc_hired.connect(_on_npc_hired)
	EventBus.entity_died.connect(_on_entity_died)
	
	# 延迟1帧后触发开场白（等待地图和玩家就绪）
	await get_tree().process_frame
	await get_tree().process_frame
	_trigger_intro()


# ─────────────────────────────────────────────
# 触发器核心方法
# ─────────────────────────────────────────────

## 激活一个触发器（id 相同的只触发一次）
func activate_trigger(trigger_id: String) -> void:
	if _triggered.get(trigger_id, false):
		return
	_triggered[trigger_id] = true
	EventBus.trigger_activated.emit(trigger_id)
	_handle_trigger(trigger_id)
	print("[Chapter1] 触发器激活: " + trigger_id)


func _handle_trigger(trigger_id: String) -> void:
	match trigger_id:
		"intro":
			_trigger_intro()
		"village_chief_talk":
			_trigger_village_chief_talk()
		"quest_start":
			_trigger_quest_start()
		"chapter_complete":
			_trigger_chapter_complete()
		"first_kill":
			_trigger_first_kill_comment()


# ─────────────────────────────────────────────
# 第一章剧情节点
# ─────────────────────────────────────────────

func _trigger_intro() -> void:
	if _triggered.get("intro", false):
		return
	_triggered["intro"] = true
	
	# 开场白（延迟0.5秒，让玩家看清地图）
	await get_tree().create_timer(0.8).timeout
	EventBus.dialogue_triggered.emit("旁白", [
		"中世纪西幻大陆，魔物横行，村庄告急……",
		"勇者，你的旅程从这片村庄开始。",
		"（提示：WASD移动，鼠标左键/J攻击，F键交互，ESC关闭商店）"
	])
	
	# 对话结束后，触发村长接触
	await EventBus.dialogue_finished
	await get_tree().create_timer(0.5).timeout
	activate_trigger("village_chief_talk")


func _trigger_village_chief_talk() -> void:
	if not GameStateManager.chapter1_vars.get("talked_to_village_chief", false):
		GameStateManager.set_chapter1_var("talked_to_village_chief", true)
	
	EventBus.dialogue_triggered.emit("村长", [
		"勇者！终于等到你了！",
		"魔物近日频繁袭击我们的村庄，村民们人心惶惶。",
		"你能帮我们消灭附近的魔物吗？据报告至少有5只在附近徘徊。",
		"（任务更新：消灭魔物 0/5）"
	])
	
	await EventBus.dialogue_finished
	activate_trigger("quest_start")


func _trigger_quest_start() -> void:
	GameStateManager.set_chapter1_var("quest_accepted", true)
	GameStateManager.set_chapter1_var("is_started", true)
	
	# 强制刷新任务计数显示
	EventBus.quest_updated.emit("kill_monsters", {
		"count": GameStateManager.chapter1_vars.get("kill_count", 0),
		"target": GameStateManager.chapter1_vars.get("kill_target", 5)
	})
	
	print("[Chapter1] 任务开始：消灭魔物 0/5")


func _trigger_first_kill_comment() -> void:
	# 第一次击杀怪物时的旁白鼓励
	EventBus.dialogue_triggered.emit("旁白", [
		"干得好！继续消灭更多魔物！",
		"（提示：附近的村民可以雇佣，花费20金币）"
	])


func _trigger_chapter_complete() -> void:
	EventBus.dialogue_triggered.emit("村长", [
		"太好了！魔物已被驱散！",
		"你是真正的勇者！村民们因你而得救。",
		"带上这些报酬，继续你的旅程吧……",
		"（第一章完成！感谢游玩 Demo！）"
	])
	# 奖励金币
	GameStateManager.add_gold(100)


# ─────────────────────────────────────────────
# 事件响应
# ─────────────────────────────────────────────

func _on_quest_updated(quest_id: String, data: Dictionary) -> void:
	if quest_id != "kill_monsters":
		return
	
	var count = data.get("count", 0)
	var target = data.get("target", 5)
	
	# 第一次击杀时触发鼓励旁白
	if count == 1 and not _triggered.get("first_kill", false):
		activate_trigger("first_kill")
	
	# 任务完成
	if count >= target and not _triggered.get("chapter_complete", false):
		activate_trigger("chapter_complete")


func _on_npc_hired(npc: Node, _player: Node) -> void:
	# 雇佣 NPC 后的提示（只提示一次）
	if not _triggered.get("first_hire", false):
		_triggered["first_hire"] = true
		await get_tree().create_timer(0.3).timeout
		EventBus.dialogue_triggered.emit("旁白", [
			npc.display_name + " 加入了你的队伍！",
			"同盟单位会在你受到攻击时协助战斗。"
		])


func _on_entity_died(entity: Node, _killer: Node) -> void:
	# 玩家死亡 → 游戏结束
	if entity is Player:
		await get_tree().create_timer(0.5).timeout
		EventBus.dialogue_triggered.emit("旁白", [
			"你倒下了……",
			"（游戏结束，感谢游玩 Demo！）"
		])
