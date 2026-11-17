# Open WebUI Configuration Reference
#
# First Admin Setup:
# 1. ENABLE_SIGNUP must be set to 'true' upon initial deployment.
# 2. Browse to https://${AI_DOMAIN} and register the first account.
# 3. The first registered user automatically becomes the Admin.
# 4. In Admin Panel -> Settings -> General, disable new signups, or set ENABLE_SIGNUP=false in .env and restart.
#
# RAG Embeddings:
# Uses BGE-M3 (567M params) via Ollama embedding endpoint (http://ollama:11434).
# Chunk Size: 1000 tokens with 100 token overlap.
#
# CPU Performance Optimization:
# - TASK_MODEL: Set to 'qwen2.5:0.5b' to offload chat titling to an ultra-lightweight model (~300ms).
# - ENABLE_TAGS_GENERATION: Set to false to avoid redundant LLM calls per message.
# - ENABLE_FOLLOW_UP_GENERATION: Set to false to prevent queuing delays on CPU.

