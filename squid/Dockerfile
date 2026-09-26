FROM ubuntu:26.04

ENV TZ="Europe/Warsaw"

# hadolint ignore=DL3008
RUN apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends squid tzdata \
	&& ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" > /etc/timezone \
	&& rm -rf /var/lib/apt/lists/*

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh
COPY config/squid.conf /etc/squid/squid.conf

EXPOSE 3128/tcp

# Signal 0 to the running Squid master process (via its PID file)
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
	CMD ["squid", "-k", "check"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
