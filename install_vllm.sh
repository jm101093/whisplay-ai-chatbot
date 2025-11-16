#!/bin/bash
# vLLM Installation Script for ARM/aarch64 (Raspberry Pi)
# This script installs vLLM and its dependencies for running local LLM inference

set -e

red="$( (/usr/bin/tput bold || :; /usr/bin/tput setaf 1 || :) 2>&-)"
green="$( (/usr/bin/tput bold || :; /usr/bin/tput setaf 2 || :) 2>&-)"
plain="$( (/usr/bin/tput sgr0 || :) 2>&-)"

status() { echo "${green}>>>${plain} $*" >&2; }
error() { echo "${red}ERROR:${plain} $*"; exit 1; }
warning() { echo "${red}WARNING:${plain} $*"; }

# Check if running on ARM
ARCH=$(uname -m)
if [[ "$ARCH" != "aarch64" && "$ARCH" != "arm64" ]]; then
    warning "This script is optimized for ARM/aarch64 architecture. You're running on $ARCH"
    read -p "Do you want to continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

status "Starting vLLM installation for ARM/aarch64..."

# Step 1: Update system
status "Step 1/7: Updating system packages..."
sudo apt update
sudo apt upgrade -y

# Step 2: Install required system dependencies
status "Step 2/7: Installing system dependencies..."
sudo apt install -y libnuma-dev build-essential git python3-dev python3-venv

# Check if libnuma is properly installed
if ! ldconfig -p | grep -q libnuma; then
    warning "libnuma-dev may not be properly installed. Attempting to build from source..."
    
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    git clone https://github.com/numactl/numactl.git
    cd numactl
    ./autogen.sh
    ./configure
    make
    sudo make install
    sudo ldconfig
    
    cd ~
    rm -rf "$TEMP_DIR"
    
    status "libnuma installed from source"
fi

# Step 3: Set up Python virtual environment
VLLM_ENV_PATH="$HOME/vllm-env"

if [ -d "$VLLM_ENV_PATH" ]; then
    warning "vLLM environment already exists at $VLLM_ENV_PATH"
    read -p "Do you want to remove and recreate it? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$VLLM_ENV_PATH"
    else
        status "Using existing environment"
    fi
fi

if [ ! -d "$VLLM_ENV_PATH" ]; then
    status "Step 3/7: Creating Python virtual environment..."
    python3 -m venv "$VLLM_ENV_PATH"
fi

source "$VLLM_ENV_PATH/bin/activate"

# Step 4: Install PyTorch
status "Step 4/7: Installing PyTorch (nightly build for ARM)..."
pip install --upgrade pip setuptools wheel
pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cpu

# Step 5: Install Python dependencies
status "Step 5/7: Installing Python dependencies..."
pip install numba scipy huggingface-hub[cli,hf_transfer] setuptools_scm
pip install "numpy<2"
pip install diskcache cmake distro

# Step 6: Install vLLM
status "Step 6/7: Installing vLLM from source..."
VLLM_DIR="$HOME/vllm"

if [ -d "$VLLM_DIR" ]; then
    warning "vLLM directory already exists at $VLLM_DIR"
    read -p "Do you want to update it? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd "$VLLM_DIR"
        git pull
    fi
else
    git clone https://github.com/vllm-project/vllm.git "$VLLM_DIR"
    cd "$VLLM_DIR"
fi

cd "$VLLM_DIR"
export VLLM_TARGET_DEVICE=empty
pip install -e .

# Step 7: Create activation helper
status "Step 7/7: Creating activation helper script..."
cat > "$HOME/activate_vllm.sh" << 'EOF'
#!/bin/bash
# Activate vLLM environment
source ~/vllm-env/bin/activate
echo "vLLM environment activated"
echo "To start vLLM server, run: bash run_vllm.sh"
EOF
chmod +x "$HOME/activate_vllm.sh"

status "vLLM installation completed successfully!"
echo ""
echo "${green}Next steps:${plain}"
echo "1. Activate the vLLM environment:"
echo "   ${green}source ~/activate_vllm.sh${plain}"
echo ""
echo "2. Download a model (example with Qwen model):"
echo "   ${green}huggingface-cli download Qwen/Qwen2.5-0.5B-Instruct --local-dir ~/models/qwen2.5-0.5b${plain}"
echo ""
echo "3. Configure your .env file with:"
echo "   ${green}LLM_SERVER=OPENAI${plain}"
echo "   ${green}OPENAI_API_BASE_URL=http://localhost:8000/v1${plain}"
echo "   ${green}OPENAI_API_KEY=token-abc123${plain}  # Can be any string for local vLLM"
echo "   ${green}SERVE_VLLM=true${plain}  # Auto-start vLLM with chatbot"
echo "   ${green}VLLM_MODEL_PATH=~/models/qwen2.5-0.5b${plain}"
echo ""
echo "4. Start vLLM server:"
echo "   ${green}bash run_vllm.sh${plain}"
echo ""
echo "${green}Installation directory:${plain} $VLLM_DIR"
echo "${green}Python environment:${plain} $VLLM_ENV_PATH"
