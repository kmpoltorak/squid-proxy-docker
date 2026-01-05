# squid-proxy-docker

Lightweight Docker setup for a Squid caching proxy.

## Quick start

1. Build and run with docker-compose:

```sh
docker compose up --build -d
```

2. Check container logs:

```sh
docker compose logs -f squid
```

3. The proxy listens on port 3128 (host:3128 -> container:3128).

## Persistance cache

This compose uses a host volume `./var-spool-squid` mounted to `/var/spool/squid` to keep Squid's cache between restarts.

## Logs

Squid writes runtime logs under `/var/log/squid` inside the container (for example `access.log` and `cache.log`). The Compose configuration mounts that folder to `./var-logs-squid` on the host so you can inspect logs directly:

```sh
# Follow logs from the host
tail -f ./var-logs-squid/access.log ./var-logs-squid/cache.log

# Or view recent lines
ls -l ./var-logs-squid
tail -n 200 ./var-logs-squid/access.log
```

If you prefer not to persist logs to the host, remove the `./var-logs-squid:/var/log/squid` volume mapping in `docker-compose.yml`.

## Configuration

Customize `squid/config/squid.conf` to change access rules or other settings. The container's entrypoint will append DNS servers from `/etc/resolv.conf` to the Squid config if `dns_nameservers` is not already present.

## Running the quick functional test

A simple test harness is provided to validate that the proxy forwards HTTP requests. To run it locally:

```sh
make test
```

This target will start the compose setup, run `scripts/test-proxy.sh` (which attempts a `curl` through the proxy and prints response headers + a short body preview), and tear the environment down. The script exits non-zero if the proxy doesn't respond within a short timeout.

You can also run the script directly:

```sh
chmod +x ./scripts/test-proxy.sh
./scripts/test-proxy.sh
```

## Official Squid documentation

For authoritative reference and advanced configuration details, consult the official Squid resources:

- Project website: https://www.squid-cache.org/
- Documentation & wiki: https://wiki.squid-cache.org/
	- Configuration examples: https://wiki.squid-cache.org/ConfigExamples
	- ACLs and access controls: https://wiki.squid-cache.org/Features/ACLs
	- Storage and cache tuning: https://wiki.squid-cache.org/ConfigExamples/Storage
	- Security and best practices: https://wiki.squid-cache.org/SquidFaq/Security

If you need help tuning Squid for production use (cache sizing, ACL hardening, authentication, TLS interception, logging), the Squid wiki and mailing lists are the best next steps.

