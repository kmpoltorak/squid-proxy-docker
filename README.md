# squid-proxy-docker

[![CI](https://github.com/kmpoltorak/squid-proxy-docker/actions/workflows/ci.yml/badge.svg)](https://github.com/kmpoltorak/squid-proxy-docker/actions/workflows/ci.yml)

A [Squid](https://www.squid-cache.org/) caching forward proxy in Docker (Ubuntu
26.04, distro Squid) for clients on a private network. It is a learning lab for
forward proxying, Squid ACLs and HTTP caching, with every deny rule checked by
a test. Only plain HTTP is cached; HTTPS goes through a `CONNECT` tunnel.

```text
$ PROXY_URL=http://localhost:3128 ./scripts/test-proxy.sh
Testing proxy http://localhost:3128
Allowed traffic:
  OK   http://example.com/ -> 200
  OK   https://example.com/ -> 200
Blocked targets:
  OK   http://127.0.0.1:3128/ -> 403
  OK   http://169.254.169.254/ -> 403
  OK   http://example.com:25/ -> 403
  OK   https://example.com:80/ -> 403
All proxy checks passed
```

- Only private source networks are allowed (RFC 1918, CGN, link-local, IPv6 ULA); there is never an `http_access allow all`.
- The container's own loopback and link-local targets (e.g. cloud metadata `169.254.169.254`) are denied, as are ports outside `Safe_ports` and `CONNECT` to non-SSL ports.
- Optional basic auth: clients then need both a private IP and valid credentials. Setting only one of `SQUID_USER` / `SQUID_PASSWORD` stops the container at start.
- `make reload` runs `squid -k parse` before applying a config change.

## Install

Requires Docker with Compose v2, GNU make, and curl and Bash 3.2+ for the tests.

```sh
git clone https://github.com/kmpoltorak/squid-proxy-docker.git
cd squid-proxy-docker
cp .env.example .env
```

## Quick start

```sh
make up          # build, start and wait until healthy
make help        # list all targets
```

Without `make`: `docker compose up -d --build --wait`. From a client:

```sh
curl -x http://<docker-host>:3128 https://example.com
export http_proxy=http://<docker-host>:3128 https_proxy=http://<docker-host>:3128
curl -x http://alice:secret@<docker-host>:3128 https://example.com   # with auth enabled
```

Do not expose port 3128 to the internet. If clients show up with a public IP in
`access.log` (`TCP_DENIED/403`), for example behind Docker Desktop networking or
a VPN, add a dedicated `acl ... src` rule instead of widening `localnet`.

## Configuration

| What | Where |
|---|---|
| Squid config | [squid/config/squid.conf](squid/config/squid.conf), mounted read-only; apply with `make reload` |
| Host port | `SQUID_PORT` in `.env` (default `3128`) |
| Basic auth | `SQUID_USER` and `SQUID_PASSWORD` in `.env` (empty disables it); apply with `make up` |
| Timezone | `TZ` in [squid/Dockerfile](squid/Dockerfile) (default `Europe/Warsaw`) |
| Extra config | mount single `*.conf` files into `/etc/squid/conf.d/`, not the whole directory (the entrypoint writes `auth.conf` there); they apply before the allow rules |

Example drop-in that blocks the Docker host and bridge gateway:

```
# /etc/squid/conf.d/block-host.conf
acl docker_host dst 192.0.2.10 172.17.0.1
http_access deny docker_host
```

| Host path | Container path | Content |
|---|---|---|
| `./var-spool-squid` | `/var/spool/squid` | 10 GB disk cache, kept across restarts |
| `./var-logs-squid` | `/var/log/squid` | `access.log`, `cache.log` |

The access log goes both to `make logs` and to the host file. Log files rotate
daily (7 kept, `access.log.0` to `.6`); `make rotate` rotates now. Container
stdout is capped at 3 × 10 MB. Clear the cache with
`make down && rm -rf var-spool-squid && make up`.

Squid reference: [configuration directives](https://www.squid-cache.org/Doc/config/),
[ACLs](https://wiki.squid-cache.org/Features/ACLs).

## Limitations

- No TLS interception, so HTTPS responses are not cached.
- No domain or content blocklist; add a drop-in with `acl blocked dstdomain .example.net` and `http_access deny blocked`.
- The Docker host's LAN address and the bridge gateway (e.g. `172.17.0.1`) are reachable unless you add a drop-in like the one above.
- The healthcheck (`squid -k check`) only confirms Squid is running, not that traffic passes.
- Basic auth sends credentials unencrypted to the proxy. The password is hashed (SHA-512 crypt) in the container, but the plain value shows in `docker inspect`. One user only, and a `:` or newline in `SQUID_USER` breaks it.
- Tests need internet access (`example.com`), so an outage there fails CI.
- Not tested: a client from a public IP being refused, the start-up failure with only one auth variable, `make reload` rejecting a bad config, log writing and rotation, the cache surviving a recreate, stale PID file cleanup, and `make test` cleaning up after a failure.
- The wrong-password check has not been sabotage-checked on its own (the missing-credentials check fails first).

## Development

```sh
make lint   # hadolint + shellcheck, in Docker
make test   # build, run the tests without and with auth (test/test), tear down
```

`make test` ignores `SQUID_*` from `.env`, publishes port `3128` (override with
`make test TEST_PORT=13128`), recreates and stops a running `squid` container,
tears down after a failure or Ctrl-C and prints the container logs on failure.
[scripts/test-proxy.sh](scripts/test-proxy.sh) checks that allowed traffic gets
`2xx` with a clean curl exit, that each deny rule returns `403` and that auth
returns `407`. It ignores `NO_PROXY` and `~/.curlrc`, so nothing bypasses the
proxy. Each deny rule and the auth check were removed once to confirm their test
fails. Run it against any proxy with `PROXY_URL`, `PROXY_USER` and
`PROXY_PASSWORD`. CI runs `make lint` and `make test`.

Built with an AI coding assistant. I wrote the spec and reviewed every change.

## License

MIT, see [LICENSE](LICENSE).
