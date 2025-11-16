#!/usr/bin/env python3
"""
Test script for speaker diarization installation
Verifies all dependencies are installed correctly
"""

import sys

def test_imports():
    """Test that all required packages can be imported"""
    print("Testing diarization package imports...")
    
    tests = [
        ("numpy", "NumPy"),
        ("scipy", "SciPy"),
        ("soundfile", "SoundFile"),
        ("webrtcvad", "WebRTC VAD"),
        ("resemblyzer", "Resemblyzer"),
        ("sklearn", "scikit-learn"),
        ("hdbscan", "HDBSCAN"),
    ]
    
    failed = []
    
    for module_name, display_name in tests:
        try:
            __import__(module_name)
            print(f"  ✓ {display_name}")
        except ImportError as e:
            print(f"  ✗ {display_name} - {e}")
            failed.append(display_name)
    
    if failed:
        print(f"\n❌ Failed to import: {', '.join(failed)}")
        print("\nInstall missing packages with:")
        print("  pip3 install -r python/requirements.txt")
        return False
    else:
        print("\n✓ All dependencies installed successfully!")
        return True


def test_diarization_modules():
    """Test that diarization modules can be imported"""
    print("\nTesting diarization modules...")
    
    try:
        from diarization import VoiceActivityDetector, SpeakerEmbedder, SpeakerClusterer
        print("  ✓ VAD module")
        print("  ✓ Embedder module")
        print("  ✓ Clustering module")
        
        # Test initialization
        vad = VoiceActivityDetector(aggressiveness=3)
        print("  ✓ VAD initialization")
        
        embedder = SpeakerEmbedder()
        print("  ✓ Embedder initialization (model may download on first run)")
        
        clusterer = SpeakerClusterer(method='spectral')
        print("  ✓ Clusterer initialization")
        
        print("\n✓ All diarization modules working!")
        return True
        
    except Exception as e:
        print(f"\n❌ Error testing modules: {e}")
        return False


def main():
    print("=" * 60)
    print("Speaker Diarization Installation Test")
    print("=" * 60)
    print()
    
    # Test imports
    if not test_imports():
        sys.exit(1)
    
    # Test modules
    if not test_diarization_modules():
        sys.exit(1)
    
    print("\n" + "=" * 60)
    print("✓ All tests passed! Diarization is ready to use.")
    print("=" * 60)
    print("\nTry running speaker diarization on an audio file:")
    print("  python3 python/speaker_diarization.py your_audio.wav")
    print()


if __name__ == "__main__":
    main()
