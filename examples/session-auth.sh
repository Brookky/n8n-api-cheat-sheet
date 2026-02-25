#!/usr/bin/env bash
# n8n Internal API session authentication + pinData example
#
# The public API v1 (/api/v1/) does NOT support:
#   - pinData (400 error)
#   - PATCH (405 error)
#   - Manual execution
#
# The internal API (/rest/) supports all of these but requires
# session cookie authentication instead of API key.
#
# Usage:
#   export N8N_URL="http://localhost:5678"
#   export N8N_EMAIL="admin@example.com"
#   export N8N_PASSWORD="your-password"
#   ./session-auth.sh <workflow_id>

set -euo pipefail

: "${N8N_URL:?Set N8N_URL (e.g. http://localhost:5678)}"
: "${N8N_EMAIL:?Set N8N_EMAIL}"
: "${N8N_PASSWORD:?Set N8N_PASSWORD}"

WORKFLOW_ID="${1:?Usage: $0 <workflow_id>}"
COOKIE_FILE=$(mktemp)

cleanup() { rm -f "$COOKIE_FILE"; }
trap cleanup EXIT

# Step 1: Login to get session cookie
echo "Logging in as $N8N_EMAIL..."

LOGIN_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -c "$COOKIE_FILE" \
  -X POST \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$N8N_EMAIL\", \"password\": \"$N8N_PASSWORD\"}" \
  "$N8N_URL/rest/login")

LOGIN_CODE=$(echo "$LOGIN_RESPONSE" | tail -1)

if [ "$LOGIN_CODE" -ge 300 ]; then
  echo "Login failed ($LOGIN_CODE)"
  exit 1
fi

echo "Login successful."

# Step 2: Set pinData via PATCH (internal API)
# pinData pins test data to a specific node for manual execution
echo ""
echo "Setting pinData on workflow $WORKFLOW_ID..."

PIN_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -b "$COOKIE_FILE" \
  -X PATCH \
  -H "Content-Type: application/json" \
  -d '{
    "pinData": {
      "Webhook": [
        {
          "headers": {},
          "params": {},
          "query": {},
          "body": {
            "channel": "email",
            "message": "test message",
            "priority": "high"
          }
        }
      ]
    }
  }' \
  "$N8N_URL/rest/workflows/$WORKFLOW_ID")

PIN_CODE=$(echo "$PIN_RESPONSE" | tail -1)
PIN_BODY=$(echo "$PIN_RESPONSE" | sed '$d')

if [ "$PIN_CODE" -ge 200 ] && [ "$PIN_CODE" -lt 300 ]; then
  echo "pinData set successfully."
  echo "$PIN_BODY" | jq '{id: .id, name: .name}' 2>/dev/null || echo "Done"
else
  echo "Error ($PIN_CODE):"
  echo "$PIN_BODY" | jq . 2>/dev/null || echo "$PIN_BODY"
  exit 1
fi

# Step 3: Verify pinData was set
echo ""
echo "Verifying pinData..."

VERIFY=$(curl -s \
  -b "$COOKIE_FILE" \
  "$N8N_URL/rest/workflows/$WORKFLOW_ID")

HAS_PIN=$(echo "$VERIFY" | jq 'has("pinData")')
echo "pinData present: $HAS_PIN"

if [ "$HAS_PIN" = "true" ]; then
  echo "Pinned nodes:"
  echo "$VERIFY" | jq -r '.pinData | keys[]'
fi
