# n8n REST API Cheat Sheet

> A practical, battle-tested reference for n8n's REST API that the official docs don't tell you.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Why This Exists

n8n's official API docs cover the basics, but when you actually try to **programmatically manage workflows**, you hit walls:

- `PUT` body with `settings` or `pinData` returns **400 error** — even though the official OpenAPI spec lists them as allowed fields
- `PATCH` is **not supported** in the public API (405 error)
- `pinData` can only be set via the **internal API (`/rest/`)** with session cookie auth — undocumented
- Manual execution (Manual Trigger) has **no API endpoint**
- The OpenAPI spec and actual server behavior **don't match**

This cheat sheet fills those gaps.

## Quick Start

### Create a workflow

```bash
curl -X POST \
  -H "X-N8N-API-KEY: your-api-key" \
  -H "Content-Type: application/json" \
  -d @examples/sample-workflow.json \
  "http://localhost:5678/api/v1/workflows"
```

### Update a workflow (GET → modify → PUT)

```bash
# ⚠️ n8n API has no PATCH. You must PUT the entire workflow.
# ⚠️ GET response contains fields that will cause 400 if sent back via PUT.

WORKFLOW=$(curl -s -H "X-N8N-API-KEY: $API_KEY" \
  "$N8N_URL/api/v1/workflows/$ID")

# Strip forbidden fields, then PUT back
echo $WORKFLOW | jq '{
  name: .name,
  nodes: .nodes,
  connections: .connections,
  active: .active
}' | curl -X PUT \
  -H "X-N8N-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d @- \
  "$N8N_URL/api/v1/workflows/$ID"
```

## Documentation

| Doc | Description |
|-----|-------------|
| [Endpoints](docs/01-endpoints.md) | All REST API endpoints with query parameters |
| [Node Schema](docs/02-node-schema.md) | Complete node object fields and key node types |
| [Connections](docs/03-connections.md) | Connection patterns: 1:1, fan-out, IF/Switch, Merge, loops |
| [Gotchas](docs/04-gotchas.md) | ⚠️ 400 errors, forbidden fields, OpenAPI spec vs reality |
| [Internal API](docs/05-internal-api.md) | Session auth for `/rest/` endpoints (pinData, PATCH) |

## ⚠️ Known API Limitations (v1)

| Feature | Public API v1 | Workaround |
|---------|--------------|------------|
| `pinData` in PUT/POST | ❌ 400 error | Internal API with session cookie |
| `settings` in PUT/POST | ❌ 400 error | Configure via n8n UI |
| `PATCH` (partial update) | ❌ 405 error | GET → modify → PUT (full replace) |
| Manual execution | ❌ No endpoint | Use Webhook trigger or n8n UI |

## Tested On

- n8n `1.x` (self-hosted, Docker)
- API version: `v1`

> Contributions welcome! If you've found more undocumented behaviors, please open an issue or PR.

## License

MIT — use it, fork it, improve it.
