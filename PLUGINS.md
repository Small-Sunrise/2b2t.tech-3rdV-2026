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
| ProtocolLib | latest | GitHub | https://github.com/dmulloy2/ProtocolLib/releases |
| LuckPerms | 5.5.53 | Modrinth | https://modrinth.com/plugin/luckperms |
| PlaceholderAPI | latest | Modrinth | https://modrinth.com/plugin/placeholderapi |
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
| WorldEdit | 7.4.4-beta-01 | Modrinth | https://modrinth.com/plugin/worldedit |
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
| ZNPCsPlus | 2.0.0 | GitHub | https://github.com/Pyrbu/ZNPCsPlus | 仅安装于 lobby（大厅服），替代 ServersNPC（v1.1.0 迁移） |
| MinePay | latest | Modrinth | https://modrinth.com/plugin/minepay | 仅安装于 lobby（大厅服），替代 Srepay（微信/支付宝，v1.1.0 迁移） |

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
| ProtocolLib | 未测试 1.26 | 已有新版本 |
| MinePay | 上游最新构建只标注到 1.21.11，没有任何 26.x 构建可下载 | 等待作者更新；在此之前 lobby 没有支付功能 |

## 已知兼容性问题

以下问题已通过实机启动日志确认，插件 jar 均被 `.gitignore` 排除，无法在仓库内直接修复，供运维参考处理：

| 插件 | 现象 | 建议动作 |
|------|------|----------|
| lobby/fakeplayer 0.3.13 | 启动日志：`Unsupported Minecraft version: 26.1.2`，插件完全无法启用 | 停用该插件，等待上游发布支持 26.x 的版本后再启用 |
| 2b2t/PlaceholderAPI | 在 Leaf 26.2 上加载失败：`java.lang.NumberFormatException: For input string: "b"`（版本号解析崩溃） | 升级到支持 26.x 的版本 |
| 2b2t/TAB 6.1.0 | 日志：`Your server version (Paper 26.1.2) is marked as compatible, but the implementation does not exist` | 升级到支持 26.x 的版本 |
| lobby/ZNPCsPlus 2.0.0 | 在 Paper 26.1.2 上初始化直接抛异常：`Version string must be in the format 'major.minor[.patch][+commit][-SNAPSHOT]', found '26.1.2.build.72' instead`——其内置的 PacketEvents 解析不了 Paper 的 API 版本号，`onLoad` 阶段就失败 | **不要放这个 jar**：放了每次启动都会多一条 ERROR，而插件本身完全不工作。2.0.0 已是上游最新 release，只能等新版 |
