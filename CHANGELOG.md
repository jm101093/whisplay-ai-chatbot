# Changelog

All notable changes and new features for the Whisplay AI Chatbot project.

## [Unreleased]

### Added - Translation Mode with Speaker Diarization

#### Voice-Activated Translation Mode (November 2024)
- **Voice Command Activation**: Say "translate mode" to activate, "normal mode" to deactivate
- **Visual Indicators**: Purple LED (#ff00ff) + 🌍 emoji when translation mode is active
- **Persistent Mode**: Translation mode stays active between button presses until explicitly deactivated
- **Exact Phrase Matching**: Uses precise phrase detection to prevent false activations

#### Speaker Diarization System (November 2024)
- **Multi-Speaker Detection**: Automatically identifies different speakers in conversations
- **VAD-Based Segmentation**: Uses Voice Activity Detection to isolate speech segments
- **Speaker Embeddings**: Utilizes Resemblyzer for voice fingerprinting
- **Clustering**: Supports both HDBSCAN and Spectral clustering algorithms
- **JSON Output**: Structured output with speaker IDs, timestamps, and segment boundaries
- **TypeScript Integration**: Node.js wrapper for seamless Python script execution

#### LLM Configuration Improvements (November 2024)
- **Anti-Reasoning Prompt**: Updated system prompt to prevent LLM from exposing internal reasoning
- **Translation Capability**: Enhanced multilingual support with translation-focused instructions
- **Cleaner Responses**: Eliminated verbose chain-of-thought output in user-facing responses

### Technical Improvements

#### Python Components
- `python/speaker_diarization.py`: Main diarization pipeline with CLI interface
- `python/diarization/vad.py`: Voice Activity Detection using WebRTC VAD
- `python/diarization/embeddings.py`: Speaker embedding extraction with Resemblyzer
- `python/diarization/clustering.py`: Speaker clustering with HDBSCAN/Spectral algorithms
- `--output-json` flag for programmatic integration

#### TypeScript Components
- `src/cloud-api/diarization.ts`: Async wrapper for Python diarization subprocess
- `src/core/ChatFlow.ts`: Voice command detection for translate mode activation
- `src/config/llm-config.ts`: Enhanced system prompt for translation and reasoning control

### Dependencies Added
- `resemblyzer`: Voice embedding extraction
- `hdbscan`: Density-based clustering
- `scikit-learn`: Spectral clustering and machine learning utilities
- `webrtcvad`: Voice Activity Detection
- `pydub`: Audio manipulation and segment extraction
- `sox`: Command-line audio processing (via subprocess)

### Known Issues
- Translate mode workflow not yet integrated with diarization pipeline
- Speaker-aware TTS output pending implementation
- Multi-speaker UI indicators not yet implemented

## Future Roadmap

### Planned Features
- [ ] Complete translate mode workflow integration (diarization → ASR → translation → TTS)
- [ ] Speaker-labeled TTS output with different voices per speaker
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
