#!/bin/bash
set -euo pipefail

# Bind-mounted host dirs are created as root; Squid runs as "proxy"
mkdir -p /var/spool/squid /var/log/squid
chown proxy:proxy /var/spool/squid /var/log/squid

# Container stdout is a root-only pipe; let Squid (as proxy) write its access log there
chown proxy /dev/stdout

# Optional basic auth: enabled when SQUID_USER and SQUID_PASSWORD are set.
# conf.d/*.conf is included before `http_access allow localnet`, so clients
# need both a private IP and valid credentials.
auth_conf=/etc/squid/conf.d/auth.conf
if [ -n "${SQUID_USER:-}" ] && [ -n "${SQUID_PASSWORD:-}" ]; then
	printf '%s:%s\n' "${SQUID_USER}" "$(printf '%s' "${SQUID_PASSWORD}" | openssl passwd -6 -stdin)" > /etc/squid/passwd
	chown root:proxy /etc/squid/passwd
	chmod 640 /etc/squid/passwd
	cat > "${auth_conf}" <<-'EOF'
		auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
		auth_param basic realm Squid proxy
		acl authenticated proxy_auth REQUIRED
		http_access deny !authenticated
	EOF
	echo "Basic auth enabled for user '${SQUID_USER}'"
elif [ -n "${SQUID_USER:-}${SQUID_PASSWORD:-}" ]; then
	echo "SQUID_USER and SQUID_PASSWORD must both be set" >&2
	exit 1
else
	rm -f "${auth_conf}" /etc/squid/passwd
fi

# Stale PID file survives container restarts and makes Squid refuse to start
rm -f /run/squid.pid

squid -k parse

# Create missing cache dirs (foreground, so it finishes before we start)
squid -N -z

# Daily log rotation; the loop outlives the exec below as a child of Squid
while sleep 86400; do squid -k rotate || true; done &

# Run in foreground as PID 1 so the container receives signals
exec squid -N -d 1 "$@"
