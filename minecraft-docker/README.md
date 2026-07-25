# minecraft-docker/

**Status: unsupported / not currently functional.**

This directory is not the supported way to run the network. It has
independent, unaddressed problems described below and shows no evidence of
ever having run successfully end-to-end. The supported path is `run-all.sh`
(or each server's own `run.sh`) from the repository root — see the top-level
`README.md`.

## Known blockers

1. **No secret / DB-credential injection.** `VC/Dockerfile.velocity`,
   `lobby/Dockerfile.lobby` and `2b2t/Dockerfile.2b2t` each set
   `ENTRYPOINT ["java", ...]` directly against the server jar. They never
   invoke the corresponding `run.sh`, so none of the startup-time steps that
   `run.sh` normally performs — writing `VC/forwarding.secret` from
   `FORWARDING_SECRET`, or injecting `LUCKPERMS_DB_*` / `AUTHME_DB_*` /
   `TAB_DB_*` credentials via `scripts/inject-db-secrets.sh` — ever run.

2. **Velocity never sees its real config.** `VC/Dockerfile.velocity` sets
   `WORKDIR /app` and `COPY`s the jar to `/app/velocity.jar`, but
   `compose/docker-compose.yml` mounts this repo's actual `VC/` directory at
   `/config` (`../../VC:/config`). Since the container's working directory
   is `/app`, not `/config`, and the `ENTRYPOINT` never references `/config`,
   Velocity starts against its own built-in defaults, not this repo's
   `velocity.toml`, `plugins/`, or `forwarding.secret`.

3. **Backend addresses can't resolve across containers.** `VC/velocity.toml`'s
   `[servers]` block points at `127.0.0.1:50015` (lobby) and
   `127.0.0.1:50013` (2b2t). In `compose/docker-compose.yml`, `velocity`,
   `lobby` and `survival` are three separate containers joined by the
   `mc-network` bridge network; `127.0.0.1` inside the `velocity` container
   refers to the `velocity` container itself, never to `lobby` or `survival`.
   (Moot in practice anyway, per point 2 — the proxy container isn't reading
   this `velocity.toml` in the first place.)

4. **No jars are tracked by git, so every build fails on a fresh clone.**
   `VC/Dockerfile.velocity` COPYs `velocity-3.5.0-SNAPSHOT-605.jar`,
   `lobby/Dockerfile.lobby` COPYs `paper.jar`, and `2b2t/Dockerfile.2b2t`
   COPYs `leaf-26.2-14.jar`. `git ls-files | grep -c '\.jar$'` returns `0` —
   none of these files exist until an operator adds them manually, so
   `docker compose build` fails immediately after cloning.

5. **The LuckPerms DB init script hardcodes a password that won't match
   `.env`.** `compose/init/01-luckperms.sql` creates the `lpsql` MySQL user
   with `IDENTIFIED BY 'change-me-in-production'` — a literal placeholder,
   not a real secret. Its own comment claims
   "`docker-compose.yml` injects `LUCKPERMS_DB_PASSWORD` env var at runtime,"
   but `compose/docker-compose.yml` never references `LUCKPERMS_DB_PASSWORD`
   anywhere, and MariaDB's `docker-entrypoint-initdb.d` scripts get no env-var
   substitution — they run as plain SQL. The password actually set in the
   database will not match `LUCKPERMS_DB_PASSWORD` in `.env`, so plugins
   configured with the `.env` value cannot authenticate.

6. **Two Dockerfiles are orphaned.** `minecraft-docker/Dockerfile` and
   `minecraft-docker/Dockerfile.vsa` are not referenced by
   `compose/docker-compose.yml` (which only builds `Dockerfile.velocity`,
   `Dockerfile.lobby` and `Dockerfile.2b2t`, from `../../VC`, `../../lobby`
   and `../../2b2t` respectively) or by any other compose/build file in this
   repository. It's unclear what, if anything, they're meant to produce.

## If you're reviving this

Fixing the stack requires at least: having each Dockerfile's entrypoint call
the real `run.sh` (or replicate its secret/credential injection), pointing
Velocity's container at the mounted config directory, replacing the
`127.0.0.1` backend addresses with the compose service names (`lobby`,
`survival`), committing the required jars into a build context (or
downloading them in the Dockerfile / mounting them as volumes), and either
templating `01-luckperms.sql` or creating the LuckPerms DB user after the
container starts using the real `LUCKPERMS_DB_PASSWORD`.
