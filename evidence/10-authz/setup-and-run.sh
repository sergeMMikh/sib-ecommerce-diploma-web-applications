#!/usr/bin/env bash
set -u

BASE_URL="${BASE_URL:-http://127.0.0.1:9999}"
TEST_USER_PASS="${TEST_USER_PASS:-Test1234}"
TEST_MANAGER_PASS="${TEST_MANAGER_PASS:-Manager1234}"

req() {
  local label="$1"; shift
  echo
  echo "===== $label ====="
  curl -sS -i "$@"
}

get_token() {
  local login="$1"
  local pass="$2"
  curl -sS -X POST --get \
    --data-urlencode "login=${login}" \
    --data-urlencode "pass=${pass}" \
    "${BASE_URL}/api/users/authentication" | jq -r '.token // empty'
}

ensure_user() {
  local login="$1"
  local name="$2"
  local pass="$3"
  local token
  token=$(get_token "$login" "$pass")
  if [[ -n "$token" ]]; then
    echo "$login already exists; reusing account"
    return 0
  fi
  local response
  response=$(curl -sS -X POST --get \
    --data-urlencode "login=${login}" \
    --data-urlencode "pass=${pass}" \
    --data-urlencode "name=${name}" \
    "${BASE_URL}/api/users/registration")
  echo "$response" | jq 'if type=="object" and has("token") then .token="[REDACTED]" else . end'
}

if [[ -z "${ADMIN_PASS:-}" ]]; then
  read -r -s -p "Admin password from local startup log: " ADMIN_PASS
  echo
fi

# The application expects the raw token value in Authorization, without a Bearer prefix.
# Raw token values are kept only in shell variables and never printed intentionally.

ensure_user userA UserA "$TEST_USER_PASS"
ensure_user userB UserB "$TEST_USER_PASS"

TOKEN_A=$(get_token userA "$TEST_USER_PASS")
TOKEN_B=$(get_token userB "$TEST_USER_PASS")
ADMIN_TOKEN=$(get_token admin "$ADMIN_PASS")

if [[ -z "$TOKEN_A" || -z "$TOKEN_B" || -z "$ADMIN_TOKEN" ]]; then
  echo "ERROR: failed to obtain one or more required tokens" >&2
  exit 1
fi

# Reuse manager when present; otherwise create it through the admin-only endpoint.
MANAGER_TOKEN=$(get_token manager1 "$TEST_MANAGER_PASS")
if [[ -z "$MANAGER_TOKEN" ]]; then
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
  MANAGER_TOKEN=$(get_token manager1 "$TEST_MANAGER_PASS")
else
  echo "manager1 already exists; reusing account"
fi

# Pick an existing product instead of assuming id=1 is present.
PRODUCT_ID=$(curl -sS "${BASE_URL}/api/products" | jq -r '.[0].id // empty')
if [[ -z "$PRODUCT_ID" ]]; then
  echo "WARNING: no products available; order/BOLA tests will be skipped" >&2
fi

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

if [[ -n "$PRODUCT_ID" ]]; then
  ORDER_A=$(curl -sS -X POST \
    -H "Authorization: ${TOKEN_A}" \
    --get \
    --data-urlencode "productId=${PRODUCT_ID}" \
    --data-urlencode "phone=79990000001" \
    "${BASE_URL}/api/orders")
  ORDER_A_ID=$(echo "$ORDER_A" | jq -r '.id // empty')
  echo "userA order id: ${ORDER_A_ID:-<not-created>}"

  ORDER_B=$(curl -sS -X POST \
    -H "Authorization: ${TOKEN_B}" \
    --get \
    --data-urlencode "productId=${PRODUCT_ID}" \
    --data-urlencode "phone=79990000002" \
    "${BASE_URL}/api/orders")
  ORDER_B_ID=$(echo "$ORDER_B" | jq -r '.id // empty')
  echo "userB order id: ${ORDER_B_ID:-<not-created>}"

  if [[ -n "${ORDER_A_ID:-}" ]]; then
    req "AUTH-08 anonymous reads userA order" "${BASE_URL}/api/orders/${ORDER_A_ID}"
    req "AUTH-09 userB reads userA order" -H "Authorization: ${TOKEN_B}" "${BASE_URL}/api/orders/${ORDER_A_ID}"
    req "AUTH-10 userA reads own order" -H "Authorization: ${TOKEN_A}" "${BASE_URL}/api/orders/${ORDER_A_ID}"
  fi
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
# The anonymous case was already reproduced manually and returned HTTP 200 with subsequent 404 on GET.

echo
echo "Raw tokens were kept only in shell variables. Do not run with shell tracing enabled."
