# Docker deployment

The Compose stack runs MariaDB, the lobby, the survival server, and Velocity on
one private bridge network. Only Velocity's Java TCP port (`50016`) and
Geyser's Bedrock UDP port (`19132`) are published to the host.

## Prerequisites

- Docker with Compose v2
- The three gitignored server jars at their exact paths:
  - `VC/velocity-3.5.0-SNAPSHOT-605.jar`
  - `lobby/paper.jar`
  - `2b2t/leaf-26.2-14.jar`
- Required plugin jars in each server's `plugins/` directory
- A root `.env` created from `.env.example`, with all required secrets filled
  in

The images use Java 25 because the included Minecraft 26.x servers require it.

## Start

```bash
cp .env.example .env
# Fill in all required values in .env.
cd minecraft-docker/compose
docker compose --env-file ../../.env config
docker compose --env-file ../../.env build
docker compose --env-file ../../.env up -d --wait
```

Check status and logs:

```bash
docker compose --env-file ../../.env ps
docker compose --env-file ../../.env logs -f
```

Stop the network while retaining the MariaDB volume:

```bash
docker compose --env-file ../../.env down
```

Add `-v` only when you intentionally want to delete the MariaDB data volume.

## Runtime behavior

- Container entrypoints copy the LuckPerms, AuthMe, TAB, and QueQiao config
  directories into container-local runtime storage, then inject credentials
  from environment variables using `scripts/inject-db-secrets.sh`. Real
  credentials never enter the bind-mounted checkout.
- MariaDB's initialization script creates the LuckPerms and AuthMe databases,
  users, and grants from `.env`; no password is hardcoded in the repository.
- Velocity runs from a container-local copy of `velocity.toml` where bare-metal
  loopback backend addresses are changed to Compose service names (`lobby` and
  `survival`). The tracked config is not modified.
- Backends receive the modern-forwarding secret through
  `PAPER_VELOCITY_SECRET`. Paper runs with a container-local copy of its
  `config/` directory so it cannot serialize the secret back into the
  bind-mounted repository.
- Worlds, plugin data, and ordinary server configuration remain bind-mounted
  under `VC/`, `lobby/`, and `2b2t/`.

## Memory overrides

The survival defaults match the bare-metal 8 GiB setup. On a smaller Docker
Desktop VM, set these optional values in `.env` before starting:

```dotenv
VELOCITY_JAVA_XMS=256M
VELOCITY_JAVA_XMX=512M
LOBBY_JAVA_XMS=512M
LOBBY_JAVA_XMX=1G
LOBBY_JAVA_SOFT_MAX=700M
SURVIVAL_JAVA_XMS=1G
SURVIVAL_JAVA_XMX=3G
SURVIVAL_JAVA_SOFT_MAX=2G
```
