# ⚠️ n8n API Gotchas — What the Docs Don't Tell You

> The most common traps when working with n8n's REST API v1, discovered through testing.

---

## The `additionalProperties: false` Trap

n8n's REST API v1 uses `additionalProperties: false` in its PUT/POST request schema. This means that **any field not explicitly whitelisted will cause a `400 Bad Request`** with the message:

```
"must NOT have additional properties"
```

The problem? The **GET response includes fields that are rejected by PUT/POST**. So if you naively GET a workflow and PUT it back, you'll get a 400 error.

---

## OpenAPI Spec vs Reality

The official OpenAPI spec (`openapi.yml`) lists `settings`, `pinData`, and `staticData` as **allowed fields** in the PUT/POST schema. But the **actual server rejects them with 400 errors**.

This is a spec-vs-implementation mismatch in n8n v1. The behavior may vary by n8n version, but as of 1.x self-hosted, these fields are consistently rejected.

---

## Forbidden Fields in PUT/POST Body

**Never include these in your PUT/POST body:**

| Field | Why It Fails | Where to Set It |
|-------|-------------|-----------------|
| `settings` | Schema mismatch across n8n versions | Configure in n8n UI (Settings tab) |
| `pinData` | GET response includes it, but PUT schema rejects it | n8n UI → Edit Output, or Internal API `/rest/` PATCH |
| `staticData` | Same as above | Managed internally by n8n |

---

## Confirmed Allowed Fields

**Only use these fields in PUT/POST body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Workflow name |
| `nodes` | array | Yes | Array of node objects |
| `connections` | object | Yes | Connection mapping between nodes |
| `active` | boolean | No | Whether the workflow is active |

> **Untested:** `tags` — The OpenAPI spec lists it as allowed, but actual behavior is untested. If you get a 400 error, remove it.

---

## Safe Workflow Update Pattern

Since PATCH is not supported (405 error), you must use the GET → strip → PUT pattern:

```bash
#!/bin/bash
N8N_URL="${N8N_URL:-http://localhost:5678}"
API_KEY="${N8N_API_KEY:?Set N8N_API_KEY}"
WORKFLOW_ID="${1:?Usage: $0 <workflow_id>}"

# Step 1: GET current workflow
WORKFLOW=$(curl -s -H "X-N8N-API-KEY: $API_KEY" \
  "$N8N_URL/api/v1/workflows/$WORKFLOW_ID")

# Step 2: Strip forbidden fields, keep only allowed ones
SAFE_BODY=$(echo "$WORKFLOW" | jq '{
  name: .name,
  nodes: .nodes,
  connections: .connections,
  active: .active
}')

# Step 3: Modify as needed (example: change name)
MODIFIED=$(echo "$SAFE_BODY" | jq '.name = "Updated Workflow"')

# Step 4: PUT back
curl -s -X PUT \
  -H "X-N8N-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d "$MODIFIED" \
  "$N8N_URL/api/v1/workflows/$WORKFLOW_ID"
```

> ⚠️ **The `jq` filter is critical.** Without it, the PUT will include `settings`, `pinData`, `staticData`, `createdAt`, `updatedAt`, `id`, `versionId`, and other read-only fields — all causing 400 errors.

---

## Workflow Creation Body (POST)

```json
{
  "name": "My New Workflow",
  "nodes": [
    {
      "id": "unique-uuid",
      "name": "Webhook",
      "type": "n8n-nodes-base.webhook",
      "typeVersion": 2,
      "position": [250, 300],
      "webhookId": "my-webhook-id",
      "parameters": {
        "httpMethod": "POST",
        "path": "my-endpoint"
      }
    }
  ],
  "connections": {},
  "active": false
}
```

> Always create with `active: false`, verify it works, then activate separately via `POST /api/v1/workflows/{id}/activate`.

---

## PUT is Full Replace — Not Partial Update

`PUT /api/v1/workflows/{id}` performs a **full replace**. Any nodes or connections missing from your PUT body will be **deleted**.

```
❌ Wrong: Send only the node you want to change
✅ Right: GET the full workflow → modify the specific node → PUT the entire thing back
```

This is why the GET → modify → PUT pattern is mandatory. There is no partial update in the public API.

---

## No PATCH Support

```bash
# This will fail with 405 Method Not Allowed
curl -X PATCH \
  -H "X-N8N-API-KEY: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{"name": "New Name"}' \
  "http://localhost:5678/api/v1/workflows/123"
# → 405 error
```

PATCH is only available via the **internal API (`/rest/`)** with session cookie auth. See [Internal API](05-internal-api.md).

---

## Webhook Output Data Structure

When using Webhook nodes, the output `$json` is **not** the POST body directly. It's the full request metadata:

```json
{
  "headers": { "content-type": "application/json", ... },
  "params": {},
  "query": {},
  "body": { "channel": "email", "message": "hello" },
  "webhookUrl": "https://...",
  "executionMode": "production"
}
```

To access POST body fields:
- ✅ Correct: `$json.body.channel`, `$json.body.message`
- ❌ Wrong: `$json.channel`, `$json.message` (undefined)

---

## Switch/IF Conditions — Missing `options` Causes Errors

Switch and IF nodes require an `options` object inside each `conditions` block. Omitting it causes:

```
Cannot read property 'caseSensitive' of undefined
```

Always include:

```json
{
  "conditions": {
    "options": {
      "caseSensitive": true,
      "leftValue": "",
      "typeValidation": "strict"
    },
    "conditions": [...],
    "combinator": "and"
  }
}
```
