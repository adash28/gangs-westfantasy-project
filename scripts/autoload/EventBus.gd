## EventBus.gd
## 全局事件总线（观察者模式）
## 作为 AutoLoad 单例加载，所有系统都可以通过它发布/订阅事件
## 使用方法:
##   发布: EventBus.entity_attacked.emit(attacker, target, damage)
##   订阅: EventBus.entity_attacked.connect(_on_entity_attacked)

extends Node

# ─────────────────────────────────────────────
# 战斗相关事件
# ─────────────────────────────────────────────

## 实体受到攻击时触发
## attacker: 攻击者节点, target: 目标节点, damage: 伤害量
signal entity_attacked(attacker, target, damage)

## 实体死亡时触发
## entity: 死亡的实体, killer: 击杀者
signal entity_died(entity, killer)

## 实体生命值变化时触发（用于刷新UI）
## entity: 实体节点, new_hp: 新血量, max_hp: 最大血量
signal hp_changed(entity, new_hp, max_hp)

## 实体魔力值变化时触发
signal mp_changed(entity, new_mp, max_mp)

# ─────────────────────────────────────────────
# 阵营与关系事件
# ─────────────────────────────────────────────

## 阵营关系发生变化时触发
## entity: 实体, new_relation: 新关系枚举值
signal relation_changed(entity, new_relation)

## NPC 被雇佣时触发
signal npc_hired(npc, player)

# ─────────────────────────────────────────────
# 游戏流程事件
# ─────────────────────────────────────────────

## 游戏状态切换
signal game_state_changed(old_state, new_state)

## 关卡加载完成
signal level_loaded(level_name)

## 对话触发
## speaker_name: 说话者名字, lines: 对话文本数组
signal dialogue_triggered(speaker_name, lines)

## 对话结束
signal dialogue_finished()

## 触发器激活
signal trigger_activated(trigger_id)

# ─────────────────────────────────────────────
# 物品与交互事件
# ─────────────────────────────────────────────

## 玩家获得金币
signal gold_changed(new_amount)

## 玩家拾取物品
signal item_picked_up(item_data)

## 打开商店
signal shop_opened(merchant_node)

## 关闭商店
signal shop_closed()

## 武器耐久度变化
signal weapon_durability_changed(entity, durability, max_durability)

## 武器损坏
signal weapon_broken(entity, weapon_id)

# ─────────────────────────────────────────────
# 音效与特效事件
# ─────────────────────────────────────────────

## 播放音效
## sound_name: 音效名称, position: 播放位置
signal play_sound(sound_name, position)

## 血液飞溅效果
## position: 飞溅位置
signal blood_splatter(position)

# ─────────────────────────────────────────────
# 任务系统事件（第一章用）
# ─────────────────────────────────────────────

## 任务更新
signal quest_updated(quest_id, status)

## 章节完成
signal chapter_completed(chapter_num)
