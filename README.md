# squid-proxy-docker

[![CI](https://github.com/kmpoltorak/squid-proxy-docker/actions/workflows/ci.yml/badge.svg)](https://github.com/kmpoltorak/squid-proxy-docker/actions/workflows/ci.yml)

Lightweight Docker setup for a [Squid](https://www.squid-cache.org/) caching forward proxy (Ubuntu 24.04, Squid 6).

## Features

- HTTP and HTTPS (`CONNECT`) forward proxy with a 10 GB disk cache
- Access limited to private networks (RFC 1918, CGN, link-local, IPv6 ULA)
- Blocks the Squid container's own loopback and link-local targets (e.g. cloud metadata `169.254.169.254`)
- Optional basic authentication via environment variables
- Access log to `docker compose logs` and to a file on the host, rotated daily
- Persistent cache, config mounted read-only and hot-reloadable
- Docker healthcheck, CI with hadolint, shellcheck and a functional test

Requirements: Docker with Compose v2 (`--wait`), GNU make, curl and Bash 3.2+ for the tests.

## Quick start

```sh
make up          # build, start and wait until healthy
make test        # start, run functional tests, tear down
make help        # list all targets
```

Without `make`: `docker compose up -d --build --wait`.

Use the proxy from a client:

```sh
curl -x http://<docker-host>:3128 https://example.com
export http_proxy=http://<docker-host>:3128 https_proxy=http://<docker-host>:3128
```

## Configuration

| What | Where |
|------|-------|
| Squid config | [squid/config/squid.conf](squid/config/squid.conf), apply with `make reload` (no rebuild) |
| Host port | `SQUID_PORT` in `.env` (default `3128`) |
| Basic auth | `SQUID_USER` + `SQUID_PASSWORD` in `.env` (disabled when empty) |
| Timezone | `TZ` in [squid/Dockerfile](squid/Dockerfile) (default `Europe/Warsaw`) |
| Extra config snippets | mount single `*.conf` files into `/etc/squid/conf.d/` (not the whole directory, the entrypoint writes `auth.conf` there) |

`make reload` validates the config (`squid -k parse`) before applying it.
Start from the template: `cp .env.example .env`.

The healthcheck (`squid -k check`) only confirms the Squid process is running, not that traffic passes through it.

### Blocked targets

`to_localhost` covers the loopback of the Squid container only. The Docker host's LAN address and the
Docker bridge gateway (e.g. `172.17.0.1`) are **not** blocked; whether they are reachable depends on your
routing and firewall. To block them, mount a drop-in (snippets are applied before the allow rules):

```
# /etc/squid/conf.d/block-host.conf
acl docker_host dst 192.168.1.10 172.17.0.1
http_access deny docker_host
```

### Authentication

With `SQUID_USER` and `SQUID_PASSWORD` set, clients need **both** a private IP and valid credentials
(unauthenticated requests get `407`). Apply changes with `make up` (the container is recreated):

```sh
curl -x http://alice:secret@<docker-host>:3128 https://example.com
```

The password is hashed (SHA-512 crypt) inside the container, but the plain value is visible in
`docker inspect`. Basic auth sends credentials unencrypted to the proxy, so use it only on trusted networks.

> **Security:** only clients from private address ranges are allowed. Do not expose port 3128 to the internet.
> If your clients show up with a public IP in `access.log` (`TCP_DENIED/403`), for example because of
> Docker Desktop networking or a VPN, add a dedicated `acl ... src` rule instead of widening `localnet`.

## Cache and logs

| Host path | Container path | Content |
|-----------|----------------|---------|
| `./var-spool-squid` | `/var/spool/squid` | disk cache |
| `./var-logs-squid` | `/var/log/squid` | `access.log`, `cache.log` |

The access log is written both to the file and to container stdout:

```sh
make logs                          # docker compose logs -f squid
tail -f var-logs-squid/access.log  # same entries, from the host
```

To clear the cache: `make down && rm -rf var-spool-squid && make up`.

Log files are rotated daily by the container (`squid -k rotate`, 7 old files kept as `access.log.0`…`.6`);
`make rotate` rotates on demand. Container stdout logs are capped by Compose (`json-file`, 3 × 10 MB).

## Testing

[scripts/test-proxy.sh](scripts/test-proxy.sh) exits non-zero on the first failed check:

- HTTP and HTTPS requests go through: curl exits cleanly and the target returns `2xx`
- the container loopback, `169.254.169.254`, ports outside `Safe_ports` and `CONNECT` to non-SSL ports are blocked (`403`)
- with `PROXY_USER`/`PROXY_PASSWORD` set: missing and wrong credentials are rejected (`407`)

The script ignores `NO_PROXY` and `~/.curlrc`, so every request goes through the proxy under test.

`make test` runs it twice, without and with auth (`test`/`test`), then tears down, also after a failed start
or Ctrl-C, printing container logs on failure. It ignores `SQUID_*` from `.env` and always publishes port
`3128` (override with `make test TEST_PORT=13128`). Note that it recreates the `squid` container, so a running
proxy is stopped. CI runs `make test`. Against a running proxy:

```sh
PROXY_URL=http://10.0.0.5:3128 PROXY_USER=alice PROXY_PASSWORD=secret ./scripts/test-proxy.sh
```

`make lint` runs hadolint and shellcheck in Docker, so nothing needs to be installed locally.

## Squid documentation

- Documentation & wiki: https://wiki.squid-cache.org/
- Configuration directives: https://www.squid-cache.org/Doc/config/
- Configuration examples: https://wiki.squid-cache.org/ConfigExamples
- ACLs and access controls: https://wiki.squid-cache.org/Features/ACLs
- Security: https://wiki.squid-cache.org/SquidFaq/Security

## License

[MIT](LICENSE)
