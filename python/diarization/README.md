# Speaker Diarization for Whisplay AI Chatbot

Air-gapped speaker diarization system optimized for Raspberry Pi 5. Enables multi-speaker conversations with translation capabilities - no cloud dependencies.

## Overview

The diarization pipeline identifies "who spoke when" in audio recordings, enabling:
- **Translate mode**: Real-time conversation translation with speaker identification
- **Multi-speaker conversations**: Separate transcription for each speaker
- **Meeting transcription**: Automatic speaker segmentation and labeling

## Architecture

```
Audio Input (WAV)
    ↓
Voice Activity Detection (WebRTC VAD)
    ↓
Speaker Embedding Extraction (Resemblyzer)
    ↓
Speaker Clustering (HDBSCAN/Spectral)
    ↓
Speaker-Labeled Segments
    ↓
ASR per Speaker (faster-whisper)
    ↓
Translation (LLM)
    ↓
TTS with Speaker Labels (Coqui TTS)
```

## Components

### 1. Voice Activity Detection (`vad.py`)
- **Technology**: WebRTC VAD
- **Purpose**: Detect speech regions, filter silence/noise
- **Performance**: Real-time on Pi 5 (< 0.1x)
- **Memory**: ~50MB

### 2. Speaker Embedding (`embedder.py`)
- **Technology**: Resemblyzer (256-dim voice embeddings)
- **Purpose**: Convert speech segments to speaker vectors
- **Performance**: ~1.5-2x realtime on Pi 5 @ 2600MHz
- **Memory**: ~300MB (model loaded in RAM)

### 3. Speaker Clustering (`clustering.py`)
- **Technology**: HDBSCAN (auto-detect) or Spectral (fixed count)
- **Purpose**: Group embeddings by speaker identity
- **Performance**: < 0.5s for 60s audio
- **Memory**: ~100MB

### 4. Main Pipeline (`speaker_diarization.py`)
- **Purpose**: Orchestrate complete diarization workflow
- **Input**: WAV audio file (any sample rate, mono/stereo)
- **Output**: Speaker segments with timestamps

## Installation

On your Raspberry Pi:

```bash
cd ~/whisplay-ai-chatbot
pip3 install -r python/requirements.txt
```

**Dependencies installed:**
- `webrtcvad` - Voice activity detection
- `resemblyzer` - Speaker embeddings
- `scikit-learn` - Machine learning utilities
- `hdbscan` - Density-based clustering
- `soundfile` - Audio I/O
- `scipy` - Signal processing

**First-run note**: Resemblyzer will download its pretrained model (~17MB) on first use. For fully air-gapped environments, pre-download to `~/.cache/resemblyzer/`.

## Testing Installation

Run the test script to verify everything is installed correctly:

```bash
python3 python/test_diarization.py
```

Expected output:
```
Testing diarization package imports...
  ✓ NumPy
  ✓ SciPy
  ✓ SoundFile
  ✓ WebRTC VAD
  ✓ Resemblyzer
  ✓ scikit-learn
  ✓ HDBSCAN

Testing diarization modules...
  ✓ VAD module
  ✓ Embedder module
  ✓ Clustering module
  ✓ VAD initialization
  ✓ Embedder initialization
  ✓ Clusterer initialization

✓ All tests passed! Diarization is ready to use.
```

## Usage

### Command Line

Basic usage (auto-detect speaker count):
```bash
python3 python/speaker_diarization.py conversation.wav
```

Specify number of speakers:
```bash
python3 python/speaker_diarization.py conversation.wav --num-speakers 3
```

Save RTTM output:
```bash
python3 python/speaker_diarization.py conversation.wav --output-rttm output.rttm
```

Adjust VAD sensitivity:
```bash
python3 python/speaker_diarization.py conversation.wav --vad-aggressiveness 2
```

Use spectral clustering (requires speaker count):
```bash
python3 python/speaker_diarization.py conversation.wav --num-speakers 2 --clustering-method spectral
```

### Python API

```python
from speaker_diarization import SpeakerDiarizationPipeline

# Initialize pipeline
pipeline = SpeakerDiarizationPipeline(
    vad_aggressiveness=3,
    clustering_method='hdbscan'
)

# Process audio file
segments = pipeline.process_audio_file('conversation.wav')

# Results: [(speaker_id, start_time, end_time), ...]
for speaker_id, start, end in segments:
    print(f"Speaker {speaker_id}: {start:.2f}s - {end:.2f}s")
```

### With NumPy Array

```python
import numpy as np
import soundfile as sf

# Load audio
audio, sr = sf.read('conversation.wav')

# Diarize
segments = pipeline.process_audio_array(audio, sample_rate=sr)
```

## Performance Benchmarks

**Raspberry Pi 5 @ 2600MHz:**
- 60 seconds of audio:
  - VAD: ~1s
  - Embedding extraction: ~90-120s (1.5-2x realtime)
  - Clustering: <0.5s
  - **Total: ~92-122s (1.5-2x realtime)**

**Memory usage:**
- Base: ~50MB
- With models loaded: ~400-500MB
- Peak during processing: ~600MB

**Accuracy:**
- Good separation for clear speakers (2-5 speakers)
- Best results with 1-2 minute segments
- Struggles with: overlapping speech, similar voices, background noise

## Configuration

### VAD Aggressiveness
- `0`: Least aggressive (keeps more audio, may include noise)
- `1`: Low aggressiveness
- `2`: Moderate aggressiveness
- `3`: Most aggressive (filters most noise, may cut speech) ⭐ **Recommended for Pi**

### Clustering Methods

**HDBSCAN** (default):
- ✓ Auto-detects number of speakers
- ✓ Handles noise/uncertain segments
- ✓ Better for unknown speaker count
- ✗ Slightly slower

**Spectral**:
- ✓ Faster computation
- ✓ More deterministic
- ✗ Requires known speaker count
- ✗ Less robust to noise

## Output Formats

### Python Tuples
```python
[(0, 0.0, 2.5), (1, 2.5, 5.0), (0, 5.0, 7.5)]
# (speaker_id, start_time_seconds, end_time_seconds)
```

### RTTM (Rich Transcription Time Marked)
```
SPEAKER audio 1 0.000 2.500 <NA> <NA> speaker_0 <NA> <NA>
SPEAKER audio 1 2.500 2.500 <NA> <NA> speaker_1 <NA> <NA>
SPEAKER audio 1 5.000 2.500 <NA> <NA> speaker_0 <NA> <NA>
```

## Integration with Chatbot

### Translate Mode Workflow

1. **Audio Capture**: User holds button, conversation is recorded
2. **Diarization**: Identify speaker segments
3. **ASR per Speaker**: Transcribe each speaker separately
4. **Translation**: LLM translates with speaker context
5. **TTS Output**: "Speaker 1 says: Hello. Speaker 2 says: Hola."

### TypeScript Integration (Coming Soon)

```typescript
import { diarizeAudio } from './cloud-api/diarization';

// Process recorded audio
const segments = await diarizeAudio(audioFilePath);

// Transcribe each speaker separately
for (const { speakerId, startTime, endTime } of segments) {
  const audioChunk = extractAudioSegment(audioFilePath, startTime, endTime);
  const text = await recognizeAudio(audioChunk);
  console.log(`Speaker ${speakerId}: ${text}`);
}
```

## Troubleshooting

### Model Download Fails
**Problem**: Resemblyzer can't download model  
**Solution**: Pre-download model on internet-connected machine:
```bash
python3 -c "from resemblyzer import VoiceEncoder; VoiceEncoder()"
# Copy ~/.cache/resemblyzer/ to Pi
```

### Memory Errors
**Problem**: "Out of memory" during processing  
**Solution**: 
- Process shorter audio segments (< 2 minutes)
- Close other applications
- Reduce model precision (future optimization)

### Poor Speaker Separation
**Problem**: Speakers incorrectly grouped  
**Solution**:
- Ensure speakers have distinct voices
- Reduce background noise
- Use `--num-speakers` if count is known
- Try `--clustering-method spectral --num-speakers N`

### Slow Performance
**Problem**: Processing takes too long  
**Solution**:
- Verify Pi is running at 2600MHz: `cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq`
- Check CPU governor is 'performance': `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`
- Use shorter audio segments
- Lower VAD aggressiveness (processes fewer segments)

## Technical Details

### Audio Requirements
- **Format**: WAV (or any format supported by soundfile)
- **Sample Rate**: Any (automatically resampled to 16kHz)
- **Channels**: Mono or stereo (stereo converted to mono)
- **Duration**: Best results with 30s - 2min segments

### Speaker Embedding
- **Model**: Resemblyzer (GE2E loss, trained on LibriSpeech)
- **Embedding Size**: 256 dimensions
- **Input**: 16kHz mono audio
- **Output**: L2-normalized speaker vector

### Clustering
- **HDBSCAN**: DBSCAN with hierarchy, auto-determines clusters
- **Spectral**: Eigenvalue decomposition of affinity matrix
- **Distance Metric**: Euclidean (after StandardScaler normalization)

## Offline Installation

For fully air-gapped deployment:

1. **On internet-connected machine:**
```bash
# Download all packages
pip3 download -r python/requirements.txt -d ./diarization-packages/

# Download Resemblyzer model
python3 -c "from resemblyzer import VoiceEncoder; VoiceEncoder()"
tar -czf resemblyzer-model.tar.gz ~/.cache/resemblyzer/
```

2. **Copy to Pi:**
```bash
scp -r diarization-packages/ pi@192.168.1.176:~/
scp resemblyzer-model.tar.gz pi@192.168.1.176:~/
```

3. **On Pi:**
```bash
# Install packages
pip3 install --no-index --find-links ~/diarization-packages/ -r python/requirements.txt

# Extract model
tar -xzf resemblyzer-model.tar.gz -C ~/
```

## Future Enhancements

- [ ] Real-time streaming diarization (process audio as it's recorded)
- [ ] GPU acceleration with ONNX Runtime
- [ ] Multi-language speaker embeddings
- [ ] Speaker enrollment (recognize known speakers by name)
- [ ] Overlap detection and handling
- [ ] Emotion detection per speaker
- [ ] Voice fingerprinting for access control

## Credits

- **WebRTC VAD**: Google (open-source)
- **Resemblyzer**: Corentin Jemine
- **HDBSCAN**: Leland McInnes, John Healy
- **scikit-learn**: Community-driven project

## License

This speaker diarization implementation is part of Whisplay AI Chatbot and follows the same license.
