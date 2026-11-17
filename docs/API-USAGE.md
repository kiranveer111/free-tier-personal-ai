# API Usage & Integration Guide

This guide explains how to programmatically interact with your self-hosted AI server using **curl**, **Python**, and **Node.js** from external applications and development workflows.

---

## 1. Authentication & Security Architecture

> [!IMPORTANT]
> **Ollama (`http://ollama:11434`) is strictly private** and not accessible directly from the public internet. All external API requests route securely through **Open WebUI** (or the optional **LiteLLM** proxy) using HTTPS and Bearer Token authentication.

### Generating an API Key in Open WebUI:
1. Log in to your Open WebUI instance at `https://ai.yourdomain.com`.
2. Click your user profile in the bottom-left corner > **Settings** > **Account**.
3. Under **API Keys**, click **Create New Key**.
4. Copy the generated key (format: `sk-...`). Keep it secret.

---

## 2. API Examples (OpenAI-Compatible Endpoint)

Open WebUI provides a fully OpenAI-compatible `/api/chat/completions` endpoint.

### Example 2.1: cURL

```bash
curl -X POST "https://ai.yourdomain.com/api/chat/completions" \
  -H "Authorization: Bearer YOUR_OPEN_WEBUI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5:3b",
    "messages": [
      {"role": "system", "content": "You are an expert DevOps engineer."},
      {"role": "user", "content": "How do I check system memory on Linux?"}
    ],
    "temperature": 0.7,
    "stream": false
  }'
```

---

### Example 2.2: Python (`requests` and `openai` SDK)

#### Using `requests`:
```python
import os
import requests

API_URL = "https://ai.yourdomain.com/api/chat/completions"
API_KEY = os.getenv("AI_SERVER_API_KEY", "YOUR_OPEN_WEBUI_API_KEY")

headers = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}

payload = {
    "model": "qwen2.5:3b",
    "messages": [
        {"role": "user", "content": "Explain the difference between TCP and UDP."}
    ],
    "temperature": 0.7
}

response = requests.post(API_URL, headers=headers, json=payload)
data = response.json()
print("Response:", data["choices"][0]["message"]["content"])
```

#### Using the Official `openai` Python SDK:
```python
from openai import OpenAI

client = OpenAI(
    base_url="https://ai.yourdomain.com/api",
    api_key="YOUR_OPEN_WEBUI_API_KEY"
)

response = client.chat.completions.create(
    model="qwen2.5:3b",
    messages=[
        {"role": "user", "content": "Write a Python function to validate IPv4 addresses."}
    ]
)

print(response.choices[0].message.content)
```

---

### Example 2.3: Node.js (`fetch`)

```javascript
// Works natively in Node.js 18+
const API_URL = "https://ai.yourdomain.com/api/chat/completions";
const API_KEY = process.env.AI_SERVER_API_KEY || "YOUR_OPEN_WEBUI_API_KEY";

async function queryAI() {
  const response = await fetch(API_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${API_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model: "qwen2.5:3b",
      messages: [
        { role: "user", content: "What is an event loop?" }
      ]
    })
  });

  const data = await response.json();
  console.log("AI Response:\n", data.choices[0].message.content);
}

queryAI().catch(console.error);
```

---

## 3. Embedding Generation for RAG / Vector Applications

Generate semantic vector embeddings using the `bge-m3` model:

```bash
curl -X POST "https://ai.yourdomain.com/api/embeddings" \
  -H "Authorization: Bearer YOUR_OPEN_WEBUI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "bge-m3",
    "input": "Oracle Cloud Ampere A1 ARM64 deployment"
  }'
```

---

## 4. Optional LiteLLM Integration

If you enabled the `modules/litellm` stack, you can route OpenAI-compatible requests directly to `http://litellm:4000` with unified model fallback, cost tracking, and team quota enforcement.

