---
name: n8n_master
description: "n8n 워크플로우 제어 도구. 사용자가 워크플로우 조회, 생성, 수정, 활성화, 실행 등을 요청할 때 사용합니다. 'n8n', '워크플로우', '자동화', 'workflow' 등의 키워드가 포함된 요청에 적합합니다."
argument-hint: "[query or action]"
disable-model-invocation: true
user-invocable: true
allowed-tools: Bash(python3 *), Bash(cat *), Bash(mkdir -p *)
---

# n8n Master Skill — v1

이 스킬은 **Orchestration + HTTP 정의 분리** 아키텍처(v1)를 따릅니다.

- `SKILL.md` (이 파일) — 의도 해석, 크레덴셜 흐름, 에러 정책, 출력 포맷
- `endpoints.json` — HTTP 정의 (method, path, auth, params, body 허용/금지 필드)
- `.env` — 크레덴셜 (API key, base URL) — **Git 제외**
- `refs/` — 워크플로우 구축 레퍼런스 문서

---

## 1. 크레덴셜 흐름

### .env 로드 및 검증

매 실행 시 아래 순서로 크레덴셜을 확인합니다.

```python
import os, json

SKILL_DIR = os.path.expanduser("~/.claude/skills/n8n_master")
ENV_PATH = os.path.join(SKILL_DIR, ".env")

def load_env():
    """Load .env file into os.environ"""
    if not os.path.exists(ENV_PATH):
        return False
    with open(ENV_PATH) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ[k.strip()] = v.strip()
    return True

def check_credentials():
    load_env()
    url = os.environ.get("N8N_URL", "")
    key = os.environ.get("N8N_API_KEY", "")
    if not url or not key or key == "your-api-key-here":
        return "MISSING"
    return "OK"
```

- `.env`가 없거나 `N8N_API_KEY`가 미설정이면 사용자에게 안내:
  - "n8n API Key가 필요합니다. n8n > Settings > Personal > API Key에서 확인할 수 있습니다."
- Key를 받으면 `.env`에 저장 후 재검증

### .env 파일 형식

```ini
N8N_URL=https://your-n8n-instance.example.com
N8N_API_KEY=your-api-key-here
```

### HTTP 호출 헬퍼

`endpoints.json`을 읽어 동적으로 URL과 헤더를 구성합니다.

```python
import urllib.request, urllib.error, json, os

def n8n_request(endpoint_id, path_params=None, query_params=None, body=None):
    """
    endpoints.json의 endpoint_id에 해당하는 HTTP 요청을 실행합니다.
    path_params: {"id": "workflow_id"} 형식
    query_params: {"limit": 50, "active": True} 형식
    body: dict (POST/PUT body)
    """
    skill_dir = os.path.expanduser("~/.claude/skills/n8n_master")
    with open(os.path.join(skill_dir, "endpoints.json")) as f:
        spec = json.load(f)

    base_url = os.environ.get("N8N_URL", "").rstrip("/")
    api_key = os.environ.get("N8N_API_KEY", "")

    ep = next((e for e in spec["endpoints"] if e["id"] == endpoint_id), None)
    if not ep:
        raise ValueError(f"Unknown endpoint: {endpoint_id}")

    path = ep["path"]
    if path_params:
        for k, v in path_params.items():
            path = path.replace(f"{{{k}}}", str(v))

    url = base_url + path
    if query_params:
        qs = "&".join(f"{k}={v}" for k, v in query_params.items())
        url += f"?{qs}"

    headers = {
        spec["auth"]["key"]: api_key,
        "Content-Type": "application/json"
    }

    data = json.dumps(body, ensure_ascii=False).encode("utf-8") if body else None
    req = urllib.request.Request(url, data=data, headers=headers, method=ep["method"])

    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {e.code}: {error_body}")
```

---

## 2. 의도 → Endpoint 매핑

사용자 요청을 분석하여 적절한 `endpoint_id`를 선택합니다.

| 사용자 표현 | endpoint_id | 주의사항 |
|---|---|---|
| "워크플로우 목록", "어떤 워크플로우 있어?" | `list_workflows` | limit=50 기본값 |
| "워크플로우 {이름} 찾아줘", "검색" | `list_workflows` + name 파라미터 | 서버사이드 필터링 |
| "워크플로우 {id} 상세" | `get_workflow` | path_params={"id": ...} |
| "워크플로우 만들어줘", "생성" | `create_workflow` | refs/ 문서 참조 필수 |
| "수정해줘", "업데이트" | `update_workflow` | 사용자 확인 후 실행 |
| "활성화해줘" | `activate_workflow` | 사용자 확인 후 실행 |
| "비활성화해줘" | `deactivate_workflow` | **사용자 확인 필수** |
| "실행해줘" | `execute_workflow` 또는 Webhook | Webhook 방식 우선 |
| "실행 기록", "로그" | `list_executions` | workflowId 파라미터 |

---

## 3. 워크플로우 생성/수정 시 필수 규칙

### body 필드 제한

`endpoints.json`의 `body_allowed` 필드에 명시된 것만 body에 포함합니다:
- ✅ `name`, `nodes`, `connections`, `active`
- ❌ `settings`, `pinData`, `staticData`, `id`, `createdAt`, `updatedAt` — 400 에러 발생

### refs/ 레퍼런스 참조 (생성/수정 시 필수)

| 파일 | 용도 |
|---|---|
| `refs/01-workflow-json-schema.md` | nodes, connections JSON 구조 확인 |
| `refs/02-node-types-reference.md` | 노드별 파라미터 (Webhook, Schedule, HTTP 등) |
| `refs/03-connection-patterns.md` | 분기, Fan-out, Merge, 루프 패턴 |
| `refs/04-workflow-templates.md` | 즉시 사용 가능한 완성 템플릿 |
| `refs/05-building-methodology.md` | 구축 방법론, 품질 체크리스트 |

---

## 4. 파괴적 작업 확인 정책

아래 작업은 실제 API 호출 **직전** 반드시 사용자 확인을 받습니다:

- **수정 (PUT)**: "워크플로우 '{이름}' (ID: {id})을 수정합니다. 진행할까요?"
- **비활성화**: "워크플로우 '{이름}'을 비활성화합니다. 진행할까요?"

사용자가 명시적으로 요청했더라도 확인 없이 실행하지 않습니다.

---

## 5. 에러 정책

| HTTP 코드 | 처리 |
|---|---|
| 400 | body 필드 확인 — body_forbidden 필드 제거 후 재시도 |
| 401 | API Key 재입력 요청 |
| 404 | endpoint_id 또는 path_params 확인 |
| 405 | 해당 메서드 미지원 — endpoints.json 확인 |
| 5xx | 30초 후 1회 재시도, 실패 시 사용자 보고 |

---

## 6. 출력 포맷

워크플로우 목록은 마크다운 테이블로 정리합니다:

```python
def format_workflows(data):
    workflows = data.get("data", [])
    print(f"| 이름 | ID | 상태 | 생성일 |")
    print(f"|------|-----|------|--------|")
    for w in workflows:
        status = "✅ 활성" if w.get("active") else "⏸ 비활성"
        created = w.get("createdAt", "")[:10]
        print(f"| {w['name']} | `{w['id'][:8]}...` | {status} | {created} |")
```

단일 워크플로우 조회 결과는 핵심 필드만 요약하여 자연어로 설명합니다.

---

## 7. Webhook 실행

`execute_workflow` endpoint는 공개 API v1에서 미지원(405)입니다. Webhook 트리거 방식을 우선합니다:

```python
def trigger_webhook(webhook_path, payload=None):
    base_url = os.environ.get("N8N_URL", "").rstrip("/")
    url = f"{base_url}/webhook/{webhook_path}"
    data = json.dumps(payload or {}, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(url, data=data,
                                  headers={"Content-Type": "application/json"},
                                  method="POST")
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())
```
