# Copilot instructions — squid-proxy-docker

Goal

- Automatically build and test a simple Docker image running a Squid proxy.
- Provide guidance for Copilot Actions (if using GitHub Copilot Actions) about what should be generated or reviewed.

Project context

- A simple Dockerfile in `squid/Dockerfile` runs Squid.
- The configuration in `squid/config/squid.conf` contains ACL rules and listens on port 3128.
- `docker-compose.yml` runs the `squid` service and mounts `./var-spool-squid` as the cache volume.
- `scripts/test-proxy.sh` performs a basic test using `curl --proxy` to `http://example.com` and prints response headers and the beginning of the response body.

Tasks Copilot Actions can perform (priority order)

1. Maintain and update the CI workflow
   - `/.github/workflows/ci.yml` — build the image, run `docker compose up --build -d`, run `./scripts/test-proxy.sh`, and tear down.
   - Optionally add lint steps: `shellcheck` for shell scripts and `hadolint` for the Dockerfile.

2. Add integration tests in CI (optional)
   - Run tests in an isolated environment (Docker-in-Docker or using `services`) and ensure `curl` through the proxy returns HTTP 200.

3. Suggest improvements to the Squid configuration (for example, ACL hardening) and propose small, low-risk improvements to `entrypoint.sh`.

Requirements and constraints

- Do not assume private secrets are present in the repository. If secrets are required (for example for authentication), request additional instructions.
- The CI workflow should run on `ubuntu-latest` and use official actions (`actions/checkout`, `docker/setup-buildx-action`).

Expected change format

- Generated files should be PR-able (commits with descriptive messages) and testable locally.
- Each workflow change should include a short description of what it does and why.

Contact

- Target branch: `main`.
- If appropriate, create PRs with the `ci` or `infra` label.
