# Copilot instructions — squid-proxy-docker

Docker setup for a Squid forward proxy.

## Layout

- `squid/Dockerfile` — image based on `ubuntu:24.04`, with healthcheck `squid -k check`.
- `squid/entrypoint.sh` — fixes volume/stdout ownership, enables basic auth when `SQUID_USER`/`SQUID_PASSWORD` are set, removes a stale PID file, validates config, starts a daily `squid -k rotate` loop, runs Squid in the foreground.
- `squid/config/squid.conf` — ACLs and cache settings; mounted read-only by compose, applied with `make reload`.
- `docker-compose.yml` — `squid` service, host port `${SQUID_PORT:-3128}`, cache/log bind mounts.
- `scripts/test-proxy.sh` — functional tests: allowed traffic, blocked targets, auth (`PROXY_URL`, `PROXY_USER`, `PROXY_PASSWORD`, `TIMEOUT`). New ACLs or features need a check here. Must stay Bash 3.2 compatible (macOS) and use `pcurl` so `NO_PROXY`/`.curlrc` cannot bypass the proxy.
- `Makefile` — `make help` lists targets; CI uses `make lint` and `make test` (fixed port, auth off then on, cleanup trap).

## Rules

- Lint must pass: `make lint` (hadolint + shellcheck, run via Docker). Do not add `|| true` to lint steps.
- Keep the access policy restrictive: never add `http_access allow all`.
- Validate config changes with `squid -k parse` and run `make test` before opening a PR.
- No secrets in the repository.
- Target branch: `main`. Use conventional commit prefixes (`ci:`, `docs:`, `fix:`, `feat:`).
