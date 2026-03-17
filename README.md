# 🗡️ Rogue-like Demo — 中世纪西幻勇者传说

> 2D 像素风 Rogue-like 游戏 —— 基础框架 + 第一章 Demo
> 引擎：**Godot 4.2+**  |  语言：**GDScript**

---

## 📂 项目结构

```
roguelike_demo/
├── project.godot                   # Godot 项目配置（含 AutoLoad 注册）
├── scenes/
│   ├── Main.tscn                   # 入口场景（角色选择）
│   ├── GameLevel.tscn              # 游戏主关卡场景
│   ├── Player.tscn                 # 玩家角色场景
│   └── NPC.tscn                    # NPC 通用场景（友好/敌对共用）
├── scripts/
│   ├── GameLevel.gd                # 关卡主控（地图生成 + 实体生成）
│   ├── autoload/                   # 全局单例（AutoLoad）
│   │   ├── EventBus.gd             # 事件总线（观察者模式）
│   │   ├── DataManager.gd          # 数据管理器（读 JSON 配置）
│   │   ├── FactionSystem.gd        # 阵营关系系统
│   │   └── GameStateManager.gd     # 游戏状态机（菜单/游玩/对话…）
│   ├── entities/
│   │   ├── BaseCharacter.gd        # 所有角色基类
│   │   ├── Player.gd               # 玩家控制逻辑
│   │   └── NPC.gd                  # NPC AI + 交互逻辑
│   ├── states/                     # 有限状态机各状态
│   │   ├── BaseState.gd
│   │   ├── IdleState.gd
│   │   ├── MoveState.gd
│   │   ├── AttackState.gd
│   │   └── DeadState.gd
│   ├── systems/
│   │   ├── StateMachine.gd         # 通用有限状态机
│   │   ├── MapGenerator.gd         # BSP 随机地图生成器
│   │   └── PlaceholderSpriteGenerator.gd  # 占位色块精灵生成器
│   ├── ui/
│   │   ├── HUD.gd                  # 血条/魔力/金币/任务 HUD
│   │   ├── DialogueBox.gd          # 对话框（逐字打印）
│   │   ├── ShopUI.gd               # 商店界面
│   │   ├── CharacterSelectUI.gd    # 角色选择界面
│   │   └── NPCHealthBar.gd         # NPC 头顶血条
│   └── chapter1/
│       └── Chapter1Manager.gd      # 第一章剧情触发器
└── data/
    ├── characters/characters.json  # 角色 + 技能配置表
    └── items/items.json            # 武器 + 商店物品配置表
```

---

## ✅ 已完成功能

### 🏗️ 核心框架
| 模块 | 说明 |
|------|------|
| **DataManager** | 启动时加载全部 JSON 配置到内存，提供 `get_character()` `get_weapon()` 等查询接口 |
| **EventBus** | 全局信号总线，解耦各系统通信（攻击、死亡、对话、金币变化等 15+ 信号） |
| **FactionSystem** | 阵营矩阵 + 个体关系覆盖表，支持 `忠诚/同盟/仇恨/中立` 四种关系 |
| **GameStateManager** | 全局状态机（主菜单→选角→加载→游玩→对话→商店→游戏结束） |
| **StateMachine** | 通用 FSM，角色挂载后自动收集子状态节点 |

### 👤 实体系统
| 类 | 说明 |
|----|------|
| **BaseCharacter** | HP/MP/攻击/速度/武器耐久度，被动技能处理（咏唱自动回蓝）|
| **Player** | WASD 移动，鼠标/J 攻击，F 交互，击杀掉落金币，任务计数 |
| **NPC** | AI 决策循环（巡逻→追击→攻击），感知范围检测，阵营响应，雇佣/商店交互 |

### 🗺️ 随机地图
- **BSP 二叉空间分割**算法生成 60×60 格随机关卡
- 自动连通走廊（L形），宽度2格
- 锚点建筑放置（酒馆/商店固定位置）
- 地形细节（树木/石头随机填充）
- **NPC 自动生成**：前两个房间放友好NPC，后续房间生成怪物（1~3只）

### 🎭 角色设定（来自文档）
**可选玩家角色：**
- 🪓 村民（HP100，斧头，可雇佣NPC）
- 💰 商人（HP80，砍刀，老谋深算打折技能）
- ⛪ 神父（HP80，MP100，圣杖，咏唱自动回蓝）

**怪物：**
- 👺 哥布林（HP60，速度快，匕首）
- 💀 不死者（HP30，高攻击，弱于圣杖/匕首）

### 🎮 第一章剧情
1. 开场旁白介绍世界观
2. 村长对话 → 接受消灭5只魔物任务
3. 雇佣村民（20金），在商人/神父处买补给
4. 击杀满5只魔物 → 通关对话 + 奖励100金币

---

## 🎮 操作说明

| 按键 | 功能 |
|------|------|
| **WASD / 方向键** | 移动 |
| **鼠标左键 / J** | 攻击（自动锁定最近敌人） |
| **F** | 交互（与NPC对话/雇佣/开商店） |
| **空格 / Enter** | 对话框继续 |
| **ESC** | 关闭商店 |

---

## 🚀 如何运行

### 环境要求
- **Godot Engine 4.2 或更高版本**（免费下载：https://godotengine.org）

### 步骤
```bash
# 1. 下载/安装 Godot 4.2+
# 2. 打开 Godot，点击「导入项目」
# 3. 选择 roguelike_demo/project.godot
# 4. 点击「运行」（F5）即可
```

> ⚠️ **无需任何美术资源**：项目内置 `PlaceholderSpriteGenerator`，会自动用纯色方块代替精灵和地图贴图，框架逻辑可完整运行。

---

## 🔧 扩展指南

### 替换占位美术
1. 在 `assets/sprites/` 下放置像素精灵图
2. 在 `GameLevel.gd` 中注释掉 `PlaceholderSpriteGenerator.setup_sprite()` 调用
3. 改用 `AnimatedSprite2D` 直接加载你的精灵资源

### 新增角色
1. 在 `data/characters/characters.json` 的 `characters` 节点中添加新角色对象
2. 将 `is_player_class` 设为 `true` 即可在角色选择界面自动出现
3. 无需修改任何 GDScript 代码

### 新增地图房间建筑
在 `MapGenerator._place_anchor_buildings()` 中调用 `_mark_building()` 即可

### 新增技能
1. 在 `characters.json` 的 `skills` 节点添加技能定义
2. 在 `BaseCharacter._process_passive_skills()` 中添加被动技能处理
3. 主动技能在 `Player._try_attack()` 或 `NPC._ai_tick()` 中扩展

---

## 📋 待实现（下一步）

- [ ] 真实像素美术资源（角色/地图贴图）
- [ ] A* 寻路系统（当前 NPC 使用直线追击）
- [ ] 背包系统（物品拾取/装备切换）
- [ ] 更多技能（主动技能：冲锋/治愈术等）
- [ ] 存档系统
- [ ] 第二章地图（地牢/魔王城）
- [ ] 音效与背景音乐
- [ ] 玩家攻击动画（招式特效）

---

## 🏗️ 架构设计要点

```
AutoLoad单例（全局）
  ├── EventBus          ← 所有系统通信枢纽（解耦）
  ├── DataManager       ← 配置数据只读内存缓存
  ├── FactionSystem     ← 阵营矩阵 + 个体覆盖
  └── GameStateManager  ← 游戏流程状态机

场景树（运行时）
  GameLevel
  ├── World
  │   ├── TileMapLayer  ← BSP地图渲染
  │   ├── NPCContainer  ← 所有NPC节点
  │   └── PlayerContainer ← 玩家节点
  ├── MapGenerator      ← 地图生成器（纯逻辑节点）
  ├── Chapter1Manager   ← 触发器驱动的剧情系统
  ├── HUD (CanvasLayer) ← 血条/金币/任务显示
  ├── DialogueBox       ← 对话框UI（layer=5）
  └── ShopUI            ← 商店UI（layer=6）
```

> 每个实体（Player/NPC）自带 `StateMachine` 子节点，
> 状态切换通过 `state_machine.transition_to("StateName")` 完成，完全解耦。
