# Translation Mode Implementation Guide

## Overview

Translation Mode enables real-time, speaker-aware conversation translation on the Whisplay AI Chatbot. When activated, the system automatically identifies different speakers, transcribes their speech segments, and provides labeled translations maintaining speaker identity.

## Features Implemented

### 1. Voice-Activated Mode Switching

**Activation Phrases:**
- "translate mode"
- "translation mode"  
- "activate translate mode"
- "enable translate mode"
- "turn on translate mode"

**Deactivation Phrases:**
- "normal mode"
- "chat mode"
- "disable translate mode"
- "deactivate translate mode"
- "turn off translate mode"

**Visual Feedback:**
- **Translate Mode Active**: Purple LED (#ff00ff) + 🌍 emoji
- **Normal Mode**: Blue LED (#000055) + 😴 emoji

### 2. Complete Translation Workflow

```
┌─────────────────┐
│  Button Press   │
│  (Record Audio) │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Speaker        │
│  Diarization    │  ← Identifies speakers & timestamps
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Extract Audio  │
│  Segments       │  ← Splits audio by speaker
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  ASR per        │
│  Speaker        │  ← Transcribes each segment
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Format with    │
│  Speaker Labels │  ← "[Speaker 0]: Hello"
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  LLM            │
│  Translation    │  ← Uses translateModePrompt
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  TTS Output     │
│  with Labels    │  ← "Speaker 0 says: Hola"
└─────────────────┘
```

### 3. Speaker Diarization System

**Technologies:**
- **VAD (Voice Activity Detection)**: WebRTC VAD for speech segment detection
- **Speaker Embeddings**: Resemblyzer for voice fingerprinting
- **Clustering**: HDBSCAN (density-based) or Spectral clustering
- **Audio Processing**: Sox for segment extraction

**Output Format:**
```json
{
  "segments": [
    {"speaker_id": 0, "start_time": 0.0, "end_time": 3.5},
    {"speaker_id": 1, "start_time": 3.5, "end_time": 7.2},
    {"speaker_id": 0, "start_time": 7.2, "end_time": 10.0}
  ],
  "num_speakers": 2
}
```

### 4. Specialized Translation Prompt

The `translateModePrompt` instructs the LLM to:
1. Translate accurately while preserving meaning, tone, and intent
2. Maintain speaker identity in output
3. Be concise without meta-commentary
4. Preserve conversational context
5. Automatically detect languages

**Example Input:**
```
[Speaker 0]: Hello, how are you?
[Speaker 1]: Hola, ¿cómo estás?
```

**Example Output:**
```
Speaker 0 says: Hola, ¿cómo estás?
Speaker 1 says: Hello, how are you?
```

## File Structure

### Core Implementation Files

```
src/
├── config/
│   └── llm-config.ts          # System prompts (normal + translate mode)
├── cloud-api/
│   ├── server.ts              # translateWithDiarization() function
│   └── diarization.ts         # Python wrapper for speaker diarization
├── core/
│   └── ChatFlow.ts            # Flow control with translate mode routing
└── python/
    ├── speaker_diarization.py # Main diarization script
    └── diarization/
        ├── vad.py             # Voice Activity Detection
        ├── embeddings.py      # Speaker embedding extraction
        └── clustering.py      # Speaker clustering algorithms
```

### Key Functions

#### `translateWithDiarization()` in `src/cloud-api/server.ts`

```typescript
export const translateWithDiarization = async (
  audioFilePath: string,
  onPartial: (text: string) => void,
  onEnd: () => void,
  onThinking?: (thinking: string) => void
): Promise<void>
```

**Steps:**
1. Run speaker diarization on audio file
2. Extract each speaker's segments using sox
3. Run ASR on each segment individually
4. Format transcriptions with speaker labels
5. Send to LLM with translate mode prompt
6. Stream translated output back with speaker labels

#### Flow Routing in `ChatFlow.ts`

```typescript
// After ASR completes
if (this.translateMode) {
  this.setCurrentFlow("translate");  // → translateWithDiarization()
} else {
  this.setCurrentFlow("answer");     // → normal chat
}
```

## Usage Instructions

### On Device

1. **Activate Translate Mode:**
   - Press button
   - Say "translate mode"
   - Wait for purple LED and 🌍 emoji

2. **Record Conversation:**
   - Press and hold button
   - Speakers converse (multiple languages)
   - Release button when done

3. **Receive Translation:**
   - System processes audio with diarization
   - Displays "Translating..." with 🌐 emoji
   - Outputs speaker-labeled translations via TTS

4. **Deactivate:**
   - Press button
   - Say "normal mode"
   - Returns to regular chat mode

### Example Conversation Flow

**Recording:**
- Speaker 0: "Hello, my name is John. Nice to meet you."
- Speaker 1: "Bonjour, je m'appelle Marie. Enchanté."

**System Processing:**
```
[DIARIZATION] Found 2 speakers, 2 segments
[TRANSLATE] Speaker 0: "Hello, my name is John. Nice to meet you."
[TRANSLATE] Speaker 1: "Bonjour, je m'appelle Marie. Enchanté."
```

**Output (via TTS):**
```
Speaker 0 says: Bonjour, je m'appelle John. Ravi de vous rencontrer.
Speaker 1 says: Hello, my name is Marie. Pleased to meet you.
```

## Configuration

### Environment Variables

```bash
# Custom translation prompt (optional)
TRANSLATE_MODE_PROMPT="Your custom prompt here..."

# Python path (if needed)
PYTHON_PATH=/usr/bin/python3

# Enable thinking display (optional)
ENABLE_THINKING=false
```

### Diarization Parameters

Edit `python/speaker_diarization.py` to adjust:
- `--num-speakers`: Force specific number of speakers
- `--min-speakers`: Minimum speakers to detect (default: 1)
- `--max-speakers`: Maximum speakers to detect (default: 10)
- `--clustering-method`: "hdbscan" or "spectral" (default: "hdbscan")

## Troubleshooting

### Common Issues

**Issue: Diarization fails or detects wrong number of speakers**
- **Solution**: Audio may be too short or have overlapping speech. Try clearer recordings with less overlap.
- **Alternative**: Use `--num-speakers N` flag to force specific speaker count

**Issue: Translation output doesn't maintain speaker labels**
- **Solution**: Check that `translateModePrompt` is properly loaded. Verify with logs showing system prompt being used.

**Issue: Sox "command not found" error**
- **Solution**: Install sox:
  ```bash
  sudo apt install sox
  ```

**Issue: Python dependencies missing**
- **Solution**: Reinstall requirements:
  ```bash
  cd python
  pip install -r requirements.txt
  ```

**Issue: Translate mode doesn't activate**
- **Solution**: Ensure exact phrase matching. Say clearly: "translate mode" (not "activate translation" or "turn on translator")

### Debug Logging

Enable verbose logging in `src/cloud-api/server.ts`:
```typescript
console.log("[TRANSLATE] Starting diarization...");
console.log("[TRANSLATE] Found N speakers, M segments");
console.log("[TRANSLATE] Speaker X: <transcript>");
console.log("[TRANSLATE] Formatted input:\n<formatted>");
```

View logs:
```bash
journalctl -u whisplay-chatbot -f
```

## Performance Considerations

### Processing Time

Typical processing timeline for 30-second audio:
- Diarization: ~5-10 seconds
- Segment extraction: ~1-2 seconds
- ASR per segment: ~2-3 seconds per segment
- LLM translation: ~3-5 seconds
- **Total**: ~15-25 seconds for 2-speaker conversation

### Optimization Tips

1. **Reduce Audio Length**: Shorter recordings = faster processing
2. **Use Local ASR**: Vosk/Whisper faster than cloud APIs
3. **Limit Max Speakers**: Set `--max-speakers 2` if only 2 people expected
4. **GPU Acceleration**: For Whisper ASR, enable CUDA if available

## Future Enhancements

### Planned Improvements
- [ ] Color-coded LED indicators per speaker (Speaker 0: Blue, Speaker 1: Green, etc.)
- [ ] Real-time streaming translation (process while recording)
- [ ] Persistent speaker profiles (recognize same speaker across sessions)
- [ ] Custom speaker naming ("John" instead of "Speaker 0")
- [ ] Support for 3+ speakers with better visualization

### Under Consideration
- Emotion detection in translations
- Language detection without explicit instruction
- Simultaneous interpretation mode (overlapping speech)
- Translation history log with playback

## Testing

### Manual Testing

```bash
# Test diarization standalone
cd python
python3 speaker_diarization.py test_audio.wav --output-json

# Test with known number of speakers
python3 speaker_diarization.py conversation.wav --num-speakers 2 --output-json

# Test segment extraction
sox input.wav output.wav trim 0.0 5.0
```

### Integration Testing

1. Record test audio with 2 distinct speakers
2. Activate translate mode via voice command
3. Record and release
4. Verify purple LED during processing
5. Confirm speaker-labeled output in TTS

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Whisplay Device                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────┐         ┌──────────────┐            │
│  │   Button     │────────▶│   Display    │            │
│  │   Handler    │         │   (LCD/LED)  │            │
│  └──────────────┘         └──────────────┘            │
│         │                                              │
│         ▼                                              │
│  ┌──────────────────────────────────────┐            │
│  │         ChatFlow.ts                  │            │
│  │  ┌────────────────────────────────┐  │            │
│  │  │ Voice Command Detection        │  │            │
│  │  │  - "translate mode"            │  │            │
│  │  │  - "normal mode"               │  │            │
│  │  └────────────┬───────────────────┘  │            │
│  │               │                       │            │
│  │               ▼                       │            │
│  │  ┌────────────────────────────────┐  │            │
│  │  │ Flow Router                    │  │            │
│  │  │  if (translateMode)            │  │            │
│  │  │    → "translate"               │  │            │
│  │  │  else                          │  │            │
│  │  │    → "answer"                  │  │            │
│  │  └────────────┬───────────────────┘  │            │
│  └───────────────┼──────────────────────┘            │
│                  │                                     │
│                  ▼                                     │
│  ┌─────────────────────────────────────────────────┐ │
│  │           server.ts                             │ │
│  │  ┌─────────────────────────────────────────┐   │ │
│  │  │  translateWithDiarization()             │   │ │
│  │  │                                         │   │ │
│  │  │  1. diarizeAudio(audioPath)            │   │ │
│  │  │     └─▶ Python subprocess              │   │ │
│  │  │                                         │   │ │
│  │  │  2. extractAudioSegment() for each     │   │ │
│  │  │     └─▶ sox subprocess                 │   │ │
│  │  │                                         │   │ │
│  │  │  3. recognizeAudio() per segment       │   │ │
│  │  │     └─▶ ASR API                        │   │ │
│  │  │                                         │   │ │
│  │  │  4. Format: "[Speaker N]: text"        │   │ │
│  │  │                                         │   │ │
│  │  │  5. chatWithLLMStream()                │   │ │
│  │  │     └─▶ LLM with translateModePrompt   │   │ │
│  │  │                                         │   │ │
│  │  │  6. Stream to TTS                      │   │ │
│  │  └─────────────────────────────────────────┘   │ │
│  └─────────────────────────────────────────────────┘ │
│                                                       │
└───────────────────────────────────────────────────────┘

External Components:
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  Python      │  │     ASR      │  │     LLM      │
│  Diarization │  │   Service    │  │   Service    │
│   (Subprocess)│  │ (API/Local) │  │ (API/Local)  │
└──────────────┘  └──────────────┘  └──────────────┘
```

## Credits

**Implementation**: November 2024
**Dependencies**: Resemblyzer, HDBSCAN, WebRTC VAD, Sox, scikit-learn
**Inspired by**: Professional simultaneous interpretation systems

## License

Same as main project license.
