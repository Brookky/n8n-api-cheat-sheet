# n8n Node Schema Reference

> JSON schema for every commonly used node type — ready to copy-paste into workflow bodies.

---

## Node Object Schema

Every node in the `nodes` array follows this structure:

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "HTTP Request",
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4.2,
  "position": [450, 300],
  "parameters": { },
  "credentials": { },
  "disabled": false,
  "notes": "",
  "notesInFlow": false,
  "executeOnce": false,
  "alwaysOutputData": false,
  "retryOnFail": false,
  "maxTries": 3,
  "waitBetweenTries": 1000,
  "continueOnFail": false,
  "onError": "stopWorkflow"
}
```

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | UUID format. Must be unique within the workflow |
| `name` | string | Display name. **Connections reference this value** — not the ID |
| `type` | string | Node type identifier (e.g. `n8n-nodes-base.httpRequest`) |
| `typeVersion` | number | Node version (use latest stable) |
| `position` | [number, number] | [x, y] canvas coordinates. ~200px spacing recommended |
| `parameters` | object | Node-specific configuration |

### Optional Fields

| Field | Default | Description |
|-------|---------|-------------|
| `credentials` | `{}` | External service auth reference |
| `disabled` | `false` | Whether node is disabled |
| `executeOnce` | `false` | Execute only for first item |
| `alwaysOutputData` | `false` | Output empty data even with no input |
| `retryOnFail` | `false` | Retry on failure |
| `maxTries` | `3` | Maximum retry attempts |
| `waitBetweenTries` | `1000` | Delay between retries (ms) |
| `continueOnFail` | `false` | Continue workflow on failure |
| `onError` | `"stopWorkflow"` | `"stopWorkflow"` or `"continueRegularOutput"` |

---

## typeVersion Compatibility

These versions are chosen for broad compatibility. Your n8n instance may have newer defaults:

| Node | This Doc | Latest Default | Versions Available |
|------|----------|----------------|--------------------|
| webhook | 2 | 2.1 | 1, 1.1, 2, 2.1 |
| scheduleTrigger | 1.2 | 1.3 | 1, 1.1, 1.2, 1.3 |
| httpRequest | 4.2 | 4.4 | 1, 2, 3, 4, 4.1, 4.2, 4.3, 4.4 |
| code | 2 | 2 | ✅ matches |
| if | 2.2 | 2.3 | 1, 2, 2.1, 2.2, 2.3 |
| switch | 3.2 | 3.4 | 1, 2, 3, 3.1, 3.2, 3.3, 3.4 |
| merge | 3 | 3.2 | 1, 2, 2.1, 3, 3.1, 3.2 |
| splitInBatches | 3 | 3 | ✅ matches |

All versions listed here work correctly. If you encounter parameter mismatches, check the [n8n node source](https://github.com/n8n-io/n8n/tree/master/packages/nodes-base/nodes).

---

## Trigger Nodes

### Webhook (`n8n-nodes-base.webhook`)

```json
{
  "id": "webhook-uuid",
  "name": "Webhook",
  "type": "n8n-nodes-base.webhook",
  "typeVersion": 2,
  "position": [250, 300],
  "webhookId": "unique-webhook-uuid",
  "parameters": {
    "httpMethod": "POST",
    "path": "my-webhook-path",
    "responseMode": "onReceived",
    "responseData": "firstEntryJson",
    "responseCode": 200,
    "options": {
      "rawBody": false,
      "responseHeaders": {}
    }
  }
}
```

| Parameter | Values | Description |
|-----------|--------|-------------|
| `httpMethod` | `"GET"`, `"POST"`, `"PUT"`, `"DELETE"`, `"PATCH"`, `"HEAD"` | HTTP method |
| `path` | string | Webhook path (`/webhook/{path}`) |
| `responseMode` | `"onReceived"`, `"lastNode"`, `"responseNode"` | When to send response |
| `responseData` | `"firstEntryJson"`, `"allEntries"`, `"noData"` | Response data shape |
| `responseCode` | number | HTTP response code |
| `webhookId` | string | Unique webhook ID (can match `path`) |

**responseMode explained:**
- `"onReceived"` — Respond immediately on webhook receipt (async processing)
- `"lastNode"` — Respond after the last node completes (sync processing)
- `"responseNode"` — Use a Respond to Webhook node for custom response

**⚠️ Webhook Output Structure (Important):**

The Webhook node's output (`$json`) is the **entire request metadata**, not just the POST body:

```json
{
  "headers": { "content-type": "application/json" },
  "params": {},
  "query": {},
  "body": { "channel": "email", "message": "hello" },
  "webhookUrl": "https://...",
  "executionMode": "production"
}
```

When accessing POST body data in downstream nodes:
- **Correct**: `$json.body.channel`, `$json.body.message`
- **Wrong**: `$json.channel`, `$json.message` (undefined)

Code node pattern to extract body:
```javascript
const d = item.json.body || item.json; // body first, fallback to full object
```

---

### Schedule Trigger (`n8n-nodes-base.scheduleTrigger`)

```json
{
  "id": "schedule-uuid",
  "name": "Schedule Trigger",
  "type": "n8n-nodes-base.scheduleTrigger",
  "typeVersion": 1.2,
  "position": [250, 300],
  "parameters": {
    "rule": {
      "interval": [
        {
          "field": "cronExpression",
          "expression": "0 9 * * *"
        }
      ]
    }
  }
}
```

**Interval options:**

| field | Interval Parameter | Example |
|-------|-------------------|---------|
| `"seconds"` | `secondsInterval` | Every 30 seconds |
| `"minutes"` | `minutesInterval` | Every 5 minutes |
| `"hours"` | `hoursInterval` | Every hour |
| `"days"` | `daysInterval`, `triggerAtHour` | Daily at 9 AM |
| `"weeks"` | `triggerAtDay`, `triggerAtHour` | Weekly Monday 9 AM |
| `"cronExpression"` | `expression` | Freeform cron |

**Cron expression example (recommended for precise timing):**
```json
{
  "rule": {
    "interval": [{
      "field": "cronExpression",
      "expression": "0 9 * * *"
    }]
  }
}
```

**Interval-based example:**
```json
{
  "rule": {
    "interval": [{
      "field": "hours",
      "hoursInterval": 1
    }]
  }
}
```

---

### Manual Trigger (`n8n-nodes-base.manualTrigger`)

```json
{
  "id": "manual-uuid",
  "name": "When clicking 'Execute workflow'",
  "type": "n8n-nodes-base.manualTrigger",
  "typeVersion": 1,
  "position": [250, 300],
  "parameters": {}
}
```

**Setting test data:**

Manual Trigger cannot accept data via `parameters`. Two approaches:

| Method | Description | API Support |
|--------|-------------|-------------|
| EDIT OUTPUT (pinData) | Pin test JSON in n8n editor UI | **Not via public API v1**. Internal API `/rest/` PATCH with session auth. See [Internal API](05-internal-api.md) |
| Code node fallback | Subsequent Code node uses dummy data when no body exists | **Works** |

Code node fallback pattern:
```javascript
const TEST_DATA = { channel: 'email', message: 'test', priority: 'high' };
const d = item.json.body || TEST_DATA; // Webhook → body, Manual → TEST_DATA
```

---

### Error Trigger (`n8n-nodes-base.errorTrigger`)

```json
{
  "id": "error-trigger-uuid",
  "name": "Error Trigger",
  "type": "n8n-nodes-base.errorTrigger",
  "typeVersion": 1,
  "position": [250, 300],
  "parameters": {}
}
```

Used in error handler workflows. Register this workflow's ID in n8n UI > Settings > Error Workflow.

---

## Core Processing Nodes

### HTTP Request (`n8n-nodes-base.httpRequest`)

```json
{
  "id": "http-uuid",
  "name": "HTTP Request",
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4.2,
  "position": [450, 300],
  "parameters": {
    "method": "POST",
    "url": "https://api.example.com/endpoint",
    "authentication": "genericCredentialType",
    "genericAuthType": "httpHeaderAuth",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "Content-Type",
          "value": "application/json"
        }
      ]
    },
    "sendBody": true,
    "bodyParameters": {
      "parameters": [
        {
          "name": "key",
          "value": "={{ $json.data }}"
        }
      ]
    },
    "options": {
      "timeout": 60000,
      "response": {
        "response": {
          "responseFormat": "json"
        }
      },
      "redirect": {
        "redirect": {
          "followRedirects": true,
          "maxRedirects": 10
        }
      }
    }
  },
  "credentials": {
    "httpHeaderAuth": {
      "id": "cred-id",
      "name": "API Auth"
    }
  },
  "retryOnFail": true,
  "maxTries": 3,
  "waitBetweenTries": 5000
}
```

| Parameter | Description |
|-----------|-------------|
| `method` | `"GET"`, `"POST"`, `"PUT"`, `"PATCH"`, `"DELETE"`, `"HEAD"` |
| `url` | Request URL. Supports expressions: `={{ $json.url }}` |
| `authentication` | `"none"`, `"genericCredentialType"`, `"predefinedCredentialType"` |
| `sendHeaders` | Whether to send custom headers |
| `sendBody` | Whether to send request body |
| `specifyBody` | `"json"`, `"string"` (when sendBody is true) |
| `jsonBody` | Raw JSON body (when specifyBody is json) |
| `options.timeout` | Timeout in ms. **Use 60000+ for external APIs** |

**Body Sending — Key-Value:**
```json
{
  "sendBody": true,
  "bodyParameters": {
    "parameters": [
      { "name": "field", "value": "data" }
    ]
  }
}
```

**Body Sending — Raw JSON:**
```json
{
  "sendBody": true,
  "specifyBody": "json",
  "jsonBody": "={{ JSON.stringify({ key: $json.value }) }}"
}
```

---

### Code (`n8n-nodes-base.code`)

```json
{
  "id": "code-uuid",
  "name": "Code",
  "type": "n8n-nodes-base.code",
  "typeVersion": 2,
  "position": [450, 300],
  "parameters": {
    "jsCode": "const items = $input.all();\n\nreturn items.map(item => ({\n  json: {\n    processed: true,\n    original: item.json,\n    timestamp: new Date().toISOString()\n  }\n}));",
    "mode": "runOnceForAllItems"
  }
}
```

| Parameter | Values | Description |
|-----------|--------|-------------|
| `mode` | `"runOnceForAllItems"` | Process all items at once |
| `mode` | `"runOnceForEachItem"` | Execute per item |
| `jsCode` | string | JavaScript code |

**runOnceForAllItems structure:**
```javascript
const items = $input.all();
return items.map(item => ({
  json: { /* output data */ }
}));
```

**runOnceForEachItem structure:**
```javascript
const item = $input.item;
return { json: { /* output data */ } };
```

---

### Set / Edit Fields (`n8n-nodes-base.set`)

```json
{
  "id": "set-uuid",
  "name": "Edit Fields",
  "type": "n8n-nodes-base.set",
  "typeVersion": 3.4,
  "position": [450, 300],
  "parameters": {
    "mode": "manual",
    "duplicateItem": false,
    "assignments": {
      "assignments": [
        {
          "id": "assign-1",
          "name": "status",
          "value": "processed",
          "type": "string"
        },
        {
          "id": "assign-2",
          "name": "count",
          "value": "={{ $json.items.length }}",
          "type": "number"
        },
        {
          "id": "assign-3",
          "name": "isActive",
          "value": true,
          "type": "boolean"
        }
      ]
    },
    "includeOtherFields": true,
    "options": {}
  }
}
```

| Parameter | Description |
|-----------|-------------|
| `mode` | `"manual"` (field-by-field) or `"raw"` (direct JSON input) |
| `includeOtherFields` | `true`: keep existing fields, `false`: only assigned fields |
| `assignments.assignments[].type` | `"string"`, `"number"`, `"boolean"`, `"array"`, `"object"` |

---

### IF (`n8n-nodes-base.if`)

```json
{
  "id": "if-uuid",
  "name": "IF",
  "type": "n8n-nodes-base.if",
  "typeVersion": 2.2,
  "position": [450, 300],
  "parameters": {
    "conditions": {
      "options": {
        "caseSensitive": true,
        "leftValue": "",
        "typeValidation": "strict"
      },
      "conditions": [
        {
          "id": "condition-1",
          "leftValue": "={{ $json.status }}",
          "rightValue": "active",
          "operator": {
            "type": "string",
            "operation": "equals"
          }
        }
      ],
      "combinator": "and"
    },
    "options": {}
  }
}
```

| operator.type | Available operations |
|---------------|---------------------|
| `"string"` | `"equals"`, `"notEquals"`, `"contains"`, `"notContains"`, `"startsWith"`, `"endsWith"`, `"regex"`, `"exists"`, `"notExists"` |
| `"number"` | `"equals"`, `"notEquals"`, `"gt"`, `"gte"`, `"lt"`, `"lte"` |
| `"boolean"` | `"true"`, `"false"`, `"equals"`, `"notEquals"` |
| `"dateTime"` | `"after"`, `"before"`, `"equals"` |

**Output:** `main[0]` = true branch, `main[1]` = false branch

---

### Switch (`n8n-nodes-base.switch`)

```json
{
  "id": "switch-uuid",
  "name": "Switch",
  "type": "n8n-nodes-base.switch",
  "typeVersion": 3.2,
  "position": [450, 300],
  "parameters": {
    "rules": {
      "values": [
        {
          "outputKey": "email",
          "conditions": {
            "options": { "caseSensitive": true, "leftValue": "", "typeValidation": "strict" },
            "conditions": [
              {
                "leftValue": "={{ $json.channel }}",
                "rightValue": "email",
                "operator": { "type": "string", "operation": "equals" }
              }
            ],
            "combinator": "and"
          }
        },
        {
          "outputKey": "slack",
          "conditions": {
            "options": { "caseSensitive": true, "leftValue": "", "typeValidation": "strict" },
            "conditions": [
              {
                "leftValue": "={{ $json.channel }}",
                "rightValue": "slack",
                "operator": { "type": "string", "operation": "equals" }
              }
            ],
            "combinator": "and"
          }
        }
      ]
    },
    "options": {
      "fallbackOutput": "extra"
    }
  }
}
```

**Output:** `main[0]` = first rule, `main[1]` = second rule, ... `main[N]` = fallback

---

### Merge (`n8n-nodes-base.merge`)

```json
{
  "id": "merge-uuid",
  "name": "Merge",
  "type": "n8n-nodes-base.merge",
  "typeVersion": 3,
  "position": [650, 300],
  "parameters": {
    "mode": "append",
    "options": {}
  }
}
```

| mode | Description |
|------|-------------|
| `"append"` | Concatenate both inputs in order |
| `"combine"` | Join data by matching field |
| `"chooseBranch"` | Select only one branch |

**combine mode (match by field):**
```json
{
  "mode": "combine",
  "mergeByFields": {
    "values": [
      { "field1": "id", "field2": "userId" }
    ]
  },
  "joinMode": "keepMatches",
  "options": {
    "multipleMatches": "first"
  }
}
```

---

### Split In Batches (`n8n-nodes-base.splitInBatches`)

```json
{
  "id": "batch-uuid",
  "name": "Split In Batches",
  "type": "n8n-nodes-base.splitInBatches",
  "typeVersion": 3,
  "position": [450, 300],
  "parameters": {
    "batchSize": 100,
    "options": {}
  }
}
```

---

## Output / Response Nodes

### Respond to Webhook (`n8n-nodes-base.respondToWebhook`)

```json
{
  "id": "respond-uuid",
  "name": "Respond to Webhook",
  "type": "n8n-nodes-base.respondToWebhook",
  "typeVersion": 1.1,
  "position": [850, 300],
  "parameters": {
    "respondWith": "json",
    "responseBody": "={{ { success: true, data: $json } }}",
    "options": {
      "responseCode": 200,
      "responseHeaders": {
        "entries": [
          {
            "name": "Content-Type",
            "value": "application/json"
          }
        ]
      }
    }
  }
}
```

⚠️ The Webhook node's `responseMode` must be `"responseNode"` for this to work.

| respondWith | Description |
|-------------|-------------|
| `"json"` | JSON response |
| `"text"` | Text response |
| `"binary"` | Binary response |
| `"noData"` | Empty response |
| `"allEntries"` | Array of all items |
| `"firstEntryJson"` | First item's JSON |

---

### No Operation (`n8n-nodes-base.noOp`)

```json
{
  "id": "noop-uuid",
  "name": "No Operation",
  "type": "n8n-nodes-base.noOp",
  "typeVersion": 1,
  "position": [650, 450],
  "parameters": {}
}
```

Passes data through without modification. Useful for empty branches in conditional flows.

---

### Stop and Error (`n8n-nodes-base.stopAndError`)

```json
{
  "id": "stop-uuid",
  "name": "Stop and Error",
  "type": "n8n-nodes-base.stopAndError",
  "typeVersion": 1,
  "position": [850, 450],
  "parameters": {
    "errorMessage": "={{ 'Validation failed: ' + $json.error }}"
  }
}
```

---

## Expression Syntax Reference

Use `={{ }}` inside any node parameter value for JavaScript expressions:

```
={{ $json.fieldName }}                  // Current item field
={{ $json.nested?.deep?.value }}        // Safe nested access
={{ $('Node Name').item.json.field }}   // Reference another node's output
={{ $now.toISO() }}                     // Current timestamp
={{ $env.API_KEY }}                     // Environment variable
={{ $execution.id }}                    // Current execution ID
={{ $workflow.id }}                     // Workflow ID
={{ $input.all() }}                     // All input items (Code node)
={{ $input.item }}                      // Current item (Code node)
={{ DateTime.now().toFormat('yyyy-MM-dd') }}  // Luxon date formatting
```
