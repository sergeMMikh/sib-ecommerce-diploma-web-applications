#!/usr/bin/env bash
set -u

BASE_URL="${BASE_URL:-http://127.0.0.1:9999}"
TEST_USER_PASS="${TEST_USER_PASS:-Test1234}"
TEST_MANAGER_PASS="${TEST_MANAGER_PASS:-Manager1234}"

redact_json_token() {
  jq 'if type=="object" and has("token") then .token="[REDACTED]" else . end'
}

req() {
  local label="$1"; shift
  echo
  echo "===== $label ====="
  curl -sS -i "$@"
}

# The application expects the raw token value in Authorization, without a Bearer prefix.
# Do not save raw tokens to evidence files.

if [[ -z "${ADMIN_PASS:-}" ]]; then
  read -r -s -p "Admin password from local startup log: " ADMIN_PASS
  echo
fi

# Register disposable ROLE_USER accounts. If they already exist, restart the disposable stand or reuse login below.
USER_A_REG=$(curl -sS -X POST \
  --get \
  --data-urlencode "login=userA" \
  --data-urlencode "pass=${TEST_USER_PASS}" \
  --data-urlencode "name=UserA" \
  "${BASE_URL}/api/users/registration")
echo "$USER_A_REG" | redact_json_token

USER_B_REG=$(curl -sS -X POST \
  --get \
  --data-urlencode "login=userB" \
  --data-urlencode "pass=${TEST_USER_PASS}" \
  --data-urlencode "name=UserB" \
  "${BASE_URL}/api/users/registration")
echo "$USER_B_REG" | redact_json_token

# Always authenticate again and keep current tokens only in shell variables.
TOKEN_A=$(curl -sS -X POST --get \
  --data-urlencode "login=userA" \
  --data-urlencode "pass=${TEST_USER_PASS}" \
  "${BASE_URL}/api/users/authentication" | jq -r '.token')
TOKEN_B=$(curl -sS -X POST --get \
  --data-urlencode "login=userB" \
  --data-urlencode "pass=${TEST_USER_PASS}" \
  "${BASE_URL}/api/users/authentication" | jq -r '.token')
ADMIN_TOKEN=$(curl -sS -X POST --get \
  --data-urlencode "login=admin" \
  --data-urlencode "pass=${ADMIN_PASS}" \
  "${BASE_URL}/api/users/authentication" | jq -r '.token')

# Create manager using the admin-only endpoint. Repeated roles parameter is compatible with Collection<String> binding.
curl -sS -o /tmp/necommerce-manager-create.json -w 'manager creation -> %{http_code}\n' \
  -X POST \
  -H "Authorization: ${ADMIN_TOKEN}" \
  --get \
  --data-urlencode "login=manager1" \
  --data-urlencode "pass=${TEST_MANAGER_PASS}" \
  --data-urlencode "name=Manager" \
  --data-urlencode "avatar=netology.jpg" \
  --data-urlencode "roles=ROLE_MANAGER" \
  "${BASE_URL}/api/users/creation"

MANAGER_TOKEN=$(curl -sS -X POST --get \
  --data-urlencode "login=manager1" \
  --data-urlencode "pass=${TEST_MANAGER_PASS}" \
  "${BASE_URL}/api/users/authentication" | jq -r '.token')

# Authentication negative case.
req "AUTH-01 invalid credentials" \
  -X POST --get \
  --data-urlencode "login=userA" \
  --data-urlencode "pass=wrong-password" \
  "${BASE_URL}/api/users/authentication"

# Read-only role matrix.
req "AUTH-02 anonymous GET /api/orders" "${BASE_URL}/api/orders"
req "AUTH-03 userA GET /api/orders" -H "Authorization: ${TOKEN_A}" "${BASE_URL}/api/orders"
req "AUTH-04 manager GET /api/orders" -H "Authorization: ${MANAGER_TOKEN}" "${BASE_URL}/api/orders"
req "AUTH-05 userA GET /api/orders/my" -H "Authorization: ${TOKEN_A}" "${BASE_URL}/api/orders/my"

# Create two disposable orders for object-level authorization tests.
ORDER_A=$(curl -sS -X POST \
  -H "Authorization: ${TOKEN_A}" \
  --get \
  --data-urlencode "productId=1" \
  --data-urlencode "phone=79990000001" \
  "${BASE_URL}/api/orders")
ORDER_A_ID=$(echo "$ORDER_A" | jq -r '.id // empty')
echo "userA order id: ${ORDER_A_ID:-<not-created>}"

ORDER_B=$(curl -sS -X POST \
  -H "Authorization: ${TOKEN_B}" \
  --get \
  --data-urlencode "productId=1" \
  --data-urlencode "phone=79990000002" \
  "${BASE_URL}/api/orders")
ORDER_B_ID=$(echo "$ORDER_B" | jq -r '.id // empty')
echo "userB order id: ${ORDER_B_ID:-<not-created>}"

if [[ -n "${ORDER_A_ID:-}" ]]; then
  req "AUTH-08 anonymous reads userA order" "${BASE_URL}/api/orders/${ORDER_A_ID}"
  req "AUTH-09 userB reads userA order" -H "Authorization: ${TOKEN_B}" "${BASE_URL}/api/orders/${ORDER_A_ID}"
  req "AUTH-10 userA reads own order" -H "Authorization: ${TOKEN_A}" "${BASE_URL}/api/orders/${ORDER_A_ID}"
fi

# Privilege escalation attempt: ROLE_USER tries admin-only user creation.
req "AUTH-13 userA attempts ROLE_ADMIN creation" \
  -X POST \
  -H "Authorization: ${TOKEN_A}" \
  --get \
  --data-urlencode "login=escalation-test" \
  --data-urlencode "pass=${TEST_USER_PASS}" \
  --data-urlencode "name=EscalationTest" \
  --data-urlencode "avatar=netology.jpg" \
  --data-urlencode "roles=ROLE_ADMIN" \
  "${BASE_URL}/api/users/creation"

# Destructive product-delete tests are deliberately NOT run automatically.
# The anonymous case has already been reproduced manually and returned HTTP 200.
# To retest on a disposable/reset stand, run one actor at a time and verify GET afterwards:
# curl -i -X DELETE "${BASE_URL}/api/products/1"
# curl -i -X DELETE -H "Authorization: ${TOKEN_A}" "${BASE_URL}/api/products/1"
# curl -i -X DELETE -H "Authorization: ${ADMIN_TOKEN}" "${BASE_URL}/api/products/1"

echo
echo "Raw tokens were kept only in shell variables. Do not redirect this script with shell tracing enabled."
