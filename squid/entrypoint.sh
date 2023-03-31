#!/bin/bash
# Exit immediately if a command exits with a non-zero status
set -e

# Setup proper DNS server in squid.conf file
grep -q 'dns_nameservers' '/etc/squid/squid.conf' || echo dns_nameservers $(cat /etc/resolv.conf | grep nameserver | cut -d " " -f2) >> /etc/squid/squid.conf

# Set proper ownership of directory for cashing
chown proxy:proxy /var/spool/squid

# Create swap directories, wait, start squid as non-daemon and set debug level 1
squid -z; sleep 20; squid -N -d 1 

# Tail Squid logs to keep the container running
tail -f /var/log/squid/access.log /var/log/squid/cache.log
