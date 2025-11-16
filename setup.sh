#!/bin/bash

# Whisplay AI Chatbot - Interactive Setup Script
# This script helps you configure and install the backends you want to use

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Function to print colored messages
print_header() {
    echo -e "${BOLD}${CYAN}=========================================="
    echo -e "$1"
    echo -e "==========================================${NC}"
    echo ""
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_choice() {
    echo -e "${MAGENTA}  $1${NC}"
}

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if .env file exists
ENV_FILE="$SCRIPT_DIR/.env"
if [ -f "$ENV_FILE" ]; then
    print_warn ".env file already exists. Backing it up to .env.backup"
    cp "$ENV_FILE" "$ENV_FILE.backup.$(date +%Y%m%d_%H%M%S)"
fi

clear
print_header "Whisplay AI Chatbot - Interactive Setup"
echo "This script will help you configure your AI chatbot with the backends you prefer."
echo ""
echo -e "${BOLD}Hardware Detection:${NC}"
ARCH=$(uname -m)
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
print_info "Architecture: $ARCH"
print_info "Total RAM: ${TOTAL_RAM}MB"
echo ""

# Detect Raspberry Pi model
if [ -f /proc/device-tree/model ]; then
    PI_MODEL=$(cat /proc/device-tree/model)
    print_info "Device: $PI_MODEL"
    echo ""
fi

# ============================================================================
# ASR (Automatic Speech Recognition) Selection
# ============================================================================
print_header "Step 1: Select ASR (Speech Recognition) Backend"
echo "Choose how you want to convert speech to text:"
echo ""
print_choice "1) Cloud Services (Recommended for beginners)"
print_choice "   - OpenAI Whisper API (high quality, costs $0.006/min)"
print_choice "   - Google Gemini (free tier available)"
print_choice "   - ByteDance VolcEngine (China region)"
print_choice "   - Tencent Cloud (China region)"
echo ""
print_choice "2) Local - faster-whisper (FREE, runs on device)"
print_choice "   - Best for offline use and privacy"
print_choice "   - Requires 500MB-2GB RAM depending on model size"
print_choice "   - Recommended: 'tiny' for Pi Zero/4, 'base' for Pi 5"
echo ""
print_choice "3) Local - Vosk (FREE, lightweight alternative)"
print_choice "   - Lower quality but very fast"
print_choice "   - Good for Pi Zero 2W"
echo ""

read -p "Enter your choice (1-3): " asr_choice

case $asr_choice in
    1)
        echo ""
        print_info "Select cloud ASR provider:"
        print_choice "1) OpenAI Whisper API"
        print_choice "2) Google Gemini"
        print_choice "3) ByteDance VolcEngine"
        print_choice "4) Tencent Cloud"
        read -p "Enter provider (1-4): " cloud_asr
        
        case $cloud_asr in
            1) ASR_SERVER="OPENAI" ;;
            2) ASR_SERVER="GEMINI" ;;
            3) ASR_SERVER="VOLCENGINE" ;;
            4) ASR_SERVER="TENCENT" ;;
            *) print_error "Invalid choice"; exit 1 ;;
        esac
        ;;
    2)
        ASR_SERVER="WHISPER"
        INSTALL_FASTER_WHISPER=true
        
        echo ""
        print_info "Select Whisper model size:"
        print_choice "1) tiny (~75MB, fastest, good for Pi Zero/4)"
        print_choice "2) base (~150MB, better quality)"
        print_choice "3) small (~500MB, high quality, Pi 5 recommended)"
        read -p "Enter choice (1-3): " whisper_model
        
        case $whisper_model in
            1) WHISPER_MODEL_SIZE="tiny" ;;
            2) WHISPER_MODEL_SIZE="base" ;;
            3) WHISPER_MODEL_SIZE="small" ;;
            *) WHISPER_MODEL_SIZE="tiny" ;;
        esac
        ;;
    3)
        ASR_SERVER="VOSK"
        print_warn "You'll need to download a Vosk model separately from: https://alphacephei.com/vosk/models"
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

print_info "ASR Backend: $ASR_SERVER"
echo ""

# ============================================================================
# LLM (Large Language Model) Selection
# ============================================================================
print_header "Step 2: Select LLM (AI Brain) Backend"
echo "Choose the AI model that will generate responses:"
echo ""
print_choice "1) Cloud Services (Recommended for beginners)"
print_choice "   - OpenAI GPT (high quality, requires paid API key)"
print_choice "   - Google Gemini (free tier available, 15 req/min)"
print_choice "   - ByteDance Doubao (China region)"
echo ""
print_choice "2) Local - vLLM (FREE, powerful but resource-intensive)"
print_choice "   - Best for Pi 5 with 8GB RAM"
print_choice "   - Supports larger models with good performance"
print_choice "   - OpenAI-compatible API"
echo ""
print_choice "3) Local - llama.cpp (FREE, lightweight and efficient)"
print_choice "   - Best for Pi Zero 2W, Pi 4, Pi 5"
print_choice "   - Uses quantized GGUF models (smaller size)"
print_choice "   - Recommended for resource-constrained devices"
echo ""

read -p "Enter your choice (1-3): " llm_choice

case $llm_choice in
    1)
        echo ""
        print_info "Select cloud LLM provider:"
        print_choice "1) OpenAI (GPT-4, GPT-4o, etc.)"
        print_choice "2) Google Gemini"
        print_choice "3) ByteDance Doubao"
        read -p "Enter provider (1-3): " cloud_llm
        
        case $cloud_llm in
            1) LLM_SERVER="OPENAI" ;;
            2) LLM_SERVER="GEMINI" ;;
            3) LLM_SERVER="VOLCENGINE" ;;
            *) print_error "Invalid choice"; exit 1 ;;
        esac
        ;;
    2)
        LLM_SERVER="OPENAI"
        INSTALL_VLLM=true
        USE_LOCAL_LLM="vllm"
        
        echo ""
        print_info "Recommended vLLM models:"
        print_choice "1) Qwen2.5-0.5B (~1GB RAM) - Pi 4 8GB / Pi 5"
        print_choice "2) Qwen2.5-1.5B (~2-3GB RAM) - Pi 5 4GB+"
        print_choice "3) Phi-2 (~4GB RAM) - Pi 5 8GB"
        print_choice "4) I'll download my own model later"
        read -p "Enter choice (1-4): " vllm_model
        
        case $vllm_model in
            1) VLLM_MODEL="Qwen/Qwen2.5-0.5B-Instruct" ;;
            2) VLLM_MODEL="Qwen/Qwen2.5-1.5B-Instruct" ;;
            3) VLLM_MODEL="microsoft/phi-2" ;;
            4) VLLM_MODEL="" ;;
        esac
        ;;
    3)
        LLM_SERVER="OPENAI"
        INSTALL_LLAMA_CPP=true
        USE_LOCAL_LLM="llama.cpp"
        
        echo ""
        print_info "Select llama.cpp model category:"
        print_choice "1) Ultra-Lightweight (300-700MB) - Pi Zero 2W / Pi 4"
        print_choice "2) Lightweight (700MB-1.2GB) - Pi 4 / Pi 5"
        print_choice "3) Medium (1.2GB-2GB) - Pi 5 (4GB+)"
        print_choice "4) Large (2GB-4.5GB) - Pi 5 (8GB)"
        print_choice "5) I'll download my own model later"
        read -p "Enter category (1-5): " llama_category
        
        case $llama_category in
            1)
                echo ""
                print_info "Ultra-Lightweight Models:"
                print_choice "1) Qwen2.5-0.5B-Q4_K_M (~350MB) - Fast, good for simple tasks"
                print_choice "2) TinyLlama-1.1B-Q4_K_M (~650MB) - Better quality, still fast"
                print_choice "3) Qwen2.5-0.5B-Q8_0 (~550MB) - Higher quality version"
                read -p "Enter choice (1-3): " model_choice
                
                case $model_choice in
                    1) LLAMA_MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf"
                       LLAMA_MODEL_NAME="qwen2.5-0.5b-instruct-q4_k_m.gguf" ;;
                    2) LLAMA_MODEL_URL="https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
                       LLAMA_MODEL_NAME="tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf" ;;
                    3) LLAMA_MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q8_0.gguf"
                       LLAMA_MODEL_NAME="qwen2.5-0.5b-instruct-q8_0.gguf" ;;
                    *) LLAMA_MODEL_URL="" ;;
                esac
                ;;
            2)
                echo ""
                print_info "Lightweight Models:"
                print_choice "1) Qwen2.5-1.5B-Q4_K_M (~900MB) - Good balance"
                print_choice "2) Qwen3-1.7B-Q3_K_M (~940MB) - Latest Qwen, smaller"
                print_choice "3) Qwen3-1.7B-Q4_K_M (~1.11GB) - Latest Qwen, recommended"
                print_choice "4) Qwen3-1.7B-Q4_K_S (~1.06GB) - Latest Qwen, fast"
                print_choice "5) Phi-1.5-Q4_K_M (~900MB) - Microsoft model, code-focused"
                print_choice "6) StableLM-2-1.6B-Q4_K_M (~1GB) - Stability AI model"
                read -p "Enter choice (1-6): " model_choice
                
                case $model_choice in
                    1) LLAMA_MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf"
                       LLAMA_MODEL_NAME="qwen2.5-1.5b-instruct-q4_k_m.gguf" ;;
                    2) LLAMA_MODEL_URL="https://huggingface.co/unsloth/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q3_K_M.gguf"
                       LLAMA_MODEL_NAME="Qwen3-1.7B-Q3_K_M.gguf" ;;
                    3) LLAMA_MODEL_URL="https://huggingface.co/unsloth/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q4_K_M.gguf"
                       LLAMA_MODEL_NAME="Qwen3-1.7B-Q4_K_M.gguf" ;;
                    4) LLAMA_MODEL_URL="https://huggingface.co/unsloth/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q4_K_S.gguf"
                       LLAMA_MODEL_NAME="Qwen3-1.7B-Q4_K_S.gguf" ;;
                    5) LLAMA_MODEL_URL="https://huggingface.co/TheBloke/phi-1_5-GGUF/resolve/main/phi-1_5.Q4_K_M.gguf"
                       LLAMA_MODEL_NAME="phi-1_5.Q4_K_M.gguf" ;;
                    6) LLAMA_MODEL_URL="https://huggingface.co/TheBloke/stablelm-2-1_6b-GGUF/resolve/main/stablelm-2-1_6b.Q4_K_M.gguf"
                       LLAMA_MODEL_NAME="stablelm-2-1_6b.Q4_K_M.gguf" ;;
                    *) LLAMA_MODEL_URL="" ;;
                esac
                ;;
            3)
                echo ""
                print_info "Medium Models:"
                print_choice "1) Phi-2-Q4_K_M (~1.6GB) - High quality, well-rounded"
                print_choice "2) Qwen2.5-3B-Q3_K_M (~1.4GB) - Larger Qwen, Q3 quantization"
                print_choice "3) Gemma-2B-Q4_K_M (~1.6GB) - Google's model"
                print_choice "4) StableLM-2-3B-Q4_K_M (~1.8GB) - Stability AI"
                read -p "Enter choice (1-4): " model_choice
                
                case $model_choice in
                    1) LLAMA_MODEL_URL="https://huggingface.co/TheBloke/phi-2-GGUF/resolve/main/phi-2.Q4_K_M.gguf"
                       LLAMA_MODEL_NAME="phi-2.Q4_K_M.gguf" ;;
                    2) LLAMA_MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q3_k_m.gguf"
                       LLAMA_MODEL_NAME="qwen2.5-3b-instruct-q3_k_m.gguf" ;;
                    3) LLAMA_MODEL_URL="https://huggingface.co/lmstudio-community/gemma-2b-it-GGUF/resolve/main/gemma-2b-it-Q4_K_M.gguf"
                       LLAMA_MODEL_NAME="gemma-2b-it-Q4_K_M.gguf" ;;
                    4) LLAMA_MODEL_URL="https://huggingface.co/second-state/stablelm-2-zephyr-1.6b-GGUF/resolve/main/stablelm-2-zephyr-1_6b-Q4_K_M.gguf"
                       LLAMA_MODEL_NAME="stablelm-2-zephyr-1_6b-Q4_K_M.gguf" ;;
                    *) LLAMA_MODEL_URL="" ;;
                esac
                ;;
            4)
                echo ""
                print_info "Large Models (Pi 5 8GB only):"
                print_choice "1) Qwen2.5-3B-Q4_K_M (~2GB) - High quality Qwen"
                print_choice "2) Mistral-7B-Q3_K_S (~3GB) - Popular, good quality"
                print_choice "3) Llama-3.2-3B-Q4_K_M (~2GB) - Meta's latest small model"
                print_choice "4) Phi-3-Mini-Q4_K_M (~2.4GB) - Microsoft's latest"
                print_choice "5) Gemma-2-2B-Q4_K_M (~1.6GB) - Google's improved model"
                read -p "Enter choice (1-5): " model_choice
                
                case $model_choice in
                    1) LLAMA_MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf"
                       LLAMA_MODEL_NAME="qwen2.5-3b-instruct-q4_k_m.gguf" ;;
                    2) LLAMA_MODEL_URL="https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.2-GGUF/resolve/main/mistral-7b-instruct-v0.2.Q3_K_S.gguf"
                       LLAMA_MODEL_NAME="mistral-7b-instruct-v0.2.Q3_K_S.gguf" ;;
                    3) LLAMA_MODEL_URL="https://huggingface.co/lmstudio-community/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf"
                       LLAMA_MODEL_NAME="Llama-3.2-3B-Instruct-Q4_K_M.gguf" ;;
                    4) LLAMA_MODEL_URL="https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf"
                       LLAMA_MODEL_NAME="Phi-3-mini-4k-instruct-q4.gguf" ;;
                    5) LLAMA_MODEL_URL="https://huggingface.co/lmstudio-community/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf"
                       LLAMA_MODEL_NAME="gemma-2-2b-it-Q4_K_M.gguf" ;;
                    *) LLAMA_MODEL_URL="" ;;
                esac
                ;;
            5)
                LLAMA_MODEL_URL=""
                ;;
            *)
                print_error "Invalid choice"
                exit 1
                ;;
        esac
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

print_info "LLM Backend: $LLM_SERVER"
if [ -n "$USE_LOCAL_LLM" ]; then
    print_info "Local LLM: $USE_LOCAL_LLM"
fi
echo ""

# ============================================================================
# TTS (Text-to-Speech) Selection
# ============================================================================
print_header "Step 3: Select TTS (Text-to-Speech) Backend"
echo "Choose how you want the AI to speak:"
echo ""
print_choice "1) Cloud Services (Recommended for beginners)"
print_choice "   - OpenAI TTS (high quality, natural voices)"
print_choice "   - Google Gemini TTS (free tier available)"
print_choice "   - ByteDance VolcEngine (China region)"
print_choice "   - Tencent Cloud (China region)"
echo ""
print_choice "2) Local - Piper TTS (FREE, fast and efficient)"
print_choice "   - Lightweight, works on all Pi models"
print_choice "   - Good quality, fast synthesis"
print_choice "   - Best for resource-constrained devices"
echo ""
print_choice "3) Local - Coqui TTS (FREE, highest quality)"
print_choice "   - Multiple speakers and languages"
print_choice "   - Natural-sounding voices"
print_choice "   - Recommended for Pi 5 (more resource-intensive)"
echo ""

read -p "Enter your choice (1-3): " tts_choice

case $tts_choice in
    1)
        echo ""
        print_info "Select cloud TTS provider:"
        print_choice "1) OpenAI TTS"
        print_choice "2) Google Gemini"
        print_choice "3) ByteDance VolcEngine"
        print_choice "4) Tencent Cloud"
        read -p "Enter provider (1-4): " cloud_tts
        
        case $cloud_tts in
            1) TTS_SERVER="OPENAI" ;;
            2) TTS_SERVER="GEMINI" ;;
            3) TTS_SERVER="VOLCENGINE" ;;
            4) TTS_SERVER="TENCENT" ;;
            *) print_error "Invalid choice"; exit 1 ;;
        esac
        ;;
    2)
        TTS_SERVER="PIPER"
        INSTALL_PIPER=true
        print_warn "You'll need to download Piper binary and voice models separately"
        print_info "Visit: https://github.com/OHF-Voice/piper1-gpl"
        ;;
    3)
        TTS_SERVER="COQUI"
        INSTALL_COQUI=true
        
        echo ""
        print_info "Select Coqui TTS model:"
        print_choice "1) Tacotron2-DDC (balanced quality/speed)"
        print_choice "2) Glow-TTS (faster inference)"
        print_choice "3) VITS multi-speaker (109 voices!)"
        print_choice "4) YourTTS multi-lingual"
        read -p "Enter choice (1-4): " coqui_model
        
        case $coqui_model in
            1) COQUI_MODEL="tts_models/en/ljspeech/tacotron2-DDC" ;;
            2) COQUI_MODEL="tts_models/en/ljspeech/glow-tts" ;;
            3) COQUI_MODEL="tts_models/en/vctk/vits"
               echo ""
               read -p "Enter speaker ID (e.g., p225, p226) or press Enter for default: " COQUI_SPEAKER
               ;;
            4) COQUI_MODEL="tts_models/multilingual/multi-dataset/your_tts"
               echo ""
               read -p "Enter language code (e.g., en, es, fr) or press Enter for default: " COQUI_LANGUAGE
               ;;
            *) COQUI_MODEL="tts_models/en/ljspeech/tacotron2-DDC" ;;
        esac
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

print_info "TTS Backend: $TTS_SERVER"
echo ""

# ============================================================================
# API Keys Collection (if cloud services selected)
# ============================================================================
NEED_API_KEYS=false

if [[ "$ASR_SERVER" == "OPENAI" ]] || [[ "$LLM_SERVER" == "OPENAI" && -z "$USE_LOCAL_LLM" ]] || [[ "$TTS_SERVER" == "OPENAI" ]]; then
    NEED_API_KEYS=true
    print_header "OpenAI API Configuration"
    read -p "Enter your OpenAI API key: " OPENAI_API_KEY
    echo ""
fi

if [[ "$ASR_SERVER" == "GEMINI" ]] || [[ "$LLM_SERVER" == "GEMINI" ]] || [[ "$TTS_SERVER" == "GEMINI" ]]; then
    NEED_API_KEYS=true
    print_header "Google Gemini API Configuration"
    read -p "Enter your Gemini API key: " GEMINI_API_KEY
    echo ""
fi

if [[ "$ASR_SERVER" == "VOLCENGINE" ]] || [[ "$TTS_SERVER" == "VOLCENGINE" ]]; then
    NEED_API_KEYS=true
    print_header "ByteDance VolcEngine Configuration"
    read -p "Enter your VolcEngine access token: " VOLCENGINE_ACCESS_TOKEN
    echo ""
fi

if [[ "$LLM_SERVER" == "VOLCENGINE" ]]; then
    NEED_API_KEYS=true
    print_header "ByteDance Doubao Configuration"
    read -p "Enter your Doubao access token: " VOLCENGINE_DOUBAO_ACCESS_TOKEN
    echo ""
fi

if [[ "$ASR_SERVER" == "TENCENT" ]] || [[ "$TTS_SERVER" == "TENCENT" ]]; then
    NEED_API_KEYS=true
    print_header "Tencent Cloud Configuration"
    read -p "Enter your Tencent Secret ID: " TENCENT_SECRET_ID
    read -p "Enter your Tencent Secret Key: " TENCENT_SECRET_KEY
    echo ""
fi

# ============================================================================
# Generate .env file
# ============================================================================
print_header "Generating .env Configuration"

cat > "$ENV_FILE" << EOF
# Whisplay AI Chatbot Configuration
# Generated by setup script on $(date)

# Backend Selection
ASR_SERVER=$ASR_SERVER
LLM_SERVER=$LLM_SERVER
TTS_SERVER=$TTS_SERVER

# Chat Settings
CHAT_HISTORY_RESET_TIME=300
ENABLE_THINKING=true

EOF

# Add API keys if cloud services are used
if [ "$NEED_API_KEYS" = true ]; then
    cat >> "$ENV_FILE" << EOF
# API Keys
EOF
    
    if [ -n "$OPENAI_API_KEY" ]; then
        cat >> "$ENV_FILE" << EOF
OPENAI_API_KEY=$OPENAI_API_KEY
EOF
    fi
    
    if [ -n "$GEMINI_API_KEY" ]; then
        cat >> "$ENV_FILE" << EOF
GEMINI_API_KEY=$GEMINI_API_KEY
EOF
    fi
    
    if [ -n "$VOLCENGINE_ACCESS_TOKEN" ]; then
        cat >> "$ENV_FILE" << EOF
VOLCENGINE_ACCESS_TOKEN=$VOLCENGINE_ACCESS_TOKEN
EOF
    fi
    
    if [ -n "$VOLCENGINE_DOUBAO_ACCESS_TOKEN" ]; then
        cat >> "$ENV_FILE" << EOF
VOLCENGINE_DOUBAO_ACCESS_TOKEN=$VOLCENGINE_DOUBAO_ACCESS_TOKEN
EOF
    fi
    
    if [ -n "$TENCENT_SECRET_ID" ]; then
        cat >> "$ENV_FILE" << EOF
TENCENT_SECRET_ID=$TENCENT_SECRET_ID
TENCENT_SECRET_KEY=$TENCENT_SECRET_KEY
EOF
    fi
    
    echo "" >> "$ENV_FILE"
fi

# Add local LLM configuration
if [ "$USE_LOCAL_LLM" = "vllm" ]; then
    cat >> "$ENV_FILE" << EOF
# vLLM Configuration
OPENAI_API_BASE_URL=http://localhost:8000/v1
OPENAI_API_KEY=token-abc123
SERVE_VLLM=true
VLLM_HOST=0.0.0.0
VLLM_PORT=8000
VLLM_MAX_MODEL_LEN=2048

EOF
fi

if [ "$USE_LOCAL_LLM" = "llama.cpp" ]; then
    cat >> "$ENV_FILE" << EOF
# llama.cpp Configuration
OPENAI_API_BASE_URL=http://localhost:8080/v1
OPENAI_API_KEY=token-abc123
LLAMA_CPP_HOST=127.0.0.1
LLAMA_CPP_PORT=8080
LLAMA_CPP_CONTEXT_SIZE=2048
LLAMA_CPP_THREADS=4

EOF
fi

# Add ASR configuration
if [ "$ASR_SERVER" = "WHISPER" ]; then
    cat >> "$ENV_FILE" << EOF
# Whisper (faster-whisper) Configuration
WHISPER_MODEL_SIZE=$WHISPER_MODEL_SIZE
WHISPER_DEVICE=cpu
WHISPER_COMPUTE_TYPE=int8

EOF
fi

# Add TTS configuration
if [ "$TTS_SERVER" = "COQUI" ]; then
    cat >> "$ENV_FILE" << EOF
# Coqui TTS Configuration
COQUI_TTS_MODEL=$COQUI_MODEL
EOF
    if [ -n "$COQUI_SPEAKER" ]; then
        echo "COQUI_TTS_SPEAKER=$COQUI_SPEAKER" >> "$ENV_FILE"
    fi
    if [ -n "$COQUI_LANGUAGE" ]; then
        echo "COQUI_TTS_LANGUAGE=$COQUI_LANGUAGE" >> "$ENV_FILE"
    fi
    echo "" >> "$ENV_FILE"
fi

print_info "Configuration file created: $ENV_FILE"
echo ""

# ============================================================================
# Installation Phase
# ============================================================================
print_header "Installing Selected Backends"

# Install faster-whisper
if [ "$INSTALL_FASTER_WHISPER" = true ]; then
    print_info "Installing faster-whisper..."
    pip3 install faster-whisper --break-system-packages || {
        print_error "Failed to install faster-whisper"
        exit 1
    }
    print_info "✓ faster-whisper installed successfully"
    echo ""
fi

# Install vLLM
if [ "$INSTALL_VLLM" = true ]; then
    print_info "Installing vLLM (this may take 20-40 minutes)..."
    if [ -f "$SCRIPT_DIR/install_vllm.sh" ]; then
        bash "$SCRIPT_DIR/install_vllm.sh"
        
        # Download model if specified
        if [ -n "$VLLM_MODEL" ]; then
            print_info "Downloading vLLM model: $VLLM_MODEL"
            source ~/vllm-env/bin/activate
            mkdir -p ~/models
            huggingface-cli download "$VLLM_MODEL" --local-dir ~/models/$(basename "$VLLM_MODEL")
            echo "VLLM_MODEL_PATH=~/models/$(basename "$VLLM_MODEL")" >> "$ENV_FILE"
        fi
    else
        print_error "install_vllm.sh not found!"
    fi
    echo ""
fi

# Install llama.cpp
if [ "$INSTALL_LLAMA_CPP" = true ]; then
    print_info "Installing llama.cpp (this may take 10-30 minutes)..."
    if [ -f "$SCRIPT_DIR/install_llama_cpp.sh" ]; then
        bash "$SCRIPT_DIR/install_llama_cpp.sh"
        
        # Download model if specified
        if [ -n "$LLAMA_MODEL_URL" ]; then
            print_info "Downloading model: $LLAMA_MODEL_NAME"
            mkdir -p "$SCRIPT_DIR/models"
            wget "$LLAMA_MODEL_URL" -O "$SCRIPT_DIR/models/$LLAMA_MODEL_NAME"
            echo "LLAMA_CPP_MODEL_PATH=$SCRIPT_DIR/models/$LLAMA_MODEL_NAME" >> "$ENV_FILE"
        fi
    else
        print_error "install_llama_cpp.sh not found!"
    fi
    echo ""
fi

# Install Coqui TTS
if [ "$INSTALL_COQUI" = true ]; then
    print_info "Installing Coqui TTS..."
    pip3 install TTS --break-system-packages || {
        print_error "Failed to install Coqui TTS"
        exit 1
    }
    print_info "✓ Coqui TTS installed successfully"
    echo ""
fi

# ============================================================================
# Summary
# ============================================================================
print_header "Setup Complete!"

echo -e "${BOLD}Configuration Summary:${NC}"
echo -e "  ASR (Speech Recognition): ${GREEN}$ASR_SERVER${NC}"
echo -e "  LLM (AI Brain): ${GREEN}$LLM_SERVER${NC}"
if [ -n "$USE_LOCAL_LLM" ]; then
    echo -e "    Local LLM Engine: ${GREEN}$USE_LOCAL_LLM${NC}"
fi
echo -e "  TTS (Voice Output): ${GREEN}$TTS_SERVER${NC}"
echo ""

echo -e "${BOLD}Next Steps:${NC}"
echo ""

if [ "$USE_LOCAL_LLM" = "vllm" ]; then
    echo -e "${CYAN}1. Start vLLM server:${NC}"
    echo "   bash run_vllm.sh"
    echo ""
fi

if [ "$USE_LOCAL_LLM" = "llama.cpp" ]; then
    echo -e "${CYAN}1. Start llama.cpp server:${NC}"
    echo "   bash run_llama_cpp.sh"
    echo ""
fi

echo -e "${CYAN}2. Build the project:${NC}"
echo "   bash build.sh"
echo ""

echo -e "${CYAN}3. Start the chatbot:${NC}"
echo "   bash run_chatbot.sh"
echo ""

echo -e "${CYAN}4. (Optional) Enable auto-start on boot:${NC}"
echo "   sudo bash startup.sh"
echo ""

print_info "Your configuration has been saved to: $ENV_FILE"
print_info "You can edit this file later to make changes"
echo ""

print_header "Happy Chatting! 🤖"
