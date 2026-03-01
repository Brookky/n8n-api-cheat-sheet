# n8n Master Skill — v1 Architecture

This directory contains the **v1 skill files** for programmatic n8n workflow management via Claude Code (or any AI agent system that supports OpenCode skills).

## v1 Architecture: Orchestration + HTTP Definition Separation

v1 splits a single monolithic `SKILL.md` into distinct layers:

```
skill/
  SKILL.md          # Orchestration layer — intent mapping, credential flow, error policy, output format
  endpoints.json    # HTTP definitions — method, path, auth, params, body allowed/forbidden fields
  .env              # Credentials — API key, base URL (git-ignored, never committed)
  refs/             # Domain knowledge — workflow schema, node types, templates
```

### Why This Matters

**v0 (single-file)** embeds curl commands directly in the SKILL.md prose:
- Changing an endpoint requires scanning 400+ lines
- curl commands scattered across sections are not machine-readable
- Auth credentials appear as placeholders mixed into text

**v1 (split)** separates concerns:
- `endpoints.json` is the single source of truth for all HTTP calls
- `SKILL.md` contains only reasoning and orchestration logic — zero curl commands
- Adding a new endpoint = one JSON object. SKILL.md untouched.
- `body_forbidden` fields explicitly block known bad inputs (e.g., `settings`, `pinData` → 400 error)

## endpoints.json Schema

```json
{
  "service": "n8n",
  "version": "v1",
  "base_url_env": "N8N_URL",
  "auth": {
    "type": "header",
    "key": "X-N8N-API-KEY",
    "value_env": "N8N_API_KEY"
  },
  "endpoints": [
    {
      "id": "create_workflow",
      "method": "POST",
      "path": "/api/v1/workflows",
      "body_allowed": ["name", "nodes", "connections", "active"],
      "body_forbidden": ["settings", "pinData", "staticData", "id", "createdAt", "updatedAt"]
    }
  ],
  "gotchas": [...]
}
```

### Key Fields

| Field | Description |
|---|---|
| `id` | Unique endpoint identifier — used by SKILL.md to look up the endpoint |
| `body_allowed` | Fields the AI is permitted to include in POST/PUT body |
| `body_forbidden` | Fields that cause 400 errors despite appearing in GET responses |
| `path_params` | URL path variables (e.g., `{id}`) that must be substituted |
| `notes` | Known API quirks or behavior notes |

## Usage

1. Copy `SKILL.md` and `endpoints.json` to `~/.claude/skills/n8n_master/`
2. Create `.env` with your credentials:
   ```ini
   N8N_URL=https://your-n8n-instance.example.com
   N8N_API_KEY=your-api-key-here
   ```
3. The skill loads `endpoints.json` at runtime to build HTTP requests dynamically

## Known n8n API Gotchas (captured in endpoints.json)

- `PUT`/`POST` body with `settings`, `pinData`, or `staticData` returns **400** — even though the OpenAPI spec lists them as allowed
- `PATCH` is **not supported** (405) — use `PUT` only
- Manual execution (`POST /api/v1/workflows/{id}/run`) returns **405** — use Webhook trigger instead
