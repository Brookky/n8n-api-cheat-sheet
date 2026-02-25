# n8n Connection Patterns Reference

> How to wire nodes together in the `connections` object — with full `nodes` + `connections` examples for each pattern.

---

## Core Rules

1. Connection keys are **node names** — not IDs
2. `main` is a doubly-nested array: `main[outputIndex][connectionList]`
3. `index` is the **destination node's input port** (0-based)
4. Regular nodes have 1 input port (`index: 0`), Merge nodes have 2+
5. IF node: `main[0]` = true, `main[1]` = false
6. Switch node: `main[0]` = first rule, `main[1]` = second rule, ... `main[N]` = fallback

---

## Pattern 1: Linear Chain

A → B → C sequential execution.

```json
{
  "nodes": [
    {
      "id": "uuid-1",
      "name": "Webhook",
      "type": "n8n-nodes-base.webhook",
      "typeVersion": 2,
      "position": [250, 300],
      "webhookId": "webhook-uuid",
      "parameters": {
        "httpMethod": "POST",
        "path": "my-endpoint",
        "responseMode": "lastNode"
      }
    },
    {
      "id": "uuid-2",
      "name": "Process Data",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [450, 300],
      "parameters": {
        "jsCode": "return $input.all().map(item => ({ json: { ...item.json, processed: true } }));",
        "mode": "runOnceForAllItems"
      }
    },
    {
      "id": "uuid-3",
      "name": "HTTP Request",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [650, 300],
      "parameters": {
        "method": "POST",
        "url": "https://api.example.com/data",
        "sendBody": true,
        "specifyBody": "json",
        "jsonBody": "={{ JSON.stringify($json) }}"
      }
    }
  ],
  "connections": {
    "Webhook": {
      "main": [
        [{ "node": "Process Data", "type": "main", "index": 0 }]
      ]
    },
    "Process Data": {
      "main": [
        [{ "node": "HTTP Request", "type": "main", "index": 0 }]
      ]
    }
  }
}
```

**Key point:** Each node's `main[0]` contains one next node.

---

## Pattern 2: IF Branch (Conditional)

Route data down two paths based on a condition.

```
Webhook → IF → [true]  → Send Email
             → [false] → Log Error
```

```json
{
  "nodes": [
    {
      "id": "uuid-1",
      "name": "Webhook",
      "type": "n8n-nodes-base.webhook",
      "typeVersion": 2,
      "position": [250, 300],
      "webhookId": "wh-uuid",
      "parameters": {
        "httpMethod": "POST",
        "path": "check",
        "responseMode": "onReceived"
      }
    },
    {
      "id": "uuid-2",
      "name": "Check Status",
      "type": "n8n-nodes-base.if",
      "typeVersion": 2.2,
      "position": [450, 300],
      "parameters": {
        "conditions": {
          "options": { "caseSensitive": true, "leftValue": "", "typeValidation": "strict" },
          "conditions": [
            {
              "id": "cond-1",
              "leftValue": "={{ $json.status }}",
              "rightValue": "ok",
              "operator": { "type": "string", "operation": "equals" }
            }
          ],
          "combinator": "and"
        },
        "options": {}
      }
    },
    {
      "id": "uuid-3",
      "name": "Send Email",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [650, 150],
      "parameters": {
        "method": "POST",
        "url": "https://api.example.com/notify",
        "sendBody": true,
        "specifyBody": "json",
        "jsonBody": "={{ JSON.stringify({ message: 'Success', data: $json }) }}"
      }
    },
    {
      "id": "uuid-4",
      "name": "Log Error",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [650, 450],
      "parameters": {
        "jsCode": "console.log('Error:', $json);\nreturn [{ json: { logged: true, error: $json } }];",
        "mode": "runOnceForAllItems"
      }
    }
  ],
  "connections": {
    "Webhook": {
      "main": [
        [{ "node": "Check Status", "type": "main", "index": 0 }]
      ]
    },
    "Check Status": {
      "main": [
        [{ "node": "Send Email", "type": "main", "index": 0 }],
        [{ "node": "Log Error", "type": "main", "index": 0 }]
      ]
    }
  }
}
```

**Key points:**
- IF node `main[0]` = true branch → Send Email
- IF node `main[1]` = false branch → Log Error
- Spread branch nodes ±150 on y-axis

---

## Pattern 3: Switch Multi-Route

Route to 3+ paths based on value.

```
Trigger → Switch → [email]    → Email Handler
                 → [slack]    → Slack Handler
                 → [fallback] → Default Handler
```

```json
{
  "nodes": [
    {
      "id": "uuid-1",
      "name": "Webhook",
      "type": "n8n-nodes-base.webhook",
      "typeVersion": 2,
      "position": [250, 300],
      "webhookId": "sw-uuid",
      "parameters": {
        "httpMethod": "POST",
        "path": "route",
        "responseMode": "onReceived"
      }
    },
    {
      "id": "uuid-2",
      "name": "Route by Channel",
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
        "options": { "fallbackOutput": "extra" }
      }
    },
    {
      "id": "uuid-3",
      "name": "Email Handler",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [650, 150],
      "parameters": { "method": "POST", "url": "https://api.example.com/email" }
    },
    {
      "id": "uuid-4",
      "name": "Slack Handler",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [650, 300],
      "parameters": { "method": "POST", "url": "https://hooks.slack.com/xxx" }
    },
    {
      "id": "uuid-5",
      "name": "Default Handler",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [650, 450],
      "parameters": {
        "jsCode": "return [{ json: { handled: 'default', original: $json } }];",
        "mode": "runOnceForAllItems"
      }
    }
  ],
  "connections": {
    "Webhook": {
      "main": [
        [{ "node": "Route by Channel", "type": "main", "index": 0 }]
      ]
    },
    "Route by Channel": {
      "main": [
        [{ "node": "Email Handler", "type": "main", "index": 0 }],
        [{ "node": "Slack Handler", "type": "main", "index": 0 }],
        [{ "node": "Default Handler", "type": "main", "index": 0 }]
      ]
    }
  }
}
```

**Key points:**
- `main[0]` = first rule (email), `main[1]` = second rule (slack), `main[2]` = fallback
- Fallback requires `"fallbackOutput": "extra"` in options

---

## Pattern 4: Fan-out (One to Many)

One output feeds multiple nodes simultaneously (parallel execution).

```
Trigger → Node A
        → Node B
        → Node C
```

```json
{
  "connections": {
    "Trigger": {
      "main": [
        [
          { "node": "Node A", "type": "main", "index": 0 },
          { "node": "Node B", "type": "main", "index": 0 },
          { "node": "Node C", "type": "main", "index": 0 }
        ]
      ]
    }
  }
}
```

**Key point:** Multiple target nodes in the **same inner array** of `main[0]`. Same output index, same array.

---

## Pattern 5: Merge (Many to One)

Rejoin branches after a fork. Merge node input ports (`index`) distinguish sources.

```
Branch A → Merge (input 0)
Branch B → Merge (input 1)
```

```json
{
  "nodes": [
    {
      "id": "uuid-1",
      "name": "Webhook",
      "type": "n8n-nodes-base.webhook",
      "typeVersion": 2,
      "position": [250, 300],
      "webhookId": "merge-uuid",
      "parameters": { "httpMethod": "POST", "path": "merge-test", "responseMode": "lastNode" }
    },
    {
      "id": "uuid-2",
      "name": "Get Users",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [450, 200],
      "parameters": { "method": "GET", "url": "https://api.example.com/users" }
    },
    {
      "id": "uuid-3",
      "name": "Get Orders",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [450, 400],
      "parameters": { "method": "GET", "url": "https://api.example.com/orders" }
    },
    {
      "id": "uuid-4",
      "name": "Merge Data",
      "type": "n8n-nodes-base.merge",
      "typeVersion": 3,
      "position": [650, 300],
      "parameters": { "mode": "append", "options": {} }
    },
    {
      "id": "uuid-5",
      "name": "Respond to Webhook",
      "type": "n8n-nodes-base.respondToWebhook",
      "typeVersion": 1.1,
      "position": [850, 300],
      "parameters": {
        "respondWith": "allEntries",
        "options": { "responseCode": 200 }
      }
    }
  ],
  "connections": {
    "Webhook": {
      "main": [
        [
          { "node": "Get Users", "type": "main", "index": 0 },
          { "node": "Get Orders", "type": "main", "index": 0 }
        ]
      ]
    },
    "Get Users": {
      "main": [
        [{ "node": "Merge Data", "type": "main", "index": 0 }]
      ]
    },
    "Get Orders": {
      "main": [
        [{ "node": "Merge Data", "type": "main", "index": 1 }]
      ]
    },
    "Merge Data": {
      "main": [
        [{ "node": "Respond to Webhook", "type": "main", "index": 0 }]
      ]
    }
  }
}
```

**Key points:**
- Webhook → Fan-out (Get Users + Get Orders in parallel)
- Get Users → Merge `index: 0` (first input)
- Get Orders → Merge `index: 1` (second input)
- Merge → Respond (single output)

---

## Pattern 6: IF Branch → Merge Rejoin

Split by condition, then rejoin for shared downstream processing.

```
Trigger → IF → [true]  → Transform A ──→ Merge → Final
             → [false] → Transform B ──↗
```

```json
{
  "nodes": [
    {
      "id": "uuid-1",
      "name": "Manual Trigger",
      "type": "n8n-nodes-base.manualTrigger",
      "typeVersion": 1,
      "position": [250, 300],
      "parameters": {}
    },
    {
      "id": "uuid-2",
      "name": "Check Type",
      "type": "n8n-nodes-base.if",
      "typeVersion": 2.2,
      "position": [450, 300],
      "parameters": {
        "conditions": {
          "options": { "caseSensitive": true, "leftValue": "", "typeValidation": "strict" },
          "conditions": [
            {
              "id": "cond-1",
              "leftValue": "={{ $json.type }}",
              "rightValue": "premium",
              "operator": { "type": "string", "operation": "equals" }
            }
          ],
          "combinator": "and"
        },
        "options": {}
      }
    },
    {
      "id": "uuid-3",
      "name": "Premium Transform",
      "type": "n8n-nodes-base.set",
      "typeVersion": 3.4,
      "position": [650, 200],
      "parameters": {
        "mode": "manual",
        "assignments": {
          "assignments": [
            { "id": "a1", "name": "tier", "value": "premium", "type": "string" },
            { "id": "a2", "name": "discount", "value": "20", "type": "number" }
          ]
        },
        "includeOtherFields": true,
        "options": {}
      }
    },
    {
      "id": "uuid-4",
      "name": "Standard Transform",
      "type": "n8n-nodes-base.set",
      "typeVersion": 3.4,
      "position": [650, 400],
      "parameters": {
        "mode": "manual",
        "assignments": {
          "assignments": [
            { "id": "a3", "name": "tier", "value": "standard", "type": "string" },
            { "id": "a4", "name": "discount", "value": "0", "type": "number" }
          ]
        },
        "includeOtherFields": true,
        "options": {}
      }
    },
    {
      "id": "uuid-5",
      "name": "Merge Results",
      "type": "n8n-nodes-base.merge",
      "typeVersion": 3,
      "position": [850, 300],
      "parameters": { "mode": "append", "options": {} }
    },
    {
      "id": "uuid-6",
      "name": "Save to DB",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [1050, 300],
      "parameters": {
        "method": "POST",
        "url": "https://api.example.com/save",
        "sendBody": true,
        "specifyBody": "json",
        "jsonBody": "={{ JSON.stringify($json) }}"
      }
    }
  ],
  "connections": {
    "Manual Trigger": {
      "main": [
        [{ "node": "Check Type", "type": "main", "index": 0 }]
      ]
    },
    "Check Type": {
      "main": [
        [{ "node": "Premium Transform", "type": "main", "index": 0 }],
        [{ "node": "Standard Transform", "type": "main", "index": 0 }]
      ]
    },
    "Premium Transform": {
      "main": [
        [{ "node": "Merge Results", "type": "main", "index": 0 }]
      ]
    },
    "Standard Transform": {
      "main": [
        [{ "node": "Merge Results", "type": "main", "index": 1 }]
      ]
    },
    "Merge Results": {
      "main": [
        [{ "node": "Save to DB", "type": "main", "index": 0 }]
      ]
    }
  }
}
```

---

## Pattern 7: Error Handling

Use `continueOnFail` + IF to detect and branch on errors.

```
Trigger → HTTP Request (continueOnFail) → Check Error → [error] → Handle Error
                                                       → [ok]    → Continue
```

```json
{
  "nodes": [
    {
      "id": "uuid-1",
      "name": "Schedule Trigger",
      "type": "n8n-nodes-base.scheduleTrigger",
      "typeVersion": 1.2,
      "position": [250, 300],
      "parameters": {
        "rule": { "interval": [{ "field": "cronExpression", "expression": "0 */6 * * *" }] }
      }
    },
    {
      "id": "uuid-2",
      "name": "Fetch API",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [450, 300],
      "parameters": {
        "method": "GET",
        "url": "https://api.example.com/data",
        "options": { "timeout": 60000 }
      },
      "continueOnFail": true,
      "retryOnFail": true,
      "maxTries": 3,
      "waitBetweenTries": 5000
    },
    {
      "id": "uuid-3",
      "name": "Check Error",
      "type": "n8n-nodes-base.if",
      "typeVersion": 2.2,
      "position": [650, 300],
      "parameters": {
        "conditions": {
          "options": { "caseSensitive": true, "leftValue": "", "typeValidation": "strict" },
          "conditions": [
            {
              "id": "err-check",
              "leftValue": "={{ $json.error }}",
              "rightValue": "",
              "operator": { "type": "string", "operation": "exists" }
            }
          ],
          "combinator": "and"
        },
        "options": {}
      }
    },
    {
      "id": "uuid-4",
      "name": "Handle Error",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [850, 150],
      "parameters": {
        "method": "POST",
        "url": "https://hooks.slack.com/services/xxx",
        "sendBody": true,
        "specifyBody": "json",
        "jsonBody": "={{ JSON.stringify({ text: 'API Error: ' + $json.error.message }) }}"
      }
    },
    {
      "id": "uuid-5",
      "name": "Process Data",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [850, 450],
      "parameters": {
        "jsCode": "return $input.all().map(item => ({ json: { ...item.json, processedAt: new Date().toISOString() } }));",
        "mode": "runOnceForAllItems"
      }
    }
  ],
  "connections": {
    "Schedule Trigger": {
      "main": [
        [{ "node": "Fetch API", "type": "main", "index": 0 }]
      ]
    },
    "Fetch API": {
      "main": [
        [{ "node": "Check Error", "type": "main", "index": 0 }]
      ]
    },
    "Check Error": {
      "main": [
        [{ "node": "Handle Error", "type": "main", "index": 0 }],
        [{ "node": "Process Data", "type": "main", "index": 0 }]
      ]
    }
  }
}
```

**Key points:**
- `continueOnFail: true` — workflow doesn't stop on error
- On error, `$json.error` object is auto-created
- IF checks whether error exists, then branches
- `retryOnFail` + `maxTries` + `waitBetweenTries` for auto-retry

---

## Pattern 8: Loop (Split In Batches)

Process large datasets in batches with a loop.

```
Trigger → Split In Batches → Process Batch → (loop back to Split)
                           ↘ Done (output 0)
```

```json
{
  "nodes": [
    {
      "id": "uuid-1",
      "name": "Manual Trigger",
      "type": "n8n-nodes-base.manualTrigger",
      "typeVersion": 1,
      "position": [250, 300],
      "parameters": {}
    },
    {
      "id": "uuid-2",
      "name": "Split In Batches",
      "type": "n8n-nodes-base.splitInBatches",
      "typeVersion": 3,
      "position": [450, 300],
      "parameters": { "batchSize": 50, "options": {} }
    },
    {
      "id": "uuid-3",
      "name": "Process Batch",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [650, 300],
      "parameters": {
        "method": "POST",
        "url": "https://api.example.com/batch",
        "sendBody": true,
        "specifyBody": "json",
        "jsonBody": "={{ JSON.stringify($json) }}"
      }
    },
    {
      "id": "uuid-4",
      "name": "Final Output",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [650, 500],
      "parameters": {
        "jsCode": "return [{ json: { status: 'all batches processed' } }];",
        "mode": "runOnceForAllItems"
      }
    }
  ],
  "connections": {
    "Manual Trigger": {
      "main": [
        [{ "node": "Split In Batches", "type": "main", "index": 0 }]
      ]
    },
    "Split In Batches": {
      "main": [
        [{ "node": "Final Output", "type": "main", "index": 0 }],
        [{ "node": "Process Batch", "type": "main", "index": 0 }]
      ]
    },
    "Process Batch": {
      "main": [
        [{ "node": "Split In Batches", "type": "main", "index": 0 }]
      ]
    }
  }
}
```

**Key points:**
- SplitInBatches `main[0]` = all batches done (exit loop)
- SplitInBatches `main[1]` = each batch output (loop body)
- Process Batch → SplitInBatches creates the loop-back

---

## Connection Patterns Summary

| Pattern | Connection Structure | Key Concept |
|---------|---------------------|-------------|
| Linear Chain | `A.main[0] → [B]` | Basic sequential |
| IF Branch | `IF.main[0] → [True], IF.main[1] → [False]` | Output index = branch |
| Switch Multi | `SW.main[0] → [R1], SW.main[1] → [R2], ...` | Rule order = output index |
| Fan-out | `A.main[0] → [B, C, D]` | Multiple nodes in one array |
| Merge | `A → Merge(index:0), B → Merge(index:1)` | Destination index = input port |
| Branch+Rejoin | `IF → A/B → Merge` | Branch then merge |
| Error Handling | `continueOnFail + IF(error exists)` | Detect error, then branch |
| Loop | `SplitBatch.main[1] → Process → SplitBatch` | Circular connection |
