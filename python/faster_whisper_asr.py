#!/usr/bin/env python3
"""
Faster Whisper ASR Script
Transcribes audio files using the faster-whisper library (optimized with CTranslate2)
Usage: python faster_whisper_asr.py <audio_file> [--model MODEL] [--language LANGUAGE] [--device DEVICE]
"""

import sys
import argparse
from pathlib import Path

try:
    from faster_whisper import WhisperModel
except ImportError:
    print("Error: faster-whisper is not installed. Install it with: pip install faster-whisper", file=sys.stderr)
    sys.exit(1)


def transcribe_audio(audio_path, model_size="tiny", language=None, device="cpu", compute_type="int8"):
    """
    Transcribe audio file using faster-whisper
    
    Args:
        audio_path: Path to audio file
        model_size: Model size (tiny, base, small, medium, large-v1, large-v2, large-v3)
        language: Language code (e.g., 'en', 'zh', 'ja'). None for auto-detection
        device: Device to use ('cpu', 'cuda', 'auto')
        compute_type: Computation type ('int8', 'int8_float16', 'float16')
    
    Returns:
        Transcribed text
    """
    if not Path(audio_path).exists():
        print(f"Error: Audio file not found: {audio_path}", file=sys.stderr)
        sys.exit(1)
    
    try:
        # Initialize model
        model = WhisperModel(model_size, device=device, compute_type=compute_type)
        
        # Transcribe
        segments, info = model.transcribe(
            audio_path,
            language=language,
            beam_size=5,
            vad_filter=True,  # Enable voice activity detection
            vad_parameters=dict(min_silence_duration_ms=500)
        )
        
        # Collect all segments
        transcription = " ".join([segment.text.strip() for segment in segments])
        
        return transcription.strip()
        
    except Exception as e:
        print(f"Error during transcription: {e}", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Transcribe audio using faster-whisper")
    parser.add_argument("audio_file", help="Path to audio file")
    parser.add_argument("--model", default="tiny", 
                       help="Model size: tiny, base, small, medium, large-v3 (default: tiny)")
    parser.add_argument("--language", default=None,
                       help="Language code (e.g., 'en', 'zh'). Auto-detect if not specified")
    parser.add_argument("--device", default="cpu",
                       help="Device: cpu, cuda, auto (default: cpu)")
    parser.add_argument("--compute-type", default="int8",
                       help="Compute type: int8, int8_float16, float16 (default: int8)")
    
    args = parser.parse_args()
    
    # Transcribe
    transcription = transcribe_audio(
        args.audio_file,
        model_size=args.model,
        language=args.language,
        device=args.device,
        compute_type=args.compute_type
    )
    
    # Output transcription
    print(transcription)


if __name__ == "__main__":
    main()
