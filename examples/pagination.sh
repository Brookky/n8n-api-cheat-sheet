#!/usr/bin/env bash
# Paginate through all n8n workflows using cursor-based pagination
#
# The /api/v1/workflows endpoint returns max 100 results per request.
# Use the `nextCursor` value from each response to fetch the next page.
#
# Usage:
#   export N8N_URL="http://localhost:5678"
#   export N8N_API_KEY="your-api-key"
#   ./pagination.sh [--active-only] [--limit N]

set -euo pipefail

: "${N8N_URL:?Set N8N_URL (e.g. http://localhost:5678)}"
: "${N8N_API_KEY:?Set N8N_API_KEY}"

ACTIVE_FILTER=""
PAGE_LIMIT=100
TOTAL=0
PAGE=1

while [[ $# -gt 0 ]]; do
  case $1 in
    --active-only) ACTIVE_FILTER="&active=true"; shift ;;
    --limit) PAGE_LIMIT="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

CURSOR=""

echo "Fetching workflows (page size: $PAGE_LIMIT)..."
echo "---"

while true; do
  # Build URL with optional cursor
  URL="$N8N_URL/api/v1/workflows?limit=$PAGE_LIMIT$ACTIVE_FILTER"
  if [ -n "$CURSOR" ]; then
    URL="$URL&cursor=$CURSOR"
  fi

  RESPONSE=$(curl -s \
    -H "X-N8N-API-KEY: $N8N_API_KEY" \
    "$URL")

  # Count items in this page
  COUNT=$(echo "$RESPONSE" | jq '.data | length')
  TOTAL=$((TOTAL + COUNT))

  # Print workflow summaries
  echo "$RESPONSE" | jq -r '.data[] | "  [\(.id)] \(.name) (active: \(.active))"'

  echo "--- Page $PAGE: $COUNT workflows ---"

  # Check for next page
  NEXT_CURSOR=$(echo "$RESPONSE" | jq -r '.nextCursor // empty')

  if [ -z "$NEXT_CURSOR" ]; then
    break
  fi

  CURSOR="$NEXT_CURSOR"
  PAGE=$((PAGE + 1))
done

echo ""
echo "Total workflows: $TOTAL"
