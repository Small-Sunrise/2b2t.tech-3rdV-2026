# 2b2t.tech Minecraft

[English](README.md) | [简体中文](README.zh-CN.md)

本仓库包含 2b2t 主服务器、Velocity 代理、大厅服，以及可选 Docker 相关资源的配置、插件和运行脚本。

## 目录结构

- `2b2t/`：主服务器配置和插件
- `VC/`：Velocity 代理配置和插件
- `lobby/`：大厅服配置和插件
- `minecraft-docker/`：容器相关配置

> Docker Compose 现可作为可选部署方式，前置条件和命令见
> `minecraft-docker/README.md`。裸机方式仍可使用 `run-all.sh` 或各服务器自己的
> `run.sh`。

## 环境变量（不要提交密钥）

先复制模板文件，再填写密钥：

```bash
cp .env.example .env
```

可用变量：

- `FORWARDING_SECRET`：Velocity 转发密钥
- `FLOODGATE_KEY_PEM`：Floodgate 密钥（PEM 内容，换行请使用 `\n`）

启动脚本会在运行时写入 `VC/forwarding.secret` 和 `VC/plugins/floodgate/key.pem`。

## 数据库

LuckPerms 使用 MySQL 在大厅服与 2b2t 之间同步跨服权限。Docker compose 技术栈中
已包含 MariaDB 服务。

### Docker

Compose 会根据 `.env` 自动初始化 LuckPerms 与 AuthMe 数据库：

```bash
cd minecraft-docker/compose
docker compose --env-file ../../.env build
docker compose --env-file ../../.env up -d --wait
```

所需 jar、内存覆盖、日志和停止命令见 `minecraft-docker/README.md`。

### 本地部署（不使用 Docker）
安装 MariaDB/MySQL，然后执行：
```sql
CREATE DATABASE luckperms_2b2t;
CREATE USER 'lpsql'@'localhost' IDENTIFIED BY '<password>';
GRANT ALL PRIVILEGES ON luckperms_2b2t.* TO 'lpsql'@'localhost';
FLUSH PRIVILEGES;
```
在 `.env` 中设置 `LUCKPERMS_DB_HOST=127.0.0.1:3306` 和 `LUCKPERMS_DB_PASSWORD`。

### 切换为 H2（无需外部数据库）
编辑 LuckPerms 的 `config.yml`，将 `storage-method` 从 `MySQL` 改为 `H2`，
即可不使用外部数据库。该配置文件在后端服务器上位于
`2b2t/plugins/LuckPerms/config.yml` 和 `lobby/plugins/LuckPerms/config.yml`，
在 Velocity 代理上则位于 `VC/plugins/luckperms/config.yml`（注意小写）。

## 首次克隆后的准备工作

所有服务器 jar 包都已被 `.gitignore` 排除（`git ls-files | grep -c '\.jar$'`
的结果是 `0`），`.env` 和 `VC/forwarding.secret` 同样如此。因此仓库刚克隆下来
时无法启动任何服务，必须手动补齐以下内容：

- `VC/velocity-3.5.0-SNAPSHOT-605.jar` —— Velocity 代理的 jar 包
- `lobby/paper.jar` —— 大厅服使用的 Paper jar 包
- `2b2t/leaf-26.2-14.jar` —— 2b2t 服务器使用的 Leaf jar 包
- 执行 `cp .env.example .env`，然后填写 `FORWARDING_SECRET`、
  `LUCKPERMS_DB_PASSWORD` 等你需要用到的变量

各 `*/plugins/` 目录下的插件 jar 包同样已被 `.gitignore` 排除——仓库中只
跟踪插件的配置文件，插件 jar 需要另行补充。`VC/forwarding.secret` 是启动
时根据 `.env` 中的 `FORWARDING_SECRET` 自动生成的，不需要手动创建。

启动服务器之前建议先执行 `bash scripts/startup-check.sh`：它会检查上述
jar 包是否存在、`.env` 中的关键变量、EULA 是否已接受、`run.sh` 是否可
执行、Java 版本、插件目录，以及若干关键插件 jar，并准确报告缺少了什么。

## 运行示例

在目标目录中执行脚本：

```bash
cd VC
./run.sh
```

在 Windows 上请使用 `.bat` 脚本：

```bat
run.bat
```

## 运维操作

### 启动与停止网络

- `./run-all.sh` 会启动全部三个服务（VC、lobby、2b2t）。它会在存在时加载
  `.env`，写入 `VC/forwarding.secret`，将运行时凭据注入委托给
  `scripts/inject-db-secrets.sh`，并把 `FORWARDING_SECRET` 作为
  `PAPER_VELOCITY_SECRET` 环境变量传给各后端以支持 modern 转发，然后
  在后台（`nohup`）启动各服务自己的 `run.sh`，将 PID 写入 `pids/<name>.pid`，
  日志写入 `logs/<name>.log`。重复运行是安全的——如果某服务的 PID 文件
  显示进程仍在运行，会自动跳过该服务。
- `./stop-all.sh` 依次停止 2b2t、lobby、VC：向 `pids/<name>.pid` 中记录的
  PID 发送 `kill` 信号，随后删除该 PID 文件。

### 辅助脚本（`scripts/`）

- `healthcheck.sh [--json]`：检查每个服务的 PID 文件及其 TCP 端口、MariaDB
  可达性和磁盘使用率，默认输出纯文本报告，加 `--json` 时输出 JSON；只要有
  异常就以非零状态退出。适合配合 cron 或监控系统使用。
- `backup.sh [world|config|db|all]`：打包备份 2b2t 世界文件、打包备份插件
  配置（排除 jar、日志和世界数据），并在 `mysqldump` 可用时导出 LuckPerms
  数据库，全部存放到 `backups/` 目录，随后删除超过 `KEEP_DAYS` 天（默认
  7 天）的旧备份。不带参数时默认执行 `all`。
- `startup-check.sh`：在启动服务器前运行的预检脚本。校验 `.env` 中的关键
  变量、各服务器 jar 是否存在、EULA 是否已接受、`run.sh` 是否可执行、Java
  版本、插件目录、LuckPerms `config.yml` 是否存在、若干关键插件 jar，以及
  旧版 CommandSync/ServersNPC/Srepay 相关文件是否已清理干净。最终打印
  通过/失败的检查项数量，若有失败项则以非零状态退出。
- `db-test.sh`：检查 LuckPerms 的 `LUCKPERMS_DB_*` 变量是否已设置、MariaDB
  主机/端口是否可达，以及（若已安装 `mysql` 客户端）登录和访问目标数据库
  是否成功。
- `install-logrotate.sh`：需以 root 身份运行；将 `scripts/logrotate.conf`
  安装到 `/etc/logrotate.d/2b2t`，并将其中的占位路径替换为实际仓库路径。
  具体的轮转规则（每日轮转、保留 14 天、大小上限等）定义在
  `scripts/logrotate.conf` 中。
- `inject-db-secrets.sh`：由各服务的 `run.sh` 和 `run-all.sh` 在启动时
  调用；将 `LUCKPERMS_DB_*` 的值写入各服务器的 LuckPerms `config.yml`
  （代理上使用小写的 `VC/plugins/luckperms/` 路径），并在设置了相应变量时
  将 `AUTHME_DB_*` / `TAB_DB_*` 的值写入 lobby 的 AuthMe 和 2b2t 的 TAB
  配置。

## 说明

- `.env`、运行时数据和密钥已被 `.gitignore` 排除。
- 首次运行前请先在 `eula.txt` 中接受 EULA。

## 安全

### 网络
- 大厅服已禁用命令方块，以防止未经授权的访问。
- Velocity 代理使用 modern 玩家信息转发模式，通过共享密钥完成代理到后端的
  身份校验（详见下文）。
- 后端服务器在代理之后以离线模式运行，并启用了 IP 转发。
- 代理与后端均启用了加入速率限制。

### 玩家信息转发（代理 ↔ 后端信任关系）

本网络正从 BungeeGuard 插件迁移到 Velocity 内置的 **modern** 转发模式：
`VC/velocity.toml` 中的 `player-info-forwarding-mode = "modern"`。这里有
两个相互独立、但很容易混淆的设置：

- **`online-mode`**（位于 `VC/velocity.toml`，并在各后端的
  `config/paper-global.yml` 的 `proxies.velocity.online-mode` 中保持一致）
  控制的是**客户端 ↔ 代理**之间的认证——即是否需要 Mojang 为登录账号背书。
  本网络是离线/破解服（代理与两台后端均为 `online-mode = false`），登录
  依靠 AuthMe 的密码验证，而非正版 Mojang 账号。代理与两台后端必须保持该
  值一致，否则玩家 UUID 会出现分歧，导致玩家数据、LuckPerms 权限和
  AuthMe 账号出错。
- **`player-info-forwarding-mode = "modern"`**，加上各后端
  `paper-global.yml` 中匹配的 `secret`（`proxies.velocity.secret`），控制
  的是**代理 ↔ 后端**之间的信任关系——它让 lobby/2b2t 能够确认某个连接
  确实来自代理（并携带玩家的真实 IP/UUID），而不是伪装的直连。这取代了
  BungeeGuard 插件，该插件已从两台后端的 `plugins/` 中移除；两台后端也
  都在 `spigot.yml` 中将 `bungeecord` 设为 `false`。
- modern 转发**并不要求**玩家使用正版账号——它只负责保护代理→后端这段
  内部连接，与 `online-mode` 相互独立。
- 共享密钥只存在于 `.env`（`FORWARDING_SECRET`，已被 `.gitignore`
  排除）中。Velocity 从 `VC/forwarding.secret` 读取它；各后端通过 Paper
  的 `PAPER_VELOCITY_SECRET` 环境变量覆盖读取。受 Git 跟踪的
  `paper-global.yml` 因而始终保持 `secret: ''`，不会保存真实密钥。
- 由于后端一旦信任"代理"，就会信任任何自称是代理的连接，因此 lobby 和
  2b2t 绝不能直接暴露在公网上——只有代理的端口应当对外开放。

运行时注入可能会把数据库或插件凭据写入受 Git 跟踪的配置文件。提交前可手动扫描：

```bash
./scripts/check-secrets.sh
```

可按需启用 pre-commit hook，自动扫描暂存内容：

```bash
git config core.hooksPath .githooks
```

该 hook 不扫描 `.env` 等已忽略的运行时文件。

### 用户数据
- 密码使用 BCRYPT2Y 哈希（由 SHA256 升级而来）。
- 数据库凭据存储在 `.env` 中，绝不提交到 Git。
- 已启用 AuthMe 的 ForceSingleSession，以防止会话劫持。
- 最小密码长度：8 个字符。

## 许可证

本项目基于 Apache License 2.0 许可发布，详见 `LICENSE`。
