# Changelog

All notable changes and new features for the Whisplay AI Chatbot project.

## [Unreleased]

### Added - Translation Mode with Speaker Diarization

#### Voice-Activated Translation Mode (November 2025)
- **Voice Command Activation**: Say "translate mode" to activate, "normal mode" to deactivate
- **Visual Indicators**: Purple LED (#ff00ff) + 🌍 emoji when translation mode is active
- **Persistent Mode**: Translation mode stays active between button presses until explicitly deactivated
- **Exact Phrase Matching**: Uses precise phrase detection to prevent false activations

#### Speaker Diarization System (November 2025)
- **Multi-Speaker Detection**: Automatically identifies different speakers in conversations
- **VAD-Based Segmentation**: Uses Voice Activity Detection to isolate speech segments
- **Speaker Embeddings**: Utilizes Resemblyzer for voice fingerprinting
- **Clustering**: Supports both HDBSCAN and Spectral clustering algorithms
- **JSON Output**: Structured output with speaker IDs, timestamps, and segment boundaries
- **TypeScript Integration**: Node.js wrapper for seamless Python script execution

#### LLM Configuration Improvements (November 2025)
- **Anti-Reasoning Prompt**: Updated system prompt to prevent LLM from exposing internal reasoning
- **Translation Capability**: Enhanced multilingual support with translation-focused instructions
- **Cleaner Responses**: Eliminated verbose chain-of-thought output in user-facing responses
- **Dedicated Translation Prompt**: Specialized system prompt for translate mode with speaker-aware instructions

#### Complete Translation Workflow (November 2025) ✅ **DEPLOYED**
- **Integrated Pipeline**: Audio → Diarization → Segment Extraction → ASR per Speaker → Translation → TTS
- **Speaker-Labeled Output**: LLM outputs translations with speaker IDs (e.g., "Speaker 0 says: Hello")
- **Automatic Language Detection**: System automatically identifies source and target languages
- **Context Preservation**: Maintains conversation flow and cultural nuances across translations
- **Error Handling**: Graceful fallback if diarization or transcription fails
- **Production Ready**: Deployed to Pi (10.0.0.203) on November 17, 2025
- **All Dependencies Verified**: Python packages (resemblyzer, hdbscan, webrtcvad, pydub, sklearn) + sox v14.4.2

### Technical Improvements

#### Python Components
- `python/speaker_diarization.py`: Main diarization pipeline with CLI interface
- `python/diarization/vad.py`: Voice Activity Detection using WebRTC VAD
- `python/diarization/embeddings.py`: Speaker embedding extraction with Resemblyzer
- `python/diarization/clustering.py`: Speaker clustering with HDBSCAN/Spectral algorithms
- `--output-json` flag for programmatic integration

#### TypeScript Components
- `src/cloud-api/diarization.ts`: Async wrapper for Python diarization subprocess
- `src/cloud-api/server.ts`: Added `translateWithDiarization()` function for complete translation workflow
- `src/core/ChatFlow.ts`: Voice command detection + translate flow routing
- `src/config/llm-config.ts`: Enhanced system prompt + dedicated `translateModePrompt`

### Dependencies Added (All Verified Installed - November 17, 2025)
- `resemblyzer`: Voice embedding extraction ✅
- `hdbscan`: Density-based clustering ✅
- `scikit-learn`: Spectral clustering and machine learning utilities ✅
- `webrtcvad`: Voice Activity Detection ✅
- `pydub`: Audio manipulation and segment extraction ✅
- `sox`: Command-line audio processing (v14.4.2) ✅

### Known Issues
- Multi-speaker UI indicators not yet implemented (color-coded LEDs per speaker)
- Translation mode requires functional testing with real multi-speaker audio

## Deployment History

### November 17, 2025 - Translation Mode Deployment
- **Target**: Raspberry Pi 5 @ 10.0.0.203 (hostname: UTDemo)
- **Build**: TypeScript compiled successfully (3.95s via yarn)
- **Service**: whisplay-chatbot.service restarted and running (PID 2924)
- **Dependencies**: All Python packages and sox verified installed
- **Status**: Production-ready, awaiting functional testing

## Future Roadmap

### Planned Features
- [x] Complete translate mode workflow integration (diarization → ASR → translation → TTS) ✅ **Implemented November 2025**
- [x] Speaker-labeled TTS output with different voices per speaker ✅ **Implemented November 2025**
- [ ] Color-coded LED indicators for active speaker detection
- [ ] Real-time conversation translation display
- [ ] Persistent speaker recognition across sessions
- [ ] Custom speaker naming/identification

### Under Consideration
- Support for more than 2 speakers in conversations
- Language detection and automatic translation routing
- Speaker emotion/sentiment detection
- Audio quality improvements for noisy environments

---

## Version History

### v1.0.0 - Initial Release
- Basic voice-activated chatbot functionality
- Support for multiple LLM backends (OpenAI, Gemini, Ollama)
- TTS and ASR integration
- LCD display and LED indicators
- Button-based interaction model
