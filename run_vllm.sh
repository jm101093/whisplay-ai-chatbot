#!/bin/bash
# vLLM Server Startup Script
# This script starts the vLLM server with OpenAI-compatible API

set -e

# Source environment variables if .env file exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Default values
VLLM_ENV_PATH="${VLLM_ENV_PATH:-$HOME/vllm-env}"
VLLM_MODEL_PATH="${VLLM_MODEL_PATH:-$HOME/models/qwen2.5-0.5b}"
VLLM_HOST="${VLLM_HOST:-0.0.0.0}"
VLLM_PORT="${VLLM_PORT:-8000}"
VLLM_MAX_MODEL_LEN="${VLLM_MAX_MODEL_LEN:-2048}"
VLLM_GPU_MEMORY_UTILIZATION="${VLLM_GPU_MEMORY_UTILIZATION:-0.9}"
VLLM_EXTRA_ARGS="${VLLM_EXTRA_ARGS:-}"

# Colors
red="$( (/usr/bin/tput bold || :; /usr/bin/tput setaf 1 || :) 2>&-)"
green="$( (/usr/bin/tput bold || :; /usr/bin/tput setaf 2 || :) 2>&-)"
yellow="$( (/usr/bin/tput bold || :; /usr/bin/tput setaf 3 || :) 2>&-)"
plain="$( (/usr/bin/tput sgr0 || :) 2>&-)"

status() { echo "${green}>>>${plain} $*" >&2; }
error() { echo "${red}ERROR:${plain} $*"; exit 1; }
warning() { echo "${yellow}WARNING:${plain} $*"; }

# Check if vLLM environment exists
if [ ! -d "$VLLM_ENV_PATH" ]; then
    error "vLLM environment not found at $VLLM_ENV_PATH. Please run: bash install_vllm.sh"
fi

# Check if model path exists
if [ ! -d "$VLLM_MODEL_PATH" ]; then
    error "Model not found at $VLLM_MODEL_PATH. Please download a model first."
fi

# Activate vLLM environment
status "Activating vLLM environment..."
source "$VLLM_ENV_PATH/bin/activate"

# Check if vLLM is already running
if lsof -Pi :$VLLM_PORT -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    warning "vLLM server is already running on port $VLLM_PORT"
    read -p "Do you want to kill it and restart? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        PID=$(lsof -Pi :$VLLM_PORT -sTCP:LISTEN -t)
        kill -9 $PID
        sleep 2
    else
        exit 0
    fi
fi

# Build command
CMD="python -m vllm.entrypoints.openai.api_server \
    --model $VLLM_MODEL_PATH \
    --host $VLLM_HOST \
    --port $VLLM_PORT \
    --max-model-len $VLLM_MAX_MODEL_LEN"

# Add GPU memory utilization if not on CPU
if command -v nvidia-smi &> /dev/null; then
    CMD="$CMD --gpu-memory-utilization $VLLM_GPU_MEMORY_UTILIZATION"
fi

# Add extra args if specified
if [ -n "$VLLM_EXTRA_ARGS" ]; then
    CMD="$CMD $VLLM_EXTRA_ARGS"
fi

status "Starting vLLM server..."
echo "${green}Model:${plain} $VLLM_MODEL_PATH"
echo "${green}Host:${plain} $VLLM_HOST"
echo "${green}Port:${plain} $VLLM_PORT"
echo "${green}Max Model Length:${plain} $VLLM_MAX_MODEL_LEN"
echo ""
echo "${yellow}Command:${plain} $CMD"
echo ""
status "Server will be available at: http://localhost:$VLLM_PORT/v1"
echo "Press Ctrl+C to stop the server"
echo ""

# Run vLLM server
eval $CMD
