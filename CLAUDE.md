# CLAUDE.md

This repo is one of my ops tools. They are built with AI coding assistants: I own the
problem, the spec, the review and the verification; the assistant writes most of the code.
The point of every rule below is that the result must not be AI slop: small, correct,
tested where it matters, and honestly documented.

## This project

- **Problem:** a learning project: how a forward proxy works, the security side of blocking
  unwanted traffic with ACLs, and speeding up page loads by caching. Now shared as a lab
  for others learning the same; not a hardened production proxy.
- **Existing tools and why they don't fit:** [Ubuntu's Squid image](https://hub.docker.com/r/ubuntu/squid)
  can support the same proxy behavior with custom configuration and deployment wiring.
  This repo packages private-network ACLs, optional environment-based authentication,
  persistent HTTP caching, and host-visible logs with daily rotation in one Compose setup.
  [Tinyproxy](https://tinyproxy.github.io/) supports lightweight HTTP/HTTPS forwarding,
  client ACLs, and basic authentication, but does not provide Squid's persistent disk cache.
- **Runs where / against what:** a Docker host with Compose v2 (Linux; Docker Desktop on
  macOS for development), serving HTTP/HTTPS clients on private networks. CI runs on
  GitHub Actions `ubuntu-latest`. Image: `ubuntu:26.04` + distro Squid (7.x).
- **Trust boundaries:**
  - client requests (source IP, destination host/port, credentials): enforced only by the
    ACLs in `squid/config/squid.conf` and the `auth.conf` written by `squid/entrypoint.sh`
  - `SQUID_USER` / `SQUID_PASSWORD` from the environment: written into `/etc/squid/passwd`
  - the Docker host network: reachable from the container unless denied by a drop-in
  - upstream responses: stored in the disk cache and served to other clients
- **Out of scope:** TLS interception (ssl-bump), content filtering / blocklists, reverse
  proxy, multi-user account management, exposure to the internet, high availability.
- **Layout:** `squid/Dockerfile`, `squid/entrypoint.sh` (auth, PID cleanup, config check,
  daily rotate loop), `squid/config/squid.conf` (ACLs, mounted read-only), `docker-compose.yml`,
  `scripts/test-proxy.sh` (functional checks; Bash 3.2 compatible, all requests via `pcurl`).
- **Commands:** `make lint` (hadolint + shellcheck via Docker), `make test` (build, run
  `scripts/test-proxy.sh` without and with auth, tear down). Both run in CI. There are no
  unit tests; `make test` is the integration test, needs Docker and internet access
  (`example.com`), and recreates the container named `squid`.
- **Hard rules:** never add `http_access allow all`; every new ACL or feature gets a check
  in `scripts/test-proxy.sh`; config changes pass `squid -k parse`.
- **Releases:** none published yet. `CHANGELOG.md` is still kept per PR (add to `Unreleased`).

## Workflow

1. **Spec before code.** For any non-trivial change, write a short plan first (what, why,
   what could break, how it will be tested) and wait for my approval.
2. **Branch + PR, never `main`.** One logical change per PR. The PR description says what
   changed, why, and how it was verified.
3. **Ask, don't guess,** when the spec is ambiguous or a change touches a trust boundary.
4. **Record review decisions.** When I reject or change something you proposed, append one
   line to `docs/review-log.md`:
   `YYYY-MM-DD · PR #n · what was proposed · what I decided · why`.
   This log is the source for the "How this was built" section. Never invent entries.

## Minimal code (ponytail)

Ponytail is installed as a plugin. Before opening a PR, run `/ponytail-review` on the diff
and apply what it finds. Run `/ponytail-audit` on the whole repo before each release.

Prefer, in order: no code → existing code in this repo → standard library → a
well-known dependency → new code. Every new dependency needs one sentence of
justification in the PR.

**Never removed for the sake of brevity** (ponytail or otherwise):
- timeouts, retries, keepalives, cancellation and cleanup on network and process boundaries
- validation of anything crossing a trust boundary (input, remote output, LLM output)
- error handling that prevents data loss, partial writes or silent failures
- secret masking and security checks
- tests

If a shortcut is taken deliberately, mark it with a `ponytail:` comment explaining the
trade-off, so `/ponytail-debt` can find it.

## Testing

- **Every test must be able to fail.** When adding a test for a behavior, break that
  behavior on purpose, confirm the test fails, restore it, and say so in the PR
  ("sabotage check: removed X → test Y failed").
- **Test the failure modes of the domain,** not just the happy path: timeouts, silent
  connection drops, partial or malformed output, unreachable hosts, invalid LLM responses.
- No tests that only assert a mock was called. Assert observable behavior.
- Unit tests are deterministic and never touch the network. Integration tests live
  behind a build tag / marker and use disposable containers.
- Never skip, weaken or delete a failing test to make CI green. Fix the code or ask.

## CI (must be green before merge)

- **Go:** `gofmt`, `go vet`, `golangci-lint`, `go test -race ./...`, `govulncheck`
- **Python:** `ruff check`, `ruff format --check`, `pytest`, `pip-audit`
- **Shell / Docker:** `shellcheck`, `hadolint`
- Integration tests in a separate job.

## Data hygiene

- Only example data: `example.com` / `example.net`, RFC 5737 addresses
  (`192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24`), invented host and site names.
- No real hostnames, topologies, device counts, logs or configs from any employer.
- No secrets in the repo. Provide `.env.example`; secrets come from the environment.

## README structure

Keep this order. Write in plain English, no marketing.

1. **Title + one sentence:** what it does.
2. **Problem:** the real situation that caused it (2–4 sentences).
3. **Why not <existing tool>?** Fair comparison. Say what the existing tool can do
   with tuning; say what this tool makes the default.
4. **Quick start:** copy-paste commands that work on a clean machine.
5. **Usage / configuration.**
6. **Limitations:** what it does not handle, honestly.
7. **Testing:** how to run the tests, then a table `| Failure mode | Tests |` naming
   the test that covers each failure mode. A claim elsewhere in the README with no row
   here is a claim without proof.
8. **How this was built:** template below.
9. **License.**

Every claim in the README must be backed by code or a test. If you cannot point to it,
remove the claim. No invented benchmarks or numbers.

### "How this was built" template

```markdown
## How this was built

Built with an AI coding assistant. I wrote the problem statement and spec, reviewed
every PR, and designed the checks below.

**Spec:** <one paragraph: the constraints I set, e.g. "must not hang on a dead
connection", "LLM output is never trusted without validation">

**What I changed or rejected in review:** (from docs/review-log.md)
- <concrete decision + why, link to PR>
- <concrete decision + why, link to PR>

**What the tests are there to catch:**
- <failure mode> → <test name>, sabotage-checked

**What I don't trust yet / known gaps:**
- <honest gap>
```

Draft this section from `docs/review-log.md` and the tests. Leave placeholders for
anything I haven't decided. Never fill it with plausible-sounding invented decisions.

## Definition of done

- [ ] Spec approved, change on a branch, PR opened
- [ ] `/ponytail-review` applied, protected list untouched
- [ ] New behavior has a sabotage-checked test
- [ ] CI green
- [ ] README updated; every new claim backed by code or a test
- [ ] Review decisions logged in `docs/review-log.md`
- [ ] `CHANGELOG.md` updated, if the repo publishes releases

Reference implementation of these rules:
https://github.com/kmpoltorak/remote-command-orchestrator
