# 打击感增强功能 - 修改总结

## 需求概述
参照地痞街区（Streets of Rogue）增强游戏打击感，包括：
1. 被攻击后和攻击敌人后将受攻击的一方击退
2. 让对方变红、僵直
3. 角色死亡时会有飞出去的效果
4. 尸体被打击三下后爆裂，溅出红色番茄汁特效

## 修改原则
- 不修改原本正确能跑的代码
- 修改部分可以轻松debug和回退
- 使用模块化设计，便于扩展和维护

## 新增文件
### 1. `scripts/states/HitStunState.gd`
- 新增受击僵直状态
- 功能：播放受击动画、变红效果、击退效果
- 僵直持续时间：0.3秒
- 击退衰减系数：0.9

## 修改的文件
### 1. `scripts/entities/BaseCharacter.gd`
#### 新增变量
- `KNOCKBACK_FORCE = 400.0` - 击退基本力度
- `KNOCKBACK_DECAY = 0.85` - 击退衰减系数
- `_knockback_velocity` - 击退速度向量
- `_is_in_hit_stun` - 是否处于僵直状态
- `_corpse_hit_count` - 尸体被攻击次数
- `_death_knockback` - 死亡击飞速度

#### 新增方法
- `_apply_knockback(attacker)` - 应用击退效果
- `_enter_hit_stun()` - 进入受击僵直状态
- `clear_knockback()` - 清除击退效果
- `_corpse_hit(attacker)` - 处理尸体被攻击
- `_play_corpse_hit_effect()` - 播放尸体受击特效
- `_restore_corpse_color()` - 恢复尸体颜色
- `_explode_corpse()` - 尸体爆裂效果
- `_create_blood_splatter()` - 创建血液飞溅特效

#### 修改的方法
- `take_damage()` - 增加击退和僵直效果调用，区分活体/尸体处理
- `die()` - 增加死亡击飞效果和尸体计数重置

### 2. `scripts/autoload/EventBus.gd`
#### 新增信号
- `play_sound(sound_name, position)` - 播放音效
- `blood_splatter(position)` - 血液飞溅效果

## 功能说明
### 1. 击退效果
- 计算方向：从攻击者指向被攻击者
- 力度调整：考虑武器重量（如果武器数据包含weight属性）
- 状态传递：通过meta数据传递给HitStunState

### 2. 变红和僵直效果
- 变红：通过修改`AnimatedSprite2D.modulate`为红色
- 僵直：进入HitStunState状态，持续0.3秒无法行动
- 恢复：退出状态时恢复白色

### 3. 死亡击飞效果
- 力度：普通击退的1.5倍
- 方向：从击杀者指向被击杀者
- 存储：在`_death_knockback`变量中

### 4. 尸体爆裂特效
- 计数：尸体被攻击3次后爆裂
- 效果：红色闪烁、血液飞溅事件、隐藏尸体、延迟移除
- 事件：通过EventBus.blood_splatter发射位置信息

## Debug和测试建议
### 1. 日志输出
- 受击时：查看控制台输出的击退信息
- 死亡时：查看死亡击飞计算
- 尸体爆裂：查看爆裂日志和血液飞溅位置

### 2. 可视化调试
- 击退方向：可在`_apply_knockback`中添加调试绘制
- 状态切换：观察状态机当前状态变化
- 颜色变化：观察精灵颜色调制

### 3. 参数调整
- 击退力度：调整`KNOCKBACK_FORCE`常量
- 僵直时间：调整`HIT_STUN_DURATION`常量
- 爆裂次数：调整`_corpse_hit_count`判断条件

## 回退方案
### 完整回退
1. 删除`scripts/states/HitStunState.gd`
2. 恢复`scripts/entities/BaseCharacter.gd`到原始版本
3. 恢复`scripts/autoload/EventBus.gd`到原始版本
4. 从状态机中移除HitStunState引用

### 部分回退
1. 只禁用击退：设置`KNOCKBACK_FORCE = 0`
2. 只禁用僵直：不切换到HitStunState状态
3. 只禁用尸体效果：注释`_corpse_hit`相关调用

## 已知限制
1. 缺少音效资源：play_sound信号需要音频系统支持
2. 缺少血液飞溅特效：blood_splatter信号需要粒子系统实现
3. 动画依赖：需要"hit"动画帧，否则使用变红效果替代
4. 武器重量：需要武器数据包含weight属性才能调整击退力度

## 扩展建议
1. 添加击退阻力：不同角色/装备有不同击退抗性
2. 添加屏幕震动：大幅击退时触发屏幕震动
3. 添加打击停顿：攻击命中时短暂时间停顿
4. 添加粒子特效：受击时产生火花/血液粒子
5. 添加音效多样化：不同武器/材质产生不同音效

## 文件备份
所有原始文件已通过版本控制保存，可通过git回退到修改前状态。
