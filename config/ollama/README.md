# Ollama Configuration Reference for Ampere A1 (4 OCPU, 24 GB RAM)
#
# Key Environment Variables:
# OLLAMA_HOST: Host and port Ollama listens on (0.0.0.0:11434 inside container)
# OLLAMA_NUM_PARALLEL: Concurrent requests per model. Set to 1 for CPU inference to avoid thread thrashing.
# OLLAMA_MAX_LOADED_MODELS: Number of models loaded in memory simultaneously. Set to 1 to reserve RAM.
# OLLAMA_KEEP_ALIVE: Duration model remains in memory (24h or -1 for persistent fast responses).
# OMP_NUM_THREADS: Thread count for OpenMP CPU matrix operations (matches 4 OCPUs).
# OLLAMA_CONTEXT_SIZE: Default token context size (e.g., 8192).

