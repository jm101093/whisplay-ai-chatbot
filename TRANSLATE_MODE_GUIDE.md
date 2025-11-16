# Translate Mode Guide

## How to Activate Translate Mode

### Via Voice Command (Current Implementation)

1. **Press and hold** the button
2. **Say one of these phrases:**
   - "Translate mode"
   - "Translation mode"
   - "Activate translate"
   - "Enable translate"
3. **Release** the button
4. The display will show:
   - 🌍 Globe emoji
   - Purple LED (#ff00ff)
   - "Translate Mode Active"

### Deactivating Translate Mode

1. **Press and hold** the button
2. **Say one of these phrases:**
   - "Normal mode"
   - "Chat mode"
   - "Disable translate"
   - "Deactivate translate"
3. **Release** the button
4. Returns to normal chat mode with 😴 emoji and blue LED

## Visual Indicators

| Mode | LED Color | Emoji | Status Text |
|------|-----------|-------|-------------|
| Normal Sleep | Blue (#000055) | 😴 | "Press the button to start" |
| Translate Sleep | Purple (#ff00ff) | 🌍 | "Translate Mode\nPress to record" |
| Listening | Green (#00ff00) | 😐 | "Listening..." |
| Processing | Yellow (#ff6800) | - | - |
| Answering | Blue (#0000ff) | 😊 | [Response text] |

## How Translate Mode Works (Once Fully Implemented)

### Current Status: Voice activation ✅ | Diarization processing ⏳

When translate mode is active and you press the button:

1. **Record Conversation**: Multiple speakers talking
2. **Speaker Diarization**: System identifies who spoke when
3. **Speech Recognition**: Transcribes each speaker separately
4. **Translation**: LLM translates maintaining speaker context
5. **Text-to-Speech**: Outputs with speaker labels
   - "Speaker 1 says: Hello, how are you?"
   - "Speaker 2 says: I'm doing well, thanks!"

### LED Colors During Translation (Planned)
- Speaker 0: Blue (#0000ff)
- Speaker 1: Green (#00ff00)
- Speaker 2: Red (#ff0000)
- Uncertain: Orange (#ff6800)

## Troubleshooting

### "Translate mode not activating"
- Speak clearly and close to the device
- Make sure you say the exact phrase
- Check ASR logs for recognition accuracy
- Try saying just "translate mode" without extra words

### "Wrong mode activated"
- Say "normal mode" to reset
- Restart the chatbot service if needed

## Examples

### Activating
```
[Button Press]
User: "Translate mode"
[Button Release]
Display: 🌍 "Translate Mode Active"
```

### Using (When Fully Implemented)
```
[In Translate Mode]
[Button Press]
Person A (English): "Where is the train station?"
Person B (Spanish): "La estación de tren está a dos cuadras."
[Button Release]
System: 
  "Speaker 1 says: Where is the train station?"
  "Speaker 2 says: The train station is two blocks away."
```

### Deactivating
```
[Button Press]
User: "Normal mode"
[Button Release]
Display: 😴 "Press the button to start"
```

## Development Notes

### Completed Features
- ✅ Voice command detection for mode switching
- ✅ Visual feedback (LED color + emoji changes)
- ✅ Mode persistence across conversations
- ✅ Python diarization pipeline with JSON output
- ✅ TypeScript diarization wrapper

### Pending Features
- ⏳ Integrate diarization into translate mode flow
- ⏳ Speaker-aware ASR processing
- ⏳ Translation prompts with speaker context
- ⏳ Speaker-labeled TTS output
- ⏳ Speaker-specific LED colors during playback

### Code Locations
- Mode detection: `src/core/ChatFlow.ts` (lines ~140-175)
- Voice commands: "translate mode", "normal mode", etc.
- Display updates: Purple LED (#ff00ff) for translate mode
- Diarization: `src/cloud-api/diarization.ts`
- Python pipeline: `python/speaker_diarization.py`
