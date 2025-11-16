#!/bin/bash

# llama.cpp Installation Script for ARM/aarch64 (Raspberry Pi)
# This script installs llama.cpp with OpenAI-compatible API server support

set -e  # Exit on error

echo "=========================================="
echo "llama.cpp Installation Script"
echo "=========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$SCRIPT_DIR/llama.cpp"

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

# Check if running on ARM architecture
ARCH=$(uname -m)
print_info "Detected architecture: $ARCH"

if [[ "$ARCH" != "aarch64" && "$ARCH" != "armv7l" && "$ARCH" != "arm64" ]]; then
    print_warn "This script is optimized for ARM architecture, but will continue anyway."
fi

# Install system dependencies
print_info "Installing system dependencies..."
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    cmake \
    git \
    pkg-config \
    libopenblas-dev

print_info "System dependencies installed successfully"

# Clone llama.cpp repository if not exists
if [ -d "$INSTALL_DIR" ]; then
    print_warn "llama.cpp directory already exists. Pulling latest changes..."
    cd "$INSTALL_DIR"
    git pull
else
    print_info "Cloning llama.cpp repository..."
    git clone https://github.com/ggerganov/llama.cpp.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# Build llama.cpp with OpenBLAS support for ARM optimization
print_info "Building llama.cpp with OpenBLAS support..."
print_info "This may take 10-30 minutes depending on your Raspberry Pi model..."

# Create build directory
mkdir -p build
cd build

# Configure with CMake using OpenBLAS
cmake .. \
    -DGGML_BLAS=ON \
    -DGGML_BLAS_VENDOR=OpenBLAS \
    -DBUILD_SHARED_LIBS=OFF \
    -DLLAMA_BUILD_SERVER=ON

# Build with all available cores
cmake --build . --config Release -j$(nproc)

# Verify the build
if [ -f "$INSTALL_DIR/build/bin/llama-server" ]; then
    print_info "✓ llama.cpp server built successfully!"
    # Create symbolic link to server binary
    ln -sf "$INSTALL_DIR/build/bin/llama-server" "$INSTALL_DIR/server"
elif [ -f "$INSTALL_DIR/build/llama-server" ]; then
    print_info "✓ llama.cpp server built successfully!"
    # Create symbolic link to server binary (alternative location)
    ln -sf "$INSTALL_DIR/build/llama-server" "$INSTALL_DIR/server"
else
    print_error "Failed to build llama.cpp server"
    print_error "Expected location: $INSTALL_DIR/build/bin/llama-server or $INSTALL_DIR/build/llama-server"
    exit 1
fi

cd "$INSTALL_DIR"

# Create a symbolic link for easier access
print_info "Creating symbolic link..."
ln -sf "$INSTALL_DIR/server" "$SCRIPT_DIR/llama-cpp-server"

# Create models directory
MODELS_DIR="$SCRIPT_DIR/models"
if [ ! -d "$MODELS_DIR" ]; then
    mkdir -p "$MODELS_DIR"
    print_info "Created models directory: $MODELS_DIR"
fi

echo ""
echo "=========================================="
print_info "llama.cpp Installation Complete!"
echo "=========================================="
echo ""
print_info "Next steps:"
echo "  1. Download a GGUF model file to: $MODELS_DIR"
echo "     Example: wget https://huggingface.co/...model.gguf -P $MODELS_DIR"
echo ""
echo "  2. Recommended models for Raspberry Pi:"
echo "     • Pi Zero 2W / Pi 4 (2-4GB):"
echo "       - Qwen2.5-0.5B-Instruct (Q4_K_M): ~350MB"
echo "       - TinyLlama-1.1B (Q4_K_M): ~650MB"
echo ""
echo "     • Pi 4 (8GB) / Pi 5 (4-8GB):"
echo "       - Phi-2 (Q4_K_M): ~1.6GB"
echo "       - Qwen2.5-1.5B-Instruct (Q4_K_M): ~900MB"
echo "       - Mistral-7B (Q3_K_S): ~3GB"
echo ""
echo "  3. Configure .env file:"
echo "     LLAMA_CPP_MODEL_PATH=$MODELS_DIR/your-model.gguf"
echo "     LLAMA_CPP_HOST=127.0.0.1"
echo "     LLAMA_CPP_PORT=8080"
echo ""
echo "  4. Start the server:"
echo "     bash run_llama_cpp.sh"
echo ""
print_info "The llama.cpp server provides OpenAI-compatible API at /v1/chat/completions"
echo ""
