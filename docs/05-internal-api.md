# n8n Internal API — Session Auth and Hidden Endpoints

> How to access n8n's internal `/rest/` API for features not available in the public API v1.

---

## Public API vs Internal API

| | Public API (`/api/v1/`) | Internal API (`/rest/`) |
|---|---|---|
| **Auth** | `X-N8N-API-KEY` header | Session cookie (login required) |
| **PUT** | ✅ Supported | ✅ Supported |
| **PATCH** | ❌ 405 error | ✅ Supported |
| **pinData** | ❌ 400 error in body | ✅ Can set via PATCH |
| **settings** | ❌ 400 error in body | ✅ Can set via PATCH |
| **Documentation** | Official docs available | Undocumented |
| **Stability** | Stable, versioned | May change between n8n versions |

---

## Session Cookie Authentication

The internal API uses session-based auth. You need to:

1. POST to `/rest/login` with credentials
2. Capture the session cookie
3. Use the cookie for subsequent requests

### Step 1: Login

```bash
N8N_URL="${N8N_URL:-http://localhost:5678}"

curl -s -c /tmp/n8n_cookie.txt -X POST \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@example.com", "password": "your-password"}' \
  "$N8N_URL/rest/login"
```

This saves the session cookie to `/tmp/n8n_cookie.txt`.

### Step 2: Use the Cookie

```bash
# Example: Get workflow list via internal API
curl -s -b /tmp/n8n_cookie.txt \
  "$N8N_URL/rest/workflows"
```

### Step 3: Cleanup

```bash
rm -f /tmp/n8n_cookie.txt
```

---

## Setting pinData via Internal API

`pinData` lets you pin test data to nodes — essential for testing Manual Trigger workflows. This is **only possible via the internal API**.

```bash
N8N_URL="${N8N_URL:-http://localhost:5678}"
WORKFLOW_ID="your-workflow-id"

# Login first
curl -s -c /tmp/n8n_cookie.txt -X POST \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@example.com", "password": "your-password"}' \
  "$N8N_URL/rest/login"

# Set pinData on a node
curl -s -b /tmp/n8n_cookie.txt -X PATCH \
  -H "Content-Type: application/json" \
  -d '{
    "pinData": {
      "Webhook Trigger": [
        {"body": {"text": "test message", "channel": "email"}}
      ]
    }
  }' \
  "$N8N_URL/rest/workflows/$WORKFLOW_ID"

rm -f /tmp/n8n_cookie.txt
```

> **Note:** The key in `pinData` must match the **node name** exactly.

---

## Using PATCH for Partial Updates

Unlike the public API (which requires full PUT), the internal API supports PATCH:

```bash
# Change just the workflow name — no need to send nodes/connections
curl -s -b /tmp/n8n_cookie.txt -X PATCH \
  -H "Content-Type: application/json" \
  -d '{"name": "Updated Name"}' \
  "$N8N_URL/rest/workflows/$WORKFLOW_ID"
```

This is significantly simpler than the public API's GET → modify → PUT pattern.

---

## Full Session Auth Script

```bash
#!/bin/bash
# n8n Internal API — Session Cookie Authentication
# Use this for endpoints not available in Public API v1

N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_EMAIL="${N8N_EMAIL:-admin@example.com}"
N8N_PASSWORD="${N8N_PASSWORD:?Set N8N_PASSWORD}"
COOKIE_FILE="/tmp/n8n_session_$$.txt"

# Step 1: Login and get session cookie
echo "Logging in to n8n..."
LOGIN_RESPONSE=$(curl -s -c "$COOKIE_FILE" -X POST \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$N8N_EMAIL\", \"password\": \"$N8N_PASSWORD\"}" \
  "$N8N_URL/rest/login")

if echo "$LOGIN_RESPONSE" | grep -q "error"; then
  echo "Login failed: $LOGIN_RESPONSE"
  rm -f "$COOKIE_FILE"
  exit 1
fi
echo "Login successful."

# Step 2: Use session (example: set pinData)
WORKFLOW_ID="${1:?Usage: $0 <workflow_id>}"

curl -s -b "$COOKIE_FILE" -X PATCH \
  -H "Content-Type: application/json" \
  -d '{
    "pinData": {
      "Webhook Trigger": [
        {"body": {"text": "test message"}}
      ]
    }
  }' \
  "$N8N_URL/rest/workflows/$WORKFLOW_ID"

echo ""
echo "pinData set successfully."

# Cleanup
rm -f "$COOKIE_FILE"
```

---

## Security Considerations

- **Session cookies are sensitive.** Always delete cookie files after use.
- **Credentials in scripts.** Use environment variables, never hardcode passwords.
- **Internal API stability.** These endpoints are undocumented and may change between n8n versions. Test after upgrades.
- **Network exposure.** The internal API should only be accessed from trusted networks. Do not expose `/rest/login` to the public internet without additional security layers.
- **Cookie file permissions.** Use `$$` (PID) in cookie filenames to avoid conflicts in concurrent scripts.
