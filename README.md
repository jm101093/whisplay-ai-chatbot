# Whisplay-AI-Chatbot

<img src="https://docs.pisugar.com/img/whisplay_logo@4x-8.png" alt="Whisplay AI Chatbot" width="200" />

This is a pocket-sized AI chatbot device built using a Raspberry Pi Zero 2w. Just press the button, speak, and it talks back—like a futuristic walkie-talkie with a mind of its own.

Test Video Playlist:
[https://www.youtube.com/watch?v=lOVA0Gui-4Q](https://www.youtube.com/playlist?list=PLpTS9YM-tG_mW5H7Xs2EO0qvlAI-Jm1e_)

Tutorial:
[https://www.youtube.com/watch?v=Nwu2DruSuyI](https://www.youtube.com/watch?v=Nwu2DruSuyI)

Tutorial 2 (offline version build on RPi 5B):
[https://www.youtube.com/watch?v=kFmhSTh167U](https://www.youtube.com/watch?v=kFmhSTh167U)

## Hardware

- Raspberry Pi zero 2w (or 5B for offline version)
- PiSugar Whisplay HAT (including LCD screen, on-board speaker and microphone)
- PiSugar 3 1200mAh

## Drivers

You need to firstly install the audio drivers for the Whisplay HAT. Follow the instructions in the [Whisplay HAT repository](https://github.com/PiSugar/whisplay).

## Installation Steps

### Quick Setup (Recommended)

1. Clone the repository:
   ```bash
   git clone https://github.com/PiSugar/whisplay-ai-chatbot.git
   cd whisplay-ai-chatbot
   ```

2. Install dependencies:
   ```bash
   bash install_dependencies.sh
   source ~/.bashrc
   ```
   Running `source ~/.bashrc` is necessary to load the new environment variables.

3. Run the interactive setup script:
   ```bash
   bash setup.sh
   ```
   
   The setup script will guide you through:
   - Selecting your ASR (speech recognition) backend
   - Choosing your LLM (AI brain) backend
   - Picking your TTS (voice output) backend
   - Installing the necessary components
   - Automatically generating your `.env` configuration
   
   **Example choices:**
   - **Beginner**: Cloud services (OpenAI/Gemini for everything)
   - **Privacy-focused**: Local everything (faster-whisper + llama.cpp + Piper)
   - **Best quality**: Cloud LLM + Local ASR/TTS
   - **Pi Zero/4**: faster-whisper (tiny) + llama.cpp (Qwen 0.5B) + Piper
   - **Pi 5**: faster-whisper (base) + vLLM (Qwen 1.5B) + Coqui TTS

4. Build the project:
   ```bash
   bash build.sh
   ```

5. Start the chatbot:
   ```bash
   bash run_chatbot.sh
   ```

6. (Optional) Enable auto-start on boot:
   ```bash
   sudo bash startup.sh
   ```
   Note: This will disable the graphical interface and set the system to multi-user mode.
   View logs with: `tail -f chatbot.log`

### Manual Setup (Advanced)

If you prefer to configure manually:

1. Follow steps 1-2 above
2. Create a `.env` file based on `.env.template` and fill in your settings
3. Manually install backends as needed:
   - vLLM: `bash install_vllm.sh`
   - llama.cpp: `bash install_llama_cpp.sh`
   - faster-whisper: `pip install faster-whisper --break-system-packages`
   - Coqui TTS: `pip install TTS --break-system-packages`
4. Continue with steps 4-6 above

## Build After Code Changes

If you make changes to the node code or just pull the new code from this repository, you need to rebuild the project. You can do this by running:

```bash
bash build.sh
```

If there's new third-party libraries to the python code, make sure to install them in global environment with `--break-system-packages`.
```
cd python
pip install -r requirements.txt --break-system-packages
```

## Update Environment Variables

If you need to update the environment variables, you can edit the `.env` file directly. After making changes, please restart the chatbot service with:

```bash
systemctl restart whisplay-ai-chatbot.service
```

## Image Generation

Enable image generation by setting the `IMAGE_GENERATION_SERVER` variable in the `.env` file. Options include: OPENAI, GEMINI, VOLCENGINE.

Then you can use prompts like "A children's book drawing of a veterinarian using a stethoscope to listen to the heartbeat of a baby otter." to generate images.

The generated images will be displayed on the screen and saved in the `data/images` folder.

## Display Battery Level

The battery level display depends on the pisugar-power-manager. If you are using PiSugar2 or PiSugar3, you need to install the pisugar-power-manager first. You can find the installation instructions in the [PiSugar Power Manager repository](https://github.com/PiSugar/pisugar-power-manager-rs).

Or use the following command to install it:

```bash
wget https://cdn.pisugar.com/release/pisugar-power-manager.sh
bash pisugar-power-manager.sh -c release
```

## Local LLM with vLLM

vLLM provides an OpenAI-compatible API for running local LLM models with optimized performance. This is especially useful for offline operation or privacy-focused deployments.

### Installation

Run the installation script (optimized for ARM/aarch64):

```bash
bash install_vllm.sh
```

This will:
- Install system dependencies (libnuma-dev, build tools)
- Set up a Python virtual environment at `~/vllm-env`
- Install PyTorch and vLLM from source
- Create helper scripts for activation

### Download a Model

Download a compatible model from Hugging Face. For Raspberry Pi, we recommend smaller models:

```bash
# Activate vLLM environment
source ~/vllm-env/bin/activate

# Download a small model (Qwen 0.5B - good for Pi)
huggingface-cli download Qwen/Qwen2.5-0.5B-Instruct --local-dir ~/models/qwen2.5-0.5b

# Or Phi-2 (2.7B - requires more RAM)
# huggingface-cli download microsoft/phi-2 --local-dir ~/models/phi-2
```

### Configure .env

Update your `.env` file to use vLLM:

```bash
LLM_SERVER=OPENAI
OPENAI_API_BASE_URL=http://localhost:8000/v1
OPENAI_API_KEY=token-abc123  # Can be any string for local vLLM
OPENAI_LLM_MODEL=Qwen/Qwen2.5-0.5B-Instruct

# Optional: Auto-start vLLM with chatbot
SERVE_VLLM=true
VLLM_MODEL_PATH=~/models/qwen2.5-0.5b
VLLM_MAX_MODEL_LEN=2048  # Adjust based on RAM (lower = less memory)
```

### Start vLLM Server

Manually start the server:

```bash
bash run_vllm.sh
```

Or enable auto-start by setting `SERVE_VLLM=true` in `.env`.

### Recommended Models for Raspberry Pi

- **Qwen2.5-0.5B** (~1GB RAM) - Best for Pi Zero 2W/Pi 4
- **Qwen2.5-1.5B** (~2-3GB RAM) - Good for Pi 5
- **Phi-2** (~4GB RAM) - Requires Pi 5 with 8GB
- **TinyLlama-1.1B** (~1.5GB RAM) - Alternative option

## Local LLM with llama.cpp

llama.cpp is a lighter alternative to vLLM that works well on resource-constrained devices like Raspberry Pi. It supports GGUF quantized models which require less RAM and provide faster inference on CPU.

### Installation

Run the installation script (builds from source with OpenBLAS optimization):

```bash
bash install_llama_cpp.sh
```

This will:
- Install system dependencies (build-essential, cmake, libopenblas-dev)
- Clone and build llama.cpp with ARM optimizations
- Create the server binary and convenience scripts
- Set up a models directory

### Download a GGUF Model

Download quantized GGUF models from Hugging Face. Q4_K_M quantization provides good quality with lower memory usage:

```bash
# Create models directory if not exists
mkdir -p models

# Ultra-Lightweight Models (300-700MB) - Pi Zero 2W / Pi 4
wget https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf -P models/
# wget https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf -P models/

# Lightweight Models (700MB-1.2GB) - Pi 4 / Pi 5
# wget https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf -P models/
# wget https://huggingface.co/unsloth/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q3_K_M.gguf -P models/
# wget https://huggingface.co/unsloth/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q4_K_M.gguf -P models/
# wget https://huggingface.co/unsloth/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q4_K_S.gguf -P models/

# Medium Models (1.2GB-2GB) - Pi 5 (4GB+)
# wget https://huggingface.co/TheBloke/phi-2-GGUF/resolve/main/phi-2.Q4_K_M.gguf -P models/
# wget https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q3_k_m.gguf -P models/

# Large Models (2GB-4.5GB) - Pi 5 (8GB)
# wget https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf -P models/
# wget https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.2-GGUF/resolve/main/mistral-7b-instruct-v0.2.Q3_K_S.gguf -P models/
# wget https://huggingface.co/lmstudio-community/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf -P models/
```

### Configure .env

Update your `.env` file to use llama.cpp:

```bash
LLM_SERVER=OPENAI
OPENAI_API_BASE_URL=http://localhost:8080/v1
OPENAI_API_KEY=token-abc123  # Can be any string for local llama.cpp
OPENAI_LLM_MODEL=qwen2.5  # Model name (llama.cpp ignores this)

# llama.cpp server configuration
LLAMA_CPP_MODEL_PATH=~/whisplay-ai-chatbot/models/qwen2.5-0.5b-instruct-q4_k_m.gguf
LLAMA_CPP_HOST=127.0.0.1
LLAMA_CPP_PORT=8080
LLAMA_CPP_CONTEXT_SIZE=2048  # Lower values use less RAM
LLAMA_CPP_THREADS=4  # Adjust based on CPU cores
```

### Start llama.cpp Server

Start the server manually:

```bash
bash run_llama_cpp.sh
```

The server provides an OpenAI-compatible API at `http://localhost:8080/v1/chat/completions`.

### Recommended GGUF Models for Raspberry Pi

**Ultra-Lightweight (300-700MB) - Pi Zero 2W / Pi 4:**
- **Qwen2.5-0.5B-Q4_K_M** (~350MB) - Fast, good for simple conversations
- **TinyLlama-1.1B-Q4_K_M** (~650MB) - Better quality, still efficient
- **Qwen2.5-0.5B-Q8_0** (~550MB) - Higher quality version of Qwen 0.5B

**Lightweight (700MB-1.2GB) - Pi 4 (8GB) / Pi 5:**
- **Qwen2.5-1.5B-Q4_K_M** (~900MB) - Excellent balance of quality/speed
- **Qwen3-1.7B-Q3_K_M** (~940MB) - Latest Qwen, Q3 quantization
- **Qwen3-1.7B-Q4_K_M** (~1.11GB) - Latest Qwen, Q4 recommended
- **Qwen3-1.7B-Q4_K_S** (~1.06GB) - Latest Qwen, slightly smaller/faster
- **Phi-1.5-Q4_K_M** (~900MB) - Microsoft model, good for coding
- **StableLM-2-1.6B-Q4_K_M** (~1GB) - Stability AI model

**Medium (1.2GB-2GB) - Pi 5 (4GB+):**
- **Phi-2-Q4_K_M** (~1.6GB) - High quality, well-rounded performance
- **Qwen2.5-3B-Q3_K_M** (~1.4GB) - Larger Qwen with Q3 quantization
- **Gemma-2B-Q4_K_M** (~1.6GB) - Google's capable model

**Large (2GB-4.5GB) - Pi 5 (8GB only):**
- **Qwen2.5-3B-Q4_K_M** (~2GB) - High quality Qwen
- **Llama-3.2-3B-Q4_K_M** (~2GB) - Meta's latest small model
- **Phi-3-Mini-Q4_K_M** (~2.4GB) - Microsoft's latest mini model
- **Mistral-7B-Q3_K_S** (~3GB) - Popular 7B model with aggressive quantization
- **Gemma-2-2B-Q4_K_M** (~1.6GB) - Google's improved Gemma v2

> **Note:** The setup script (`bash setup.sh`) provides an interactive menu to choose and automatically download these models!

### vLLM vs llama.cpp

**Use llama.cpp when:**
- Running on low-resource devices (Pi Zero 2W, Pi 4)
- You want quantized models (GGUF format)
- CPU-only inference is preferred
- Lower memory usage is critical

**Use vLLM when:**
- You have more RAM/GPU available (Pi 5 with 8GB+)
- You want maximum throughput
- You need advanced features like tensor parallelism

## Local TTS Options

The project supports multiple local TTS engines for offline voice synthesis.

### Piper TTS

Piper is a fast, local neural text-to-speech system optimized for Raspberry Pi.

**Installation:**
1. Download Piper binary for Raspberry Pi from: https://github.com/OHF-Voice/piper1-gpl
2. Download voice models from: https://rhasspy.github.io/piper-samples/

**Configure .env:**
```bash
TTS_SERVER=PIPER
PIPER_BINARY_PATH=/path/to/piper
PIPER_MODEL_PATH=/path/to/voice/model.onnx
```

**Recommended for:** Fast inference, low resource usage, good for Pi Zero 2W and Pi 4

### Coqui TTS

Coqui TTS is a deep learning toolkit offering high-quality, natural-sounding voices with multi-speaker and multi-lingual support.

**Installation:**
```bash
pip install TTS --break-system-packages
```

**List available models:**
```bash
python python/coqui_tts.py --list-models
```

**Configure .env:**
```bash
TTS_SERVER=COQUI
COQUI_TTS_MODEL=tts_models/en/ljspeech/tacotron2-DDC

# For multi-speaker models
# COQUI_TTS_MODEL=tts_models/en/vctk/vits
# COQUI_TTS_SPEAKER=p225

# For multi-lingual models
# COQUI_TTS_MODEL=tts_models/multilingual/multi-dataset/your_tts
# COQUI_TTS_LANGUAGE=en

# Enable GPU acceleration (requires CUDA)
# COQUI_TTS_GPU=false
```

**Recommended Models:**
- **tts_models/en/ljspeech/tacotron2-DDC** - Good quality, moderate speed
- **tts_models/en/ljspeech/glow-tts** - Faster inference
- **tts_models/en/vctk/vits** - Multi-speaker English (select with COQUI_TTS_SPEAKER)
- **tts_models/multilingual/multi-dataset/your_tts** - Multi-lingual support

**Recommended for:** High-quality voices, multi-speaker support, best on Pi 5 (models can be large)

**Piper vs Coqui TTS:**

| Feature | Piper | Coqui TTS |
|---------|-------|-----------|
| Quality | Good | Excellent |
| Speed | Very Fast | Moderate to Slow |
| Resource Usage | Low | High |
| Multi-speaker | Limited | Extensive |
| Multi-lingual | Limited | Extensive |
| Best for | Pi Zero 2W, Pi 4 | Pi 5 (8GB) |

## Data Folder

The chatbot saves conversation history and generated images in the `data` folder. It's a temporal folder and can be deleted if you want to clear the history.

## Enclosure

[Whisplay Chatbot Case](https://github.com/PiSugar/suit-cases/tree/main/pisugar3-whisplay-chatbot)

## Goals

- Integrate the tool with the API ✅
- Enable the AI assistant to adjust the volume autonomously ✅
- Reset the conversation history if there is no speech for five minutes ✅
- Support local llm server (vLLM) ✅
- Support local asr (faster-whisper/vosk) ✅
- Support local tts (piper/coqui) ✅
- Support image generation (openai/gemini/volcengine) ✅
- Refactor python render thread, better performance ✅
- Add Google Gemini API support ✅
- Add Grok API support
- RPI camera support
- Support speaker recognition

## License

[GPL-3.0](https://github.com/PiSugar/whisplay-ai-chatbot?tab=GPL-3.0-1-ov-file#readme)
