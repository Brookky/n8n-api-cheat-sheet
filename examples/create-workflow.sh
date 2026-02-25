#!/usr/bin/env bash
# Create a workflow via n8n REST API v1
#
# Usage:
#   export N8N_URL="http://localhost:5678"
#   export N8N_API_KEY="your-api-key"
#   ./create-workflow.sh

set -euo pipefail

: "${N8N_URL:?Set N8N_URL (e.g. http://localhost:5678)}"
: "${N8N_API_KEY:?Set N8N_API_KEY}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -H "Content-Type: application/json" \
  -d @"$(dirname "$0")/sample-workflow.json" \
  "$N8N_URL/api/v1/workflows")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
  WORKFLOW_ID=$(echo "$BODY" | jq -r '.id')
  echo "Created workflow: $WORKFLOW_ID"
  echo ""
  echo "Activate with:"
  echo "  curl -s -X POST -H \"X-N8N-API-KEY: \$N8N_API_KEY\" \\"
  echo "    \"\$N8N_URL/api/v1/workflows/$WORKFLOW_ID/activate\""
else
  echo "Error ($HTTP_CODE):"
  echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
  exit 1
fi
