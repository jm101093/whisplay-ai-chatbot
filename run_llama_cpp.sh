#!/bin/bash

# llama.cpp Server Startup Script
# Starts the llama.cpp server with OpenAI-compatible API

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if .env file exists
if [ -f "$SCRIPT_DIR/.env" ]; then
    print_info "Loading environment variables from .env file..."
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
else
    print_warn ".env file not found. Using default values."
fi

# Configuration with defaults
MODEL_PATH="${LLAMA_CPP_MODEL_PATH:-$SCRIPT_DIR/models/model.gguf}"
HOST="${LLAMA_CPP_HOST:-127.0.0.1}"
PORT="${LLAMA_CPP_PORT:-8080}"
CONTEXT_SIZE="${LLAMA_CPP_CONTEXT_SIZE:-4096}"
N_GPU_LAYERS="${LLAMA_CPP_N_GPU_LAYERS:-0}"
THREADS="${LLAMA_CPP_THREADS:-4}"
BATCH_SIZE="${LLAMA_CPP_BATCH_SIZE:-512}"
EXTRA_ARGS="${LLAMA_CPP_EXTRA_ARGS:-}"

# Check if llama.cpp server exists
SERVER_PATH="$SCRIPT_DIR/llama.cpp/server"
if [ ! -f "$SERVER_PATH" ]; then
    # Try build directory locations
    if [ -f "$SCRIPT_DIR/llama.cpp/build/bin/llama-server" ]; then
        SERVER_PATH="$SCRIPT_DIR/llama.cpp/build/bin/llama-server"
    elif [ -f "$SCRIPT_DIR/llama.cpp/build/llama-server" ]; then
        SERVER_PATH="$SCRIPT_DIR/llama.cpp/build/llama-server"
    fi
fi

if [ ! -f "$SERVER_PATH" ]; then
    print_error "llama.cpp server not found!"
    print_error "Please run: bash install_llama_cpp.sh"
    exit 1
fi

# Check if model file exists
if [ ! -f "$MODEL_PATH" ]; then
    print_error "Model file not found: $MODEL_PATH"
    print_error "Please download a GGUF model file to the models directory."
    echo ""
    echo "Example models for Raspberry Pi:"
    echo "  • Qwen2.5-0.5B-Instruct-Q4_K_M.gguf (~350MB)"
    echo "  • TinyLlama-1.1B-Chat-Q4_K_M.gguf (~650MB)"
    echo "  • Phi-2-Q4_K_M.gguf (~1.6GB)"
    exit 1
fi

# Check if port is already in use
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    print_error "Port $PORT is already in use!"
    print_error "Please stop the existing process or change LLAMA_CPP_PORT in .env"
    exit 1
fi

echo "=========================================="
echo "Starting llama.cpp Server"
echo "=========================================="
print_info "Model: $MODEL_PATH"
print_info "Host: $HOST"
print_info "Port: $PORT"
print_info "Context Size: $CONTEXT_SIZE"
print_info "Threads: $THREADS"
print_info "Batch Size: $BATCH_SIZE"
print_info "GPU Layers: $N_GPU_LAYERS"
echo "=========================================="
echo ""

# Build the command
CMD="$SERVER_PATH \
  --model \"$MODEL_PATH\" \
  --host $HOST \
  --port $PORT \
  --ctx-size $CONTEXT_SIZE \
  --threads $THREADS \
  --batch-size $BATCH_SIZE \
  --n-gpu-layers $N_GPU_LAYERS \
  --jinja \
  --cont-batching \
  --flash-attn on \
  --mlock \
  --no-mmap \
  --rope-freq-scale 1 \
  -n 512"

# Add extra arguments if provided
if [ -n "$EXTRA_ARGS" ]; then
    CMD="$CMD $EXTRA_ARGS"
fi

print_info "Starting server..."
print_info "OpenAI-compatible API endpoint: http://$HOST:$PORT/v1/chat/completions"
print_info "Health check endpoint: http://$HOST:$PORT/health"
echo ""
print_info "Press Ctrl+C to stop the server"
echo ""

# Execute the command
eval $CMD
