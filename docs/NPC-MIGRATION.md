# NPC 迁移指南：ServersNPC → ZNPCsPlus

## 背景

v1.1.0 已将 NPC 插件从 ServersNPC 迁移至 ZNPCsPlus 2.0.0。
旧 ServersNPC 数据目录已移除，以下为旧 NPC 数据记录，需在游戏中通过 ZNPCsPlus 命令重建。

## 旧 NPC 数据（来自 lobby/plugins/ServersNPC/data.json）

### NPC 1: 2b2t 特色区入口

| 属性 | 值 |
|------|-----|
| 位置 | world, (-71.5, 119, -41.5) |
| 朝向 | yaw=-9.83, pitch=90 |
| 皮肤 | BedRock (base64 编码) |
| 全息文字 | "点我进入2b2t特色区" |
| 点击动作 | SERVER → "2b2t" |
| NPC类型 | PLAYER |
| 注视玩家 | 是 |

### NPC 2: 起床战争入口

| 属性 | 值 |
|------|-----|
| 位置 | world, (-68.5, 119, -45.5) |
| 朝向 | yaw=-73.73, pitch=90 |
| 皮肤 | GrassBlock (base64 编码) |
| 全息文字 | "点我进入起床战争(无反作弊)" |
| 点击动作 | SERVER → "BW" |
| NPC类型 | PLAYER |
| 注视玩家 | 是 |

### NPC 3: 宵禁周入口

| 属性 | 值 |
|------|-----|
| 位置 | world, (-75.5, 119, -41.5) |
| 朝向 | yaw=-174.08, pitch=-8.25 |
| 皮肤 | Steve (默认皮肤) |
| 全息文字 | "&6宵——禁——周" |
| 点击动作 | SERVER → "xiaojin" |
| NPC类型 | PLAYER |
| 注视玩家 | 是 |

## 重建步骤

1. 启动大厅服务器并进入游戏
2. 使用 ZNPCsPlus 命令创建 NPC：

```
# NPC 1: 2b2t 特色区
/npc create BedRock PLAYER -71.5 119 -41.5 world
/npc set hologram 1 "点我进入2b2t特色区"
/npc set action SERVER "2b2t"
/npc set look

# NPC 2: 起床战争
/npc create GrassBlock PLAYER -68.5 119 -45.5 world
/npc set hologram 1 "点我进入起床战争(无反作弊)"
/npc set action SERVER "BW"
/npc set look

# NPC 3: 宵禁周
/npc create Steve PLAYER -75.5 119 -41.5 world
/npc set hologram 1 "&6宵——禁——周"
/npc set action SERVER "xiaojin"
/npc set look
```

3. 验证每个 NPC 可见、可点击、动作正确
4. ZNPCsPlus 会自动保存配置到 `lobby/plugins/ZNPCsPlus/`

## 皮肤迁移说明

- NPC 1 (BedRock) 和 NPC 2 (GrassBlock) 的旧皮肤数据为 base64 编码的 Minecraft texture。
- ZNPCsPlus 支持通过玩家名称设置皮肤，因此用 `/npc create <skinName> PLAYER` 即可。
- 如需使用原始 base64 texture，可通过 ZNPCsPlus 的皮肤设置命令另行配置。

## 清理确认

- [x] `lobby/plugins/ServersNPC/` 已删除
- [x] `2b2t/plugins/ServersNPC/` 已删除
- [x] PLUGINS.md 已更新
