#!/usr/bin/env bash
set -euo pipefail

# Functional tests for the Squid proxy: allowed traffic, blocked targets and
# (when PROXY_USER/PROXY_PASSWORD are set) basic auth. Works with Bash 3.2+.
# Usage: PROXY_URL=http://host:3128 [PROXY_USER=u PROXY_PASSWORD=p] ./scripts/test-proxy.sh

PROXY_URL="${PROXY_URL:-http://localhost:3128}"
TIMEOUT="${TIMEOUT:-60}"
PROXY_USER="${PROXY_USER:-}"
PROXY_PASSWORD="${PROXY_PASSWORD:-}"

auth=()
[ -n "${PROXY_USER}" ] && auth=(--proxy-user "${PROXY_USER}:${PROXY_PASSWORD}")

# -q ignores ~/.curlrc, --noproxy '' stops NO_PROXY from bypassing the proxy under test
pcurl() {
  curl -q -s -o /dev/null -m 10 --noproxy '' --proxy "${PROXY_URL}" "$@"
}

# Retries until the proxy is up; needs a clean curl exit and a 2xx from the target
expect_ok() {
  local target=$1 start=$SECONDS code='' rc=''
  while (( SECONDS - start < TIMEOUT )); do
    # ${auth[@]+...}: empty arrays trip `set -u` in Bash 3.2 (macOS)
    rc=0; code=$(pcurl -w '%{http_code}' ${auth[@]+"${auth[@]}"} "${target}") || rc=$?
    if [ "${rc}" -eq 0 ] && [[ ${code} == 2* ]]; then
      echo "  OK   ${target} -> ${code}"
      return 0
    fi
    sleep 1
  done
  echo "  FAIL ${target} -> ${code:-none} (curl exit ${rc:-none}), expected 2xx" >&2
  return 1
}

# Expects Squid to reply with a given code; for https:// that is the CONNECT reply,
# so curl itself failing afterwards is expected
expect_code() {
  local want=$1 target=$2 fmt='%{http_code}' code
  shift 2
  [[ ${target} == https://* ]] && fmt='%{http_connect}'
  code=$(pcurl -w "${fmt}" "$@" "${target}" || true)
  if [ "${code}" = "${want}" ]; then
    echo "  OK   ${target} -> ${code}"
  else
    echo "  FAIL ${target} -> ${code}, expected ${want}" >&2
    return 1
  fi
}

echo "Testing proxy ${PROXY_URL}${PROXY_USER:+ as ${PROXY_USER}}"

echo "Allowed traffic:"
expect_ok "http://example.com/"
expect_ok "https://example.com/"

echo "Blocked targets:"
expect_code 403 "http://127.0.0.1:3128/" ${auth[@]+"${auth[@]}"}    # proxy's own loopback
expect_code 403 "http://169.254.169.254/" ${auth[@]+"${auth[@]}"}   # cloud metadata
expect_code 403 "http://example.com:25/" ${auth[@]+"${auth[@]}"}    # port not in Safe_ports (plain GET, not CONNECT)
expect_code 403 "https://example.com:80/" ${auth[@]+"${auth[@]}"}   # CONNECT to non-SSL port

if [ -n "${PROXY_USER}" ]; then
  echo "Authentication:"
  expect_code 407 "http://example.com/"
  expect_code 407 "http://example.com/" --proxy-user "${PROXY_USER}:wrong-${PROXY_PASSWORD}"
fi

echo "All proxy checks passed"
