# 2b2t.tech Minecraft

[English](README.md) | [简体中文](README.zh-CN.md)

本仓库包含 2b2t 主服务器、Velocity 代理、大厅服，以及可选 Docker 相关资源的配置、插件和运行脚本。

## 目录结构

- `2b2t/`：主服务器配置和插件
- `VC/`：Velocity 代理配置和插件
- `lobby/`：大厅服配置和插件
- `minecraft-docker/`：容器相关配置

## 环境变量（不要提交密钥）

先复制模板文件，再填写密钥：

```bash
cp .env.example .env
```

可用变量：

- `FORWARDING_SECRET`：Velocity 转发密钥
- `FLOODGATE_KEY_PEM`：Floodgate 密钥（PEM 内容，换行请使用 `\n`）

启动脚本会在运行时写入 `VC/forwarding.secret` 和 `VC/plugins/floodgate/key.pem`。

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

## 说明

- `.env`、运行时数据和密钥已被 `.gitignore` 排除。
- 首次运行前请先在 `eula.txt` 中接受 EULA。

## 许可证

本项目基于 Apache License 2.0 许可发布，详见 `LICENSE`。
