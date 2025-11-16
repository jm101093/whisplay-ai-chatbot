#!/usr/bin/env python3
"""
Coqui TTS Wrapper for Whisplay AI Chatbot
Provides text-to-speech synthesis using Coqui TTS library
"""

import sys
import os
import argparse
from pathlib import Path

try:
    from TTS.api import TTS
except ImportError:
    print("Error: Coqui TTS library not found.", file=sys.stderr)
    print("Install it with: pip install TTS", file=sys.stderr)
    sys.exit(1)


def synthesize_speech(
    text: str,
    output_file: str,
    model_name: str = "tts_models/en/ljspeech/tacotron2-DDC",
    speaker: str = None,
    language: str = None,
    gpu: bool = False
) -> bool:
    """
    Synthesize speech from text using Coqui TTS
    
    Args:
        text: Text to synthesize
        output_file: Path to save the audio file (WAV format)
        model_name: TTS model to use
        speaker: Speaker name for multi-speaker models
        language: Language code for multi-lingual models
        gpu: Whether to use GPU acceleration
        
    Returns:
        bool: True if successful, False otherwise
    """
    try:
        # Initialize TTS with the specified model
        tts = TTS(model_name=model_name, gpu=gpu)
        
        # Prepare synthesis parameters
        synthesis_kwargs = {
            "text": text,
            "file_path": output_file
        }
        
        # Add speaker if specified and model supports it
        if speaker and hasattr(tts, 'speakers') and tts.speakers:
            synthesis_kwargs["speaker"] = speaker
            
        # Add language if specified and model supports it
        if language and hasattr(tts, 'languages') and tts.languages:
            synthesis_kwargs["language"] = language
        
        # Synthesize speech
        tts.tts_to_file(**synthesis_kwargs)
        
        return True
        
    except Exception as e:
        print(f"Error during TTS synthesis: {e}", file=sys.stderr)
        return False


def list_models():
    """List all available TTS models"""
    try:
        tts = TTS()
        print("Available TTS models:")
        print("-" * 80)
        for model in tts.list_models():
            print(f"  {model}")
        print("-" * 80)
    except Exception as e:
        print(f"Error listing models: {e}", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Coqui TTS - Text-to-Speech Synthesis",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic usage with default model
  python coqui_tts.py -t "Hello world" -o output.wav
  
  # Use a specific model
  python coqui_tts.py -t "Hello" -o out.wav -m "tts_models/en/vctk/vits"
  
  # Multi-speaker model with specific speaker
  python coqui_tts.py -t "Hello" -o out.wav -m "tts_models/en/vctk/vits" -s "p225"
  
  # Multi-lingual model with language selection
  python coqui_tts.py -t "Bonjour" -o out.wav -m "tts_models/multilingual/multi-dataset/your_tts" -l "fr"
  
  # List all available models
  python coqui_tts.py --list-models
  
  # Use GPU acceleration
  python coqui_tts.py -t "Hello" -o out.wav --gpu
"""
    )
    
    parser.add_argument(
        "-t", "--text",
        type=str,
        help="Text to synthesize"
    )
    
    parser.add_argument(
        "-o", "--output",
        type=str,
        help="Output WAV file path"
    )
    
    parser.add_argument(
        "-m", "--model",
        type=str,
        default="tts_models/en/ljspeech/tacotron2-DDC",
        help="TTS model name (default: tts_models/en/ljspeech/tacotron2-DDC)"
    )
    
    parser.add_argument(
        "-s", "--speaker",
        type=str,
        default=None,
        help="Speaker name for multi-speaker models"
    )
    
    parser.add_argument(
        "-l", "--language",
        type=str,
        default=None,
        help="Language code for multi-lingual models (e.g., 'en', 'es', 'fr')"
    )
    
    parser.add_argument(
        "--gpu",
        action="store_true",
        help="Use GPU acceleration (requires CUDA)"
    )
    
    parser.add_argument(
        "--list-models",
        action="store_true",
        help="List all available TTS models"
    )
    
    args = parser.parse_args()
    
    # Handle list models request
    if args.list_models:
        list_models()
        return
    
    # Validate required arguments
    if not args.text or not args.output:
        parser.print_help()
        sys.exit(1)
    
    # Ensure output directory exists
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Synthesize speech
    print(f"Synthesizing: {args.text}", file=sys.stderr)
    print(f"Model: {args.model}", file=sys.stderr)
    if args.speaker:
        print(f"Speaker: {args.speaker}", file=sys.stderr)
    if args.language:
        print(f"Language: {args.language}", file=sys.stderr)
    
    success = synthesize_speech(
        text=args.text,
        output_file=str(output_path),
        model_name=args.model,
        speaker=args.speaker,
        language=args.language,
        gpu=args.gpu
    )
    
    if success:
        print(f"Success: Audio saved to {args.output}", file=sys.stderr)
        sys.exit(0)
    else:
        print("Failed to synthesize speech", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
