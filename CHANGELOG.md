# Changelog

No versioned releases yet; entries are grouped by the date the PRs were merged.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Unreleased

### Added
- `CLAUDE.md` with the project rules, `docs/review-log.md`, this changelog.

### Changed
- README reorganised: problem, comparison with ubuntu/squid and Tinyproxy, limitations,
  failure-mode test table, "How this was built".
- Documentation examples use RFC 5737 addresses.

### Fixed
- The `Safe_ports` test could not fail; see "How this was built" in the README.

## 2026-09-26

### Changed
- Base image `ubuntu` 24.04 → 26.04, which ships Squid 7 ([#3](https://github.com/kmpoltorak/squid-proxy-docker/pull/3)).
- CI: `actions/checkout` 6 → 7 ([#4](https://github.com/kmpoltorak/squid-proxy-docker/pull/4)).

### Added ([#2](https://github.com/kmpoltorak/squid-proxy-docker/pull/2))
- Optional basic auth via `SQUID_USER` / `SQUID_PASSWORD`, `.env.example`.
- Deny rules for the container's loopback (`to_localhost`) and link-local targets (`to_linklocal`).
- Access log to the host file and to container stdout; daily `squid -k rotate`, 7 files kept;
  Compose `json-file` log cap.
- Docker healthcheck; `make` targets `up`, `down`, `restart`, `reload`, `rotate`, `logs`, `lint`, `test`.
- Functional tests for denied targets, `CONNECT` to non-SSL ports and auth (`407`);
  `make test` runs without and with auth and always tears down.
- Dependabot for GitHub Actions and the Docker base image.

### Changed ([#2](https://github.com/kmpoltorak/squid-proxy-docker/pull/2))
- Allowed-traffic checks need curl exit 0 and a `2xx`; `NO_PROXY` and `~/.curlrc` cannot bypass the proxy.
- Lint blocks CI; hadolint and shellcheck versions are pinned and run in Docker.
- CI runs `make test` instead of its own wait-for-port steps.

## 2026-01-05

### Added ([#1](https://github.com/kmpoltorak/squid-proxy-docker/pull/1))
- GitHub Actions CI: builds the Compose stack and checks that an HTTP request goes through the proxy.
- Non-blocking hadolint and shellcheck, `make test`, `scripts/test-proxy.sh`, `.github/copilot-instructions.md`.
- Official Squid documentation links in the README.

### Changed ([#1](https://github.com/kmpoltorak/squid-proxy-docker/pull/1))
- Entrypoint creates the spool directory, fixes ownership, runs `squid -z` and keeps Squid in the foreground.
- Dockerfile: non-interactive apt, apt lists cleaned; `docker-compose.yml` without the top-level `version:`.
- ACL and comment typos fixed in `squid.conf`.
