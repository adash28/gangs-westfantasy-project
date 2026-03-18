# 🗡️ 勇者传说 - 中世纪西幻 Rogue-Like Demo

## 版本：v1.0.2

一个基于 Godot 4.x 的 2D 像素风 Rogue-Like 游戏 Demo，以中世纪西方奇幻为背景。

---

## 🎮 游戏控制

| 按键 | 功能 |
|------|------|
| WASD | 移动 |
| 鼠标左键 / J | 攻击 |
| F | 交互 / 拾取地面物品 |
| E | 打开/关闭背包 |
| Q | 开关附近的门 |
| H | 使用血瓶（需背包中有） |
| B | 使用蓝瓶（需背包中有） |
| 鼠标滚轮 | 切换武器 |
| ESC | 关闭商店 |

---

## ✅ v1.0.2 新增与修复

### 地图系统
- **封闭边界**：地图四周实心墙，不可走出边界
- **教堂**：有讲台+椅子障碍物，神父被限制在教堂内活动
- **民宅**：有床+柜子障碍物，村民在周围巡逻
- **墓地**：围栏+墓碑障碍物，不死者生成于墓地
- **门系统**：教堂和民宅有门，按 Q 键开/关
- **地图扩大**：100×100 格地图（原来60×60）
- **分辨率**：1920×1080

### 人物系统
- **像素小人**：16×24 像素，有头部/身体/腿，各角色颜色不同
  - 村民：灰衣棕裤
  - 商人：黄色外套绿裤
  - 神父：白袍
  - 哥布林：绿皮褐衣
  - 不死者：灰白皮肤黑袍

### 背包系统（新增）
- 5×5 方格，最多 25 物品
- E 键打开/关闭
- F 键拾取地面物品放入背包
- 点击背包内药水直接使用

### 武器系统（增强）
- 鼠标滚轮切换武器，头顶白字提示武器名
- 武器重量影响击退力度（斧5、剑4、砍刀3、匕首1）
- 武器图标显示在角色前方
- 近战攻击触发白色弧线挥击特效

### 射弹系统（新增）
- 神父/圣杖发射**黄色像素格子射弹**
- 两种消失方式：碰墙消失、击中角色消失
- 射弹命中有爆炸粒子特效

### 打击感
- 击退碰墙后弹回（碰撞反弹）
- 受击变红僵直 0.3 秒
- 死亡击飞效果
- 尸体被打 3 次后爆裂

### Bug 修复
- ✅ **商人折扣**：只有选择商人角色时才享受 30% 折扣
- ✅ **NPC 血条**：白色当前血量 + 暗红背景，血量低时变黄/橙
- ✅ **药水使用**：H/B 键使用，也可在背包点击使用
- ✅ **购买入背包**：商店购买的药水进入背包，而非立即使用
- ✅ **怪物血量**：大幅提高（哥布林200HP，不死者150HP）
- ✅ **A* 寻路**：NPC 使用 BFS 寻路，避免卡在障碍物

### NPC 系统
- 神父限制在教堂内活动
- 雇佣村民后可离开房间跟随玩家
- A* 路径寻路，3 只哥布林上限，2-3 只不死者在墓地

---

## 📁 项目结构

```
roguelike_demo/
├── data/
│   ├── characters/characters.json    # 角色数据（含颜色配置）
│   └── items/items.json              # 武器/物品数据（含weight）
├── scenes/
│   ├── Main.tscn                     # 角色选择入口
│   ├── GameLevel.tscn                # 游戏主场景
│   ├── Player.tscn                   # 玩家场景
│   ├── NPC.tscn                      # NPC场景
│   └── Projectile.tscn               # 射弹场景
└── scripts/
    ├── autoload/                     # 单例系统
    │   ├── EventBus.gd               # 事件总线
    │   ├── DataManager.gd            # 数据管理
    │   ├── GameStateManager.gd       # 游戏状态
    │   └── FactionSystem.gd          # 阵营系统
    ├── entities/
    │   ├── BaseCharacter.gd          # 角色基类（v1.1）
    │   ├── Player.gd                 # 玩家（v1.1）
    │   ├── NPC.gd                    # NPC（v1.1）
    │   ├── Projectile.gd             # 射弹（v1.1）
    │   └── DroppedItem.gd            # 掉落物（新增）
    ├── states/
    │   ├── HitStunState.gd           # 受击僵直（含碰撞弹回）
    │   ├── IdleState.gd
    │   ├── MoveState.gd
    │   ├── AttackState.gd
    │   └── DeadState.gd
    ├── systems/
    │   ├── MapGenerator.gd           # 地图生成器（v1.1）
    │   ├── PlaceholderSpriteGenerator.gd  # 像素小人生成器（v1.1）
    │   ├── StateMachine.gd           # 状态机
    │   ├── InventorySystem.gd        # 背包系统（新增）
    │   └── DoorController.gd         # 门控制器（新增）
    └── ui/
        ├── HUD.gd                    # HUD（v1.1）
        ├── InventoryUI.gd            # 背包界面（新增）
        ├── NPCHealthBar.gd           # NPC血条（修复）
        ├── ShopUI.gd                 # 商店（修复折扣Bug）
        ├── DialogueBox.gd
        └── CharacterSelectUI.gd
```

---

## 🚀 运行方法

1. 使用 **Godot 4.2+** 打开项目文件夹
2. 打开 `project.godot`
3. 按 F5 运行（或点击播放按钮）

---

## 🔮 后续开发建议

- [ ] 导入真实像素艺术素材（推荐 [itch.io](https://itch.io/game-assets) 搜索 "pixel RPG free"）
- [ ] 添加音效（[freesound.org](https://freesound.org)）
- [ ] 第二章：走出村庄进入森林/地下城
- [ ] 更多角色技能（战士冲刺、神父群体治疗等）
- [ ] 随机 Boss 房间
- [ ] 存档系统

---

## 📦 免费素材资源推荐

**像素角色精灵：**
- https://itch.io/game-assets/tag-pixel-art/tag-characters → 搜索 "RPG character"
- https://opengameart.org/content/2d-rpg-character-set → CC0 授权

**地图瓦片集：**
- https://itch.io/game-assets/tag-pixel-art/tag-tileset → 搜索 "dungeon tileset"
- https://kenney.nl/assets/roguelike-rpg-pack → CC0 授权

**音效：**
- https://freesound.org → 搜索 "sword swing", "footstep", "magic"

---

*最后更新：v1.0.2 | 框架已完成，可直接在 Godot 4.2+ 运行*
