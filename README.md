# squid-proxy-docker

[![CI](https://github.com/kmpoltorak/squid-proxy-docker/actions/workflows/ci.yml/badge.svg)](https://github.com/kmpoltorak/squid-proxy-docker/actions/workflows/ci.yml)

A [Squid](https://www.squid-cache.org/) caching forward proxy in Docker (Ubuntu 26.04, distro Squid), restricted to private-network clients.

## Problem

I built this to learn three things hands-on: how a forward proxy works, how to block unwanted traffic
with Squid ACLs, and how caching speeds up page loads. The repo is that lab, shared for anyone learning the
same: private-network ACLs, deny rules checked by tests, a persistent HTTP cache and access logs on the host.
Caching only helps plain HTTP; HTTPS goes through a `CONNECT` tunnel and is not cached (see Limitations).

## Why not ubuntu/squid or Tinyproxy?

[ubuntu/squid](https://hub.docker.com/r/ubuntu/squid) runs the same Squid and can do everything this
repo does with your own `squid.conf` and Compose wiring. [Tinyproxy](https://tinyproxy.github.io/)
handles HTTP/HTTPS forwarding, client ACLs and basic auth with less overhead, but has no disk cache.

What this repo makes the default in one Compose setup:

- access limited to private source networks (RFC 1918, CGN, link-local, IPv6 ULA)
- the container's own loopback and link-local targets (e.g. cloud metadata `169.254.169.254`) are denied
- optional basic auth from two environment variables
- access log both to `docker compose logs` and to a file on the host, rotated daily
- persistent 10 GB disk cache, config mounted read-only and reloadable without rebuild

## Quick start

Requirements: Docker with Compose v2 (`--wait`), GNU make, curl and Bash 3.2+ for the tests.

```sh
cp .env.example .env
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

### Blocked targets

`to_localhost` covers the loopback of the Squid container only. The Docker host's LAN address and the
Docker bridge gateway (e.g. `172.17.0.1`) are **not** blocked; whether they are reachable depends on your
routing and firewall. To block them, mount a drop-in (snippets are applied before the allow rules):

```
# /etc/squid/conf.d/block-host.conf
acl docker_host dst 192.0.2.10 172.17.0.1
http_access deny docker_host
```

### Authentication

With `SQUID_USER` and `SQUID_PASSWORD` set, clients need **both** a private IP and valid credentials
(unauthenticated requests get `407`). Setting only one of them makes the container exit at start.
Apply changes with `make up` (the container is recreated):

```sh
curl -x http://alice:secret@<docker-host>:3128 https://example.com
```

> **Security:** only clients from private address ranges are allowed. Do not expose port 3128 to the internet.
> If your clients show up with a public IP in `access.log` (`TCP_DENIED/403`), for example because of
> Docker Desktop networking or a VPN, add a dedicated `acl ... src` rule instead of widening `localnet`.

### Cache and logs

| Host path | Container path | Content |
|-----------|----------------|---------|
| `./var-spool-squid` | `/var/spool/squid` | disk cache |
| `./var-logs-squid` | `/var/log/squid` | `access.log`, `cache.log` |

```sh
make logs                          # docker compose logs -f squid
tail -f var-logs-squid/access.log  # same entries, from the host
```

To clear the cache: `make down && rm -rf var-spool-squid && make up`.

Log files are rotated daily by the container (`squid -k rotate`, 7 old files kept as `access.log.0`…`.6`);
`make rotate` rotates on demand. Container stdout logs are capped by Compose (`json-file`, 3 × 10 MB).

### Squid documentation

- Documentation & wiki: https://wiki.squid-cache.org/
- Configuration directives: https://www.squid-cache.org/Doc/config/
- ACLs and access controls: https://wiki.squid-cache.org/Features/ACLs

## Limitations

- No TLS interception: HTTPS is tunnelled with `CONNECT`, so HTTPS responses are not cached.
- The Docker host's LAN address and bridge gateway are reachable unless you add a drop-in (see above).
- The healthcheck (`squid -k check`) only confirms the Squid process is running, not that traffic passes.
- Basic auth sends credentials unencrypted to the proxy. The password is hashed (SHA-512 crypt) inside the
  container, but the plain value is visible in `docker inspect`. One user only.
- `SQUID_USER` is written to the password file as-is; a `:` or newline in it breaks authentication.
- The tests need internet access (`example.com`); there are no offline tests.

## Testing

```sh
make lint   # hadolint + shellcheck, run in Docker
make test   # build, run scripts/test-proxy.sh without and with auth (test/test), tear down
```

`make test` ignores `SQUID_*` from `.env`, always publishes port `3128` (override with
`make test TEST_PORT=13128`), tears down also after a failed start or Ctrl-C, and prints container logs on
failure. It recreates the `squid` container, so a running proxy is stopped. CI runs both targets.

Against a running proxy:

```sh
PROXY_URL=http://192.0.2.5:3128 PROXY_USER=alice PROXY_PASSWORD=secret ./scripts/test-proxy.sh
```

[scripts/test-proxy.sh](scripts/test-proxy.sh) exits non-zero on the first failed check. It ignores
`NO_PROXY` and `~/.curlrc`, so every request goes through the proxy under test.

| Failure mode | Tests (in `scripts/test-proxy.sh`) |
|--------------|-------|
| Proxy up but not forwarding HTTP / HTTPS | `expect_ok http://example.com/`, `expect_ok https://example.com/` |
| Client reaches the Squid container's own loopback | `expect_code 403 http://127.0.0.1:3128/` |
| Client reaches cloud metadata / link-local | `expect_code 403 http://169.254.169.254/` |
| Request to a port outside `Safe_ports` | `expect_code 403 http://example.com:25/` |
| `CONNECT` tunnel to a non-SSL port | `expect_code 403 https://example.com:80/` |
| Auth enabled, request without credentials accepted | `expect_code 407 http://example.com/` |
| Auth enabled, wrong password accepted | `expect_code 407 ... --proxy-user test:wrong-test` |
| Client from a public IP allowed | not tested (the test client is always on a private network) |
| Only one of `SQUID_USER`/`SQUID_PASSWORD` set | not tested (entrypoint exits 1) |
| Invalid config applied by `make reload` | not tested (`squid -k parse` runs first) |
| Access log not written to the host file or to container stdout | not tested (`access_log` lines in `squid.conf`) |
| Log rotation stops | not tested (loop in `entrypoint.sh`) |
| Disk cache lost when the container is recreated | not tested (bind mount in `docker-compose.yml`) |
| Container fails to restart because of a stale PID file | not tested (`rm -f /run/squid.pid` in `entrypoint.sh`) |
| `make test` leaves the container running after a failure | not tested (`trap` in `Makefile`) |

## How this was built

Built with an AI coding assistant. I wrote the problem statement and spec, reviewed
every PR, and designed the checks below.

**Spec:** Access policy stays restrictive: private source networks only, never `http_access allow all`.
Every ACL or feature gets a check in `scripts/test-proxy.sh`. The tests must not pass on a false positive:
curl must exit cleanly, the target must return `2xx`, and `NO_PROXY` or `~/.curlrc` must not route around the
proxy. The script runs on macOS Bash 3.2. Lint blocks CI, config changes pass `squid -k parse`, and there are
no secrets in the repo.

**What I changed or rejected in review:** (from [docs/review-log.md](docs/review-log.md))
- Had the Spec, review and known-gaps sections filled from PR history instead of left as placeholders,
  and kept a `CHANGELOG.md` although nothing is released ([#5](https://github.com/kmpoltorak/squid-proxy-docker/pull/5)).

**What changed between the first and second version:** the assistant revised its own first version
([#1](https://github.com/kmpoltorak/squid-proxy-docker/pull/1)) in
[#2](https://github.com/kmpoltorak/squid-proxy-docker/pull/2); these were not review decisions.
- Lint went from warnings (`|| true`, `hadolint:latest`) to blocking, with pinned tool versions.
- The test went from a single `curl -f` to checking exit code + `2xx`, the deny rules and auth, without a
  way to bypass the proxy. A TLS error or `500` after `CONNECT 200` passed the old test.
- The CI wait-for-port loop (and the proposed DinD fallback) became the healthcheck plus `make test`, so CI
  and local runs are the same.
- The container's loopback and link-local targets are denied, and the README says Docker host addresses
  need a drop-in.

**What the tests are there to catch:** each deny rule or auth check was removed on purpose and the test
below failed, then it was restored.
- loopback target allowed → `expect_code 403 http://127.0.0.1:3128/` (got `400`), sabotage-checked
- link-local / metadata target allowed → `expect_code 403 http://169.254.169.254/` (got `503`), sabotage-checked
- `Safe_ports` not enforced → `expect_code 403 http://example.com:25/`, sabotage-checked
- `CONNECT` to non-SSL port allowed → `expect_code 403 https://example.com:80/` (got `200`), sabotage-checked
- auth not enforced → `expect_code 407 http://example.com/` (got `200`), sabotage-checked
- proxy unreachable → `expect_ok` fails with curl exit 7, sabotage-checked

The sabotage checks found one test that could not fail. The `Safe_ports` check used to send `CONNECT` to
port 25, but `CONNECT !SSL_ports` blocks that request before `Safe_ports` is evaluated, so removing
`http_access deny !Safe_ports` left every test green. The check now sends a plain `GET` to port 25, which only
`Safe_ports` denies, and removing the rule makes it fail
([#5](https://github.com/kmpoltorak/squid-proxy-docker/pull/5)).

**What I don't trust yet / known gaps:**
- the wrong-password check was not sabotage-checked on its own (the missing-credentials check fails first)
- the rows marked "not tested" in the table above
- the tests depend on `example.com` and the runner's internet access, so an outage there fails CI
- the Ubuntu 26.04 / Squid 7 bump ([#3](https://github.com/kmpoltorak/squid-proxy-docker/pull/3)) was merged on
  green CI only; the sabotage checks above were run on Squid 7.2 afterwards

## License

[MIT](LICENSE)
