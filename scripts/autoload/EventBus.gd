## EventBus.gd
## 全局事件总线（观察者模式）v1.0.2
## 新增：打击感信号、射弹信号、背包信号

extends Node

# ─────────────────────────────────────────────
# 战斗相关事件
# ─────────────────────────────────────────────
signal entity_attacked(attacker, target, damage)
signal entity_died(entity, killer)
signal hp_changed(entity, new_hp, max_hp)
signal mp_changed(entity, new_mp, max_mp)

# ─────────────────────────────────────────────
# 打击感相关事件 (v1.0.2)
# ─────────────────────────────────────────────
signal play_sound(sound_name, position)
signal blood_splatter(position)
signal swing_effect(position, direction)

# ─────────────────────────────────────────────
# 射弹相关事件 (v1.0.2)
# ─────────────────────────────────────────────
signal projectile_fired(from_pos, direction, weapon_data, shooter)

# ─────────────────────────────────────────────
# 阵营与关系事件
# ─────────────────────────────────────────────
signal relation_changed(entity, new_relation)
signal npc_hired(npc, player)

# ─────────────────────────────────────────────
# 游戏流程事件
# ─────────────────────────────────────────────
signal game_state_changed(old_state, new_state)
signal level_loaded(level_name)
signal dialogue_triggered(speaker_name, lines)
signal dialogue_finished()
signal trigger_activated(trigger_id)

# ─────────────────────────────────────────────
# 物品与交互事件
# ─────────────────────────────────────────────
signal gold_changed(new_amount)
signal item_picked_up(item_data)
signal shop_opened(merchant_node)
signal shop_closed()
signal weapon_durability_changed(entity, durability, max_durability)
signal weapon_broken(entity, weapon_id)

# ─────────────────────────────────────────────
# 背包系统事件 (v1.0.2)
# ─────────────────────────────────────────────
signal inventory_changed()
signal weapon_switched(entity, weapon_data)

# ─────────────────────────────────────────────
# 任务系统事件
# ─────────────────────────────────────────────
signal quest_updated(quest_id, status)
signal chapter_completed(chapter_num)
