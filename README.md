# squid-proxy-docker

Lightweight Docker setup for a Squid caching proxy.

## Quick start

1. Build and run with docker-compose:

```sh
docker-compose up --build -d
```

2. Check logs:

```sh
docker logs -f squid
```

3. The proxy listens on port 3128 (host:3128 -> container:3128).

## Persistence

This compose uses a host volume `./var-spool-squid` mounted to `/var/spool/squid` to keep Squid's cache between restarts.

# squid-proxy-docker

Lightweight Docker setup for a Squid caching proxy.

## Quick start

1. Build and run with docker-compose:

```sh
docker-compose up --build -d
```

2. Check logs:

```sh
docker logs -f squid
```

3. The proxy listens on port 3128 (host:3128 -> container:3128).

## Persistence

This compose uses a host volume `./var-spool-squid` mounted to `/var/spool/squid` to keep Squid's cache between restarts.

## Configuration

Customize `squid/config/squid.conf` to change access rules or other settings. The container's entrypoint will append DNS servers from `/etc/resolv.conf` to the Squid config if `dns_nameservers` is not already present.

## Notes

If you change the Dockerfile or entrypoint, rebuild with `docker-compose build squid`.

## Running the quick functional test

I added a small test harness. To run it locally:

```sh
make test
```

This target will start the compose setup, try a simple HTTP request through the proxy (using `curl`), and tear the environment down. It returns non-zero if the proxy doesn't respond within a short timeout.

## Official Squid documentation

For authoritative reference and advanced configuration details, consult the official Squid documentation and resources:

- Squid project: https://www.squid-cache.org/
- Squid wiki (manual & docs): https://wiki.squid-cache.org/
	- Configuration examples: https://wiki.squid-cache.org/ConfigExamples
	- ACLs and access controls: https://wiki.squid-cache.org/Features/ACLs
	- Storage and cache tuning: https://wiki.squid-cache.org/ConfigExamples/Storage
	- Security and best practices: https://wiki.squid-cache.org/SquidFaq/Security

If you need help tuning Squid for production use (cache sizing, ACL hardening, authentication, TLS interception, logging), the Squid wiki, documentation, and mailing lists are the best next steps.
