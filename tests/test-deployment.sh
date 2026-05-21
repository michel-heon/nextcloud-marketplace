#!/usr/bin/env bash
# tests/test-deployment.sh
# Smoke tests for a deployed Nextcloud VM.
# Usage: NEXTCLOUD_HOST=<ip_or_fqdn> bash tests/test-deployment.sh
set -euo pipefail

HOST="${NEXTCLOUD_HOST:-localhost}"
HTTP_URL="http://${HOST}"
HTTPS_URL="https://${HOST}"
TIMEOUT=15
PASS=0
FAIL=0

# --------------------------------------------------------------------------
pass() { echo "[PASS] $*"; ((PASS++)); }
fail() { echo "[FAIL] $*"; ((FAIL++)); }

# --------------------------------------------------------------------------
echo "=== Nextcloud Deployment Smoke Tests ==="
echo "Target host: ${HOST}"
echo ""

# 1. HTTP → HTTPS redirect
echo "--- Test: HTTP → HTTPS redirect ---"
location=$(curl --silent --insecure --max-time "${TIMEOUT}" \
                --output /dev/null \
                --write-out "%{redirect_url}" \
                --head "${HTTP_URL}/" || true)
if echo "${location}" | grep -q "^https://"; then
    pass "HTTP redirects to HTTPS (location: ${location})"
else
    fail "HTTP does not redirect to HTTPS (got: ${location})"
fi

# 2. HTTPS login page returns 200
echo "--- Test: HTTPS login page ---"
http_code=$(curl --silent --insecure --max-time "${TIMEOUT}" \
                 --output /dev/null --write-out "%{http_code}" \
                 "${HTTPS_URL}/login" || echo "000")
if [[ "${http_code}" == "200" ]]; then
    pass "HTTPS /login returns 200"
else
    fail "HTTPS /login returned ${http_code}"
fi

# 3. status.php reports installed=true
echo "--- Test: status.php installed ---"
status_body=$(curl --silent --insecure --max-time "${TIMEOUT}" \
                   "${HTTPS_URL}/status.php" 2>/dev/null || echo "{}")
if echo "${status_body}" | grep -q '"installed":true'; then
    pass "status.php reports installed=true"
else
    fail "status.php does not report installed=true (body: ${status_body})"
fi

# 4. status.php reports maintenance=false
echo "--- Test: status.php not in maintenance ---"
if echo "${status_body}" | grep -q '"maintenance":false'; then
    pass "status.php reports maintenance=false"
else
    fail "status.php reports maintenance mode is active"
fi

# 5. .well-known/carddav redirect
echo "--- Test: .well-known/carddav redirect ---"
dav_code=$(curl --silent --insecure --max-time "${TIMEOUT}" \
                --output /dev/null --write-out "%{http_code}" \
                "${HTTPS_URL}/.well-known/carddav" || echo "000")
if [[ "${dav_code}" == "301" || "${dav_code}" == "302" ]]; then
    pass ".well-known/carddav redirects (${dav_code})"
else
    fail ".well-known/carddav returned unexpected ${dav_code}"
fi

# 6. Security headers present
echo "--- Test: security headers ---"
headers=$(curl --silent --insecure --max-time "${TIMEOUT}" \
               --head "${HTTPS_URL}" 2>/dev/null || true)

if echo "${headers}" | grep -qi "strict-transport-security"; then
    pass "HSTS header present"
else
    fail "HSTS header missing"
fi
if echo "${headers}" | grep -qi "x-content-type-options"; then
    pass "X-Content-Type-Options header present"
else
    fail "X-Content-Type-Options header missing"
fi
if echo "${headers}" | grep -qi "x-frame-options"; then
    pass "X-Frame-Options header present"
else
    fail "X-Frame-Options header missing"
fi

# --------------------------------------------------------------------------
echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [[ "${FAIL}" -gt 0 ]]; then
    exit 1
fi
exit 0
