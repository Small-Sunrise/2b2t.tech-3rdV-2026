# 2b2t.tech 插件清单

> 核心: Leaf 26.2-37 | 更新日期: 2026-07-28

## Core

| 插件 | 版本 | 下载地址 |
|------|------|----------|
| Leaf | 26.2-37 | https://github.com/Winds-Studio/Leaf/releases/tag/ver-26.2 |

## ViaVersion Suite

| 插件 | 版本 | 来源 | 下载地址 |
|------|------|------|----------|
| ViaVersion | 5.11.0 | Modrinth | https://modrinth.com/plugin/viaversion |
| ViaBackwards | 5.11.0 | Modrinth | https://modrinth.com/plugin/viabackwards |
| ViaRewind | 4.1.3 | Modrinth | https://modrinth.com/plugin/viarewind |

这三个由 `scripts/fetch-jars.sh` 自动拉取（见 `scripts/jars.manifest`），无需手工下载：
lobby 是协议 775、2b2t 是协议 776，缺了 Via 就没有任何一个客户端协议能同时连上
两个后端。三个服务（VC / lobby / 2b2t）都要装，装的是同一份 universal jar。

## 基础依赖

| 插件 | 版本 | 来源 | 下载地址 |
|------|------|------|----------|
| ProtocolLib | 5.5.0-SNAPSHOT-589ee12 | GitHub dev-build | https://github.com/dmulloy2/ProtocolLib/releases/tag/dev-build |
| LuckPerms | 5.5.53 | Modrinth | https://modrinth.com/plugin/luckperms |
| PlaceholderAPI | 2.12.3 | GitHub | https://github.com/PlaceholderAPI/PlaceholderAPI/releases/tag/2.12.3 |
| Vault | 1.7.3 | GitHub | https://github.com/MilkBowl/Vault/releases |
| CMILib | 1.5.9.9 | GitHub | https://github.com/Zrips/CMILib/releases |

## 性能与分析

| 插件 | 版本 | 来源 | 下载地址 |
|------|------|------|----------|
| spark | latest | Modrinth | https://modrinth.com/plugin/spark |
| Plan | 5.7 build 3558 | Modrinth | https://modrinth.com/plugin/plan |
| Chunky | 1.5.3 | Modrinth | https://modrinth.com/plugin/chunky |
| LagFixer | 1.6.5 | Modrinth | https://modrinth.com/plugin/lagfixer |
| ChunkEntityLimiter | 1.3.1 | Modrinth | https://modrinth.com/plugin/chunkentitylimiter |
| ChunkDeleter | 1.2 | Modrinth | https://modrinth.com/plugin/chunkdeleter |

## 基础功能

| 插件 | 版本 | 来源 | 下载地址 |
|------|------|------|----------|
| EssentialsX | 2.22.0 | Modrinth | https://modrinth.com/plugin/essentialsx |
| WorldEdit | 7.4.4 | Modrinth | https://modrinth.com/plugin/worldedit |
| Residence | 6.0.0.1 | GitHub | https://github.com/Zrips/Residence/releases |
| QuickShop-Hikari | 6.2.0.11 | Modrinth | https://modrinth.com/plugin/quickshop-hikari |
| AdvancedTeleport | 6.2.0 | Modrinth | https://modrinth.com/plugin/advancedteleport |
| EnderChestVault | 1.0.0 | Modrinth | https://modrinth.com/plugin/enderchestvault |
| ShulkerBoxDrop | 1.0.0 | Modrinth | https://modrinth.com/plugin/shulkerboxdrop |

## 聊天与展示

| 插件 | 版本 | 来源 | 下载地址 |
|------|------|------|----------|
| TAB | 6.1.0 | GitHub | https://github.com/NEZNAMY/TAB/releases |
| TChat | 5.0.0-DEV-6 | Modrinth | https://modrinth.com/plugin/tchat |
| DecentHolograms | 2.10.1 | Modrinth | https://modrinth.com/plugin/decentholograms |
| DeluxeTags | 1.8.3 | Modrinth | https://modrinth.com/plugin/deluxetags |
| Skript | 2.15.4 | Modrinth | https://modrinth.com/plugin/skript |

## 反作弊/限制

| 插件 | 版本 | 来源 | 下载地址 |
|------|------|------|----------|
| AntiRedstoneLag | 2.0.1 | Modrinth | https://modrinth.com/plugin/antiredstonelag |
| ElytraSpeed | 1.3.4 | Modrinth | https://modrinth.com/plugin/elytraspeed |
| CommandBlocker | 1.7.2 | Modrinth | https://modrinth.com/plugin/commandblocker |
| Anti-Motd-Scanner | 0.5-BETA | Modrinth | https://modrinth.com/plugin/anti-motd-scanner |
| DupePlus | 1.4.3 | Modrinth | https://modrinth.com/plugin/dupeplus |
| SimplePolice | 6.1.4 | GitHub | https://github.com/fierceeo/SimplePolice/releases |

## 其他

| 插件 | 版本 | 来源 | 下载地址 |
|------|------|------|----------|
| JoinLeaveMessage | 0.2 | SpigotMC | https://www.spigotmc.org/resources/9262/ |
| PlayerTime | 1.0.7-RELEASE | SpigotMC | https://www.spigotmc.org/resources/58915/ |
| FancyNpcs | 2.11.0 | Modrinth | https://modrinth.com/plugin/fancynpcs | 仅安装于 lobby（大厅服）。取代无法在 26.x 上运行的 ZNPCsPlus，见下方兼容性表。要求 Java 25+，跨服跳转用 `send_to_server` 动作（依赖 velocity.toml 的 `bungee-plugin-message-channel`，本仓库已开启） |
| MinePay | latest | Modrinth | https://modrinth.com/plugin/minepay | 仅安装于 lobby（大厅服），替代 Srepay（微信/支付宝，v1.1.0 迁移） |

### 大厅 NPC 跳转配置（FancyNpcs）

插件 jar 与默认配置已入库（`lobby/plugins/FancyNpcs/`），但**没有预置任何 NPC**——
NPC 需要一个具体坐标，只能在服内创建。创建一个「点一下就进生存服」的 NPC：

```
/npc create hub_to_survival
/npc action hub_to_survival RIGHT_CLICK add send_to_server 2b2t
```

`2b2t` 是 `VC/velocity.toml` 的 `[servers]` 里的服务名。`send_to_server` 走
BungeeCord 插件消息通道，依赖 `velocity.toml` 的
`bungee-plugin-message-channel = true`（本仓库已是 `true`）。

创建后 NPC 会写进 `lobby/plugins/FancyNpcs/npcs.yml`，该文件已被跟踪，记得提交。

> `lobby/plugins/FancyAnalytics/config.json` 是 FancyNpcs 作者的遥测配置，按本仓库
> 既有惯例（bStats / cStats / PluginMetrics 的配置都入库且保持开启）一并入库、保持
> 默认开启。要关掉就把 `send_metrics` 与 `send_errors` 改成 `false`。

## 内置统计

以下插件由其他插件内置携带，随父插件自动更新，无需手动下载：

| 插件 | 说明 |
|------|------|
| bStats | 插件统计 |
| cStats | 插件统计 |
| PluginMetrics | 插件统计 |

## MC 1.26 兼容性注意

以下插件需要手动更新到最新版（或尚未适配 1.26）：

| 插件 | 问题 | 解决方案 |
|------|------|----------|
| Residence | CMILib 缺 v1_22_R1 字段 | 更新 CMILib + Residence |
| AdvancedTeleport | 仅支持 1.17-1.19 | 等待作者更新 |
| ProtocolLib | 正式版 5.4.0 只支持到 1.21.8 | 使用 5.5.0-SNAPSHOT-589ee12；已在 Paper 26.1.2 与 Leaf 26.2 实机启用 |
| PlaceholderAPI | 2.11.x 会因 26.x 版本号解析抛出 `NumberFormatException` | 使用修复该问题的 2.12.3；已在两个后端实机启用，上游仍将 Paper 26.x 支持标为 experimental |
| Vault | 1.7.3 发布于 2020，未声明 26.x | 已在两个后端实机启用并挂接 SuperPermissions；尚未安装经济实现 |
| WorldEdit | 7.4.4 正式版明确标注支持 26.1.2 与 26.2 | 已在两个后端实机启用，取代清单中原先的 beta 版本 |
| EssentialsX | 2.22.0 正式支持 Paper 26.1.2；Leaf 26.2 被上游硬编码为 `DANGEROUS_FORK` | 两个后端均实机启用。服主为保留 VIP/SVIP 的 `/home`、`/back` 与经济权益，明确接受 Leaf 上的数据丢失警告；必须保持备份并在升级后复测 |
| MinePay | 上游最新构建只标注到 1.21.11，没有任何 26.x 构建可下载 | 等待作者更新；在此之前 lobby 没有支付功能 |

## 已知兼容性问题

以下问题已通过实机启动日志确认，插件 jar 均被 `.gitignore` 排除，无法在仓库内直接修复，供运维参考处理：

| 插件 | 现象 | 建议动作 |
|------|------|----------|
| lobby/fakeplayer 0.3.13 | 启动日志：`Unsupported Minecraft version: 26.1.2`，插件完全无法启用 | 停用该插件，等待上游发布支持 26.x 的版本后再启用 |
| 2b2t/TAB 6.1.0 | 日志：`Your server version (Paper 26.1.2) is marked as compatible, but the implementation does not exist` | 升级到支持 26.x 的版本 |
| lobby/ZNPCsPlus 2.0.0 | 在 Paper 26.1.2 上初始化直接抛异常：`Version string must be in the format 'major.minor[.patch][+commit][-SNAPSHOT]', found '26.1.2.build.72' instead`——其内置的 PacketEvents 解析不了 Paper 的 API 版本号，`onLoad` 阶段就失败 | **不要放这个 jar**：放了每次启动都会多一条 ERROR，而插件本身完全不工作。2.0.0 已是上游最新 release，只能等新版 | 
| lobby/AuthMe 6.0.0 | 启动日志：`WARNING! The protectInventory feature requires PacketEvents! Disabling it...` | 功能降级而非启动失败：登录前的背包保护不可用，其余功能（含 MySQL 存储）正常。要恢复该功能需额外安装 PacketEvents |
| VC/LuckPerms 5.5.53 | Velocity 上加载翻译时报 `Error loading locale file: zh_TW.properties` | 只影响繁体中文翻译文件的加载，插件本身正常启用并连上 MySQL |
