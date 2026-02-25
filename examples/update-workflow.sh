#!/usr/bin/env bash
# Safe workflow update via GET → strip forbidden fields → PUT
#
# The n8n REST API v1 uses PUT (full replace) — no PATCH.
# GET responses include fields that cause 400 errors if sent back in PUT.
# This script strips those fields automatically.
#
# Usage:
#   export N8N_URL="http://localhost:5678"
#   export N8N_API_KEY="your-api-key"
#   ./update-workflow.sh <workflow_id> <new_name>

set -euo pipefail

: "${N8N_URL:?Set N8N_URL (e.g. http://localhost:5678)}"
: "${N8N_API_KEY:?Set N8N_API_KEY}"

WORKFLOW_ID="${1:?Usage: $0 <workflow_id> [new_name]}"
NEW_NAME="${2:-}"

echo "Fetching workflow $WORKFLOW_ID..."

# Step 1: GET current workflow
CURRENT=$(curl -s \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  "$N8N_URL/api/v1/workflows/$WORKFLOW_ID")

# Step 2: Strip forbidden fields that cause 400 errors
# Only these fields are accepted: name, nodes, connections, active
CLEAN=$(echo "$CURRENT" | jq '{
  name: .name,
  nodes: .nodes,
  connections: .connections,
  active: .active
}')

# Step 3: Optionally update the name
if [ -n "$NEW_NAME" ]; then
  CLEAN=$(echo "$CLEAN" | jq --arg n "$NEW_NAME" '.name = $n')
fi

echo "Updating workflow..."

# Step 4: PUT the cleaned body
RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$CLEAN" \
  "$N8N_URL/api/v1/workflows/$WORKFLOW_ID")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
  echo "Updated successfully."
  echo "$BODY" | jq '{id: .id, name: .name, active: .active, updatedAt: .updatedAt}'
else
  echo "Error ($HTTP_CODE):"
  echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
  exit 1
fi
