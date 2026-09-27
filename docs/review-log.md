# Review log

One line per review decision on an AI-proposed change:
`YYYY-MM-DD · PR #n · what was proposed · what I decided · why`

Entries for PR #1/#2 are reconstructed from the PR descriptions and the code in each PR;
there were no review comments. "why" is left as `not recorded` where the PR does not state it.

2026-09-26 · PR #2 · linters non-blocking (`|| true`, `hadolint:latest`), "run as warning initially" (PR #1 follow-up) · lint blocks CI, tool versions pinned, `|| true` banned in copilot-instructions · not recorded
2026-09-26 · PR #2 · test = one `curl -f` to `http://example.com/` (PR #1) · allowed traffic needs curl exit 0 and a `2xx`; denials and auth checked; `NO_PROXY`/`.curlrc` cannot bypass the proxy · a TLS error or `500` after `CONNECT 200` passed the old test
2026-09-26 · PR #2 · CI wait-for-port loop, switch to DinD if flaky (PR #1) · compose `--wait` on the healthcheck; CI runs `make test` with a cleanup trap; no DinD · CI should not duplicate `make test`
2026-09-26 · PR #2 · "harden Squid ACLs based on the intended deployment" (PR #1 follow-up) · deny `to_localhost` and `to_linklocal`; document that Docker host/gateway addresses are not covered · not recorded
2026-09-26 · PR #3 · Dependabot: `ubuntu` 24.04 → 26.04 (Squid 6 → 7) · merged on green CI · not recorded
2026-09-27 · PR #5 · leave Spec / review decisions / known gaps in README as `TODO(owner)` · fill them from PRs #1–#4 and log the reconstructed decisions here · not recorded
2026-09-27 · PR #5 · no `CHANGELOG.md` because no releases are published · keep `CHANGELOG.md` per PR, reconstructed from PR history · not recorded
