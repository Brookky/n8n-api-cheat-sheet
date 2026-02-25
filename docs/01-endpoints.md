# n8n REST API Endpoints Reference

> Complete reference for n8n's public REST API v1 endpoints.

---

## Authentication

All requests require the `X-N8N-API-KEY` header:

```bash
curl -H "X-N8N-API-KEY: your-api-key" \
  "http://localhost:5678/api/v1/workflows"
```

---

## API Endpoints

| Action | Method | Endpoint | Description |
|--------|--------|----------|-------------|
| Create | POST | `/api/v1/workflows` | Create a new workflow |
| List | GET | `/api/v1/workflows` | List workflows (with query filters) |
| Get | GET | `/api/v1/workflows/{id}` | Get a single workflow |
| Update | PUT | `/api/v1/workflows/{id}` | Full replace update (no PATCH!) |
| Activate | POST | `/api/v1/workflows/{id}/activate` | Activate a workflow |
| Deactivate | POST | `/api/v1/workflows/{id}/deactivate` | Deactivate a workflow |

---

## List Workflows — Query Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `limit` | integer | Max results (default: 100) |
| `cursor` | string | Pagination cursor (from previous response's `nextCursor`) |
| `active` | boolean | Filter by active status (`true` / `false`) |
| `tags` | string | Filter by tags (comma-separated, e.g. `tag1,tag2`) |
| `name` | string | Filter by name |
| `projectId` | string | Filter by project ID |
| `excludePinnedData` | boolean | Exclude pinData from response |

**Example:**

```bash
curl -s -H "X-N8N-API-KEY: your-api-key" \
  "http://localhost:5678/api/v1/workflows?active=true&limit=50&tags=production"
```

### Response Structure

```json
{
  "data": [
    {
      "id": "workflow_id",
      "name": "My Workflow",
      "active": true,
      "nodes": [...],
      "connections": {...},
      "createdAt": "2024-01-01T00:00:00.000Z",
      "updatedAt": "2024-01-02T00:00:00.000Z"
    }
  ],
  "nextCursor": "eyJsaW1pdCI6MTB9"
}
```

---

## Searching Workflows

```bash
# Method 1: Server-side name filter (recommended)
curl -s -H "X-N8N-API-KEY: your-api-key" \
  "http://localhost:5678/api/v1/workflows?name=keyword&limit=100"

# Method 2: Filter by active status
curl -s -H "X-N8N-API-KEY: your-api-key" \
  "http://localhost:5678/api/v1/workflows?active=true&limit=100"

# Method 3: Local filtering with jq (for complex searches)
curl -s -H "X-N8N-API-KEY: your-api-key" \
  "http://localhost:5678/api/v1/workflows?limit=100" \
  | jq '.data[] | select(.name | contains("keyword"))'
```

> **Tip:** Use server-side filters (`name`, `active`, `tags`) when possible. Only use local `jq` filtering for complex conditions.

---

## API Limitations (v1)

| Feature | Public API v1 | Workaround |
|---------|--------------|------------|
| `pinData` (pin test data to nodes) | **Not supported** — 400 error if included in PUT body | Internal API (`/rest/`) with session cookie auth. See [Internal API](05-internal-api.md) |
| Manual Execution | **Not supported** — No `/execute` or `/run` endpoint (405) | Use Webhook trigger for API-triggered execution, or run manually via n8n UI |
| PATCH (partial update) | **Not supported** — 405 error | GET → modify → PUT (full replace). See [Gotchas](04-gotchas.md) |
| `settings` in PUT/POST | **Not supported** — 400 error | Configure via n8n UI |

---

## Workflow Create/Update Body

Only these fields are accepted in POST/PUT body:

```json
{
  "name": "Workflow Name",
  "nodes": [...],
  "connections": {...},
  "active": false
}
```

> ⚠️ **Including `settings`, `pinData`, or `staticData` will cause a 400 error.** See [Gotchas](04-gotchas.md) for details.

---

## Position Coordinate Guide

- x-axis: increases to the right
- y-axis: increases downward
- Recommended spacing: ~200px between nodes
- Start node: around `[250, 300]`
- Subsequent nodes: x += 200, branch vertically ± 150

```
[250, 300] → [450, 300] → [650, 300]
                              ↘ [650, 450]  (branch)
```
