# 2b2t.tech Minecraft

[English](README.md) | [简体中文](README.zh-CN.md)

This repository contains the configuration, plugins, and run scripts for the
2b2t main server, Velocity proxy, and lobby, plus optional Docker assets.

## Structure

- `2b2t/`: main server configuration and plugins
- `VC/`: Velocity proxy configuration and plugins
- `lobby/`: lobby configuration and plugins
- `minecraft-docker/`: container-related configuration

## Environment Variables (do not commit secrets)

Copy the template and fill in the secrets:

```bash
cp .env.example .env
```

Available variables:

- `FORWARDING_SECRET`: Velocity forwarding secret
- `FLOODGATE_KEY_PEM`: Floodgate key (PEM content; use `\n` for newlines)

Startup scripts write `VC/forwarding.secret` and `VC/plugins/floodgate/key.pem`
at runtime.

## Run Example

Run the scripts in the target directory:

```bash
cd VC
./run.sh
```

On Windows, use the `.bat` scripts:

```bat
run.bat
```

## Notes

- `.env`, runtime data, and secrets are excluded by `.gitignore`.
- Accept the EULA in `eula.txt` before the first run.

## Security

### Network
- Command blocks are disabled on the lobby server to prevent unauthorized access.
- Velocity proxy uses bungeeguard forwarding mode with shared-secret token validation.
- Backend servers run in offline mode behind the proxy with IP forwarding enabled.
- Join rate limiting enabled at both proxy and backend levels.

### User Data
- Passwords hashed with BCRYPT2Y (upgraded from SHA256).
- Database credentials stored in `.env`, never committed to git.
- AuthMe ForceSingleSession enabled to prevent session hijacking.
- Minimum password length: 8 characters.

## License

Licensed under the Apache License, Version 2.0. See `LICENSE`.
