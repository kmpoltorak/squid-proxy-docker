#!/usr/bin/env bash
set -euo pipefail

# Simple check that Squid proxy forwards HTTP requests
# Usage: ./scripts/test-proxy.sh

PROXY_URL="http://localhost:3128"
TARGET_URL="http://example.com/"
TIMEOUT=60
INTERVAL=1

echo "Waiting up to ${TIMEOUT}s for proxy at ${PROXY_URL} to respond..."
START=$SECONDS
while [ $((SECONDS - START)) -lt ${TIMEOUT} ]; do
  if curl -s -f --proxy "${PROXY_URL}" "${TARGET_URL}" -o /tmp/proxy_body -D /tmp/proxy_headers; then
    echo "Proxy responded successfully"
    echo
    echo "=== Response headers ==="
    sed -n '1,200p' /tmp/proxy_headers || true
    echo
    echo "=== Body (first 500 bytes) ==="
    head -c 500 /tmp/proxy_body || true
    echo
    echo "(truncated)"
    exit 0
  fi
  sleep ${INTERVAL}
done

echo "Proxy did not respond within ${TIMEOUT}s" >&2
exit 1
