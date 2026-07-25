# 2b2t.tech Minecraft

[English](README.md) | [简体中文](README.zh-CN.md)

This repository contains the configuration, plugins, and run scripts for the
2b2t main server, Velocity proxy, and lobby, plus optional Docker assets.

## Structure

- `2b2t/`: main server configuration and plugins
- `VC/`: Velocity proxy configuration and plugins
- `lobby/`: lobby configuration and plugins
- `minecraft-docker/`: container-related configuration

> Docker Compose is supported as an optional deployment path. See
> `minecraft-docker/README.md` for prerequisites and commands. Bare-metal
> startup remains available through `run-all.sh` or each server's `run.sh`.

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

## Database

LuckPerms uses MySQL for cross-server permission syncing between lobby
and 2b2t. A MariaDB service is included in the Docker compose stack.

### Docker

The Compose stack initializes both LuckPerms and AuthMe databases from `.env`:

```bash
cd minecraft-docker/compose
docker compose --env-file ../../.env build
docker compose --env-file ../../.env up -d --wait
```

See `minecraft-docker/README.md` for required jars, memory overrides, logs, and
shutdown commands.

### Local (without Docker)
Install MariaDB/MySQL, then:
```sql
CREATE DATABASE luckperms_2b2t;
CREATE USER 'lpsql'@'localhost' IDENTIFIED BY '<password>';
GRANT ALL PRIVILEGES ON luckperms_2b2t.* TO 'lpsql'@'localhost';
FLUSH PRIVILEGES;
```
Set `LUCKPERMS_DB_HOST=127.0.0.1:3306` and `LUCKPERMS_DB_PASSWORD` in `.env`.

### Switching to H2 (no external DB)
Edit the LuckPerms `config.yml` and change `storage-method` from `MySQL`
to `H2`. No external database needed. The config file lives at
`2b2t/plugins/LuckPerms/config.yml` and `lobby/plugins/LuckPerms/config.yml`
on the backend servers, and at `VC/plugins/luckperms/config.yml` (lowercase)
on the Velocity proxy.

## First-Time Setup (Fresh Clone)

Every server jar is gitignored (`git ls-files | grep -c '\.jar$'` returns
`0`), along with `.env` and `VC/forwarding.secret`. A fresh clone cannot start
any service until you add these manually:

- `VC/velocity-3.5.0-SNAPSHOT-605.jar` — the Velocity proxy jar
- `lobby/paper.jar` — the Paper jar for the lobby server
- `2b2t/leaf-26.2-14.jar` — the Leaf jar for the 2b2t server
- `cp .env.example .env`, then fill in `FORWARDING_SECRET`,
  `LUCKPERMS_DB_PASSWORD`, and any other variables your setup needs

Plugin jars under each `*/plugins/` directory are also gitignored — only
their configuration files are tracked, so plugin `.jar`s must be supplied
separately. `VC/forwarding.secret` is generated from `.env`'s
`FORWARDING_SECRET` at startup; you don't create it by hand.

Run `bash scripts/startup-check.sh` before starting the servers — it checks
for the jars above, required `.env` values, EULA acceptance, executable run
scripts, Java version, plugin directories and key plugin jars, and reports
exactly what's missing.

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

## Operations

### Starting and stopping the network

- `./run-all.sh` starts all three services (VC, lobby, 2b2t). It loads `.env`
  if present, writes `VC/forwarding.secret`, delegates runtime credential
  injection to `scripts/inject-db-secrets.sh`, then launches each backend with
  `PAPER_VELOCITY_SECRET` exported from `FORWARDING_SECRET` for modern
  forwarding. It then launches each
  server's own `run.sh` in the background (`nohup`), writing a PID to
  `pids/<name>.pid` and logs to `logs/<name>.log`. Re-running it is safe — it
  skips any service whose PID file shows a process that is still alive.
- `./stop-all.sh` stops 2b2t, then lobby, then VC, by sending `kill` to the
  PID recorded in `pids/<name>.pid` and removing the PID file afterwards.

### Helper scripts (`scripts/`)

- `healthcheck.sh [--json]`: checks each service's PID file and its TCP port,
  MariaDB reachability, and disk usage, printing a plain-text report (or JSON
  with `--json`); exits non-zero if anything is unhealthy. Meant to be run
  from cron or a monitoring system.
- `backup.sh [world|config|db|all]`: archives the 2b2t world, archives plugin
  configs (excluding jars, logs and world data), and `mysqldump`s the
  LuckPerms database (if `mysqldump` is installed) into `backups/`, then
  deletes backups older than `KEEP_DAYS` days (default 7). Defaults to `all`
  when no argument is given.
- `startup-check.sh`: pre-flight check to run before starting the servers.
  Verifies `.env` values, the presence of each server jar, EULA acceptance,
  that the `run.sh` scripts are executable, the Java version, the plugin
  directories, LuckPerms `config.yml` presence, a handful of key plugin jars,
  and that old CommandSync/ServersNPC/Srepay files have been cleaned up.
  Prints a pass/fail count and exits non-zero if any check fails.
- `db-test.sh`: checks that the LuckPerms `LUCKPERMS_DB_*` variables are set,
  that the MariaDB host/port is reachable, and — if the `mysql` client is
  installed — that login and access to the target database succeed.
- `install-logrotate.sh`: must be run as root; installs `scripts/logrotate.conf`
  to `/etc/logrotate.d/2b2t`, substituting the placeholder path with the real
  repository path. The rotation rules themselves (daily, 14 days retained,
  size caps) live in `scripts/logrotate.conf`.
- `inject-db-secrets.sh`: called by the server `run.sh` scripts (and by
  `run-all.sh`) at startup; writes the `LUCKPERMS_DB_*` values into each
  server's LuckPerms `config.yml` (using the lowercase `VC/plugins/luckperms/`
  path on the proxy), and writes `AUTHME_DB_*` / `TAB_DB_*` values into
  lobby's AuthMe and 2b2t's TAB configs when those variables are set.

## Notes

- `.env`, runtime data, and secrets are excluded by `.gitignore`.
- Accept the EULA in `eula.txt` before the first run.

## Security

### Network
- Command blocks are disabled on the lobby server to prevent unauthorized access.
- Velocity proxy uses modern player-info forwarding with a shared secret to
  authenticate the proxy to the backends (see below).
- Backend servers run in offline mode behind the proxy with IP forwarding enabled.
- Join rate limiting enabled at both proxy and backend levels.

### Player-info forwarding (proxy ↔ backend trust)

The network is migrating from the BungeeGuard plugin to Velocity's built-in
**modern** forwarding: `player-info-forwarding-mode = "modern"` in
`VC/velocity.toml`. Two settings are independent and easy to conflate:

- **`online-mode`** (`VC/velocity.toml`, mirrored in each backend's
  `config/paper-global.yml` under `proxies.velocity.online-mode`) governs
  **client ↔ proxy** authentication — whether Mojang has to vouch for the
  connecting account. This network is cracked/offline (`online-mode = false`
  on the proxy and both backends); logins are password-based via AuthMe, not
  premium Mojang accounts. The proxy and both backends must agree on this
  value, or player UUIDs diverge and break player data, LuckPerms and AuthMe.
- **`player-info-forwarding-mode = "modern"`**, plus the matching `secret` in
  each backend's `paper-global.yml` (`proxies.velocity.secret`), governs
  **proxy ↔ backend** trust — it lets lobby/2b2t verify a connection really
  originates from the proxy (carrying the player's real IP/UUID) instead of a
  spoofed direct connection. This replaces BungeeGuard, which is removed from
  both backends' `plugins/`; both backends also set `bungeecord: false` in
  `spigot.yml`.
- Modern forwarding does **not** require premium accounts — it only secures
  the internal proxy→backend hop and is orthogonal to `online-mode`.
- The shared secret lives only in `.env` (`FORWARDING_SECRET`, gitignored).
  Velocity reads it from `VC/forwarding.secret`; each backend receives it via
  Paper's `PAPER_VELOCITY_SECRET` environment override. The tracked
  `paper-global.yml` files therefore keep `secret: ''` and never store it.
- Because a backend that trusts "the proxy" trusts *any* connection claiming
  to be the proxy, lobby and 2b2t must never be exposed directly to the
  internet — only the proxy's port should be reachable publicly.

Runtime injection can place database and plugin credentials into tracked configuration files. Before committing, scan tracked content manually:

```bash
./scripts/check-secrets.sh
```

Install the opt-in pre-commit hook to scan staged content automatically:

```bash
git config core.hooksPath .githooks
```

The hook never scans ignored runtime files such as `.env`.

### User Data
- Passwords hashed with BCRYPT2Y (upgraded from SHA256).
- Database credentials stored in `.env`, never committed to git.
- AuthMe ForceSingleSession enabled to prevent session hijacking.
- Minimum password length: 8 characters.

## License

Licensed under the Apache License, Version 2.0. See `LICENSE`.
