#!/bin/bash
set -euo pipefail

# Ensure spool directory exists and has correct ownership
mkdir -p /var/spool/squid
chown -R proxy:proxy /var/spool/squid

# If squid.conf exists, append dns_nameservers from /etc/resolv.conf when missing
if [ -f /etc/squid/squid.conf ]; then
	if ! grep -q '^dns_nameservers' /etc/squid/squid.conf; then
		names=$(awk '/^nameserver/ {print $2}' /etc/resolv.conf | xargs)
		if [ -n "${names}" ]; then
			echo "dns_nameservers ${names}" >> /etc/squid/squid.conf
		fi
	fi
fi

# Initialize cache directories and start squid in foreground (so container receives signals)
squid -z
sleep 2
exec squid -N -d 1
