# 2b2t.tech Minecraft

该仓库包含 2b2t 主服、VC（Velocity 代理）与 lobby 的配置与运行脚本，以及可选的 docker 配置。

## 目录结构

- `2b2t/`：主服配置与插件
- `VC/`：Velocity 代理配置与插件
- `lobby/`：大厅配置与插件
- `minecraft-docker/`：容器化相关配置

## 环境变量（不提交密钥）

复制模板并填写密钥：

```bash
cp .env.example .env
```

可用变量：

- `FORWARDING_SECRET`：Velocity forwarding secret
- `FLOODGATE_KEY_PEM`：Floodgate key（PEM 内容，使用 `\n` 表示换行）

启动脚本会在运行时写入 `VC/forwarding.secret` 与 `VC/plugins/floodgate/key.pem`。

## 运行示例

进入对应目录执行脚本：

```bash
cd VC
./run.sh
```

Windows 使用 `.bat` 脚本：

```bat
run.bat
```

## 注意事项

- `.env`、运行时数据与密钥均被 `.gitignore` 排除。
- 首次运行前请确认 `eula.txt` 已接受协议。
