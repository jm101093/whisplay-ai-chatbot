"""
Speaker Diarization Package
Air-gapped compatible - fully local operation for Raspberry Pi 5
"""

from .vad import VoiceActivityDetector
from .embedder import SpeakerEmbedder
from .clustering import SpeakerClusterer

__all__ = [
    'VoiceActivityDetector',
    'SpeakerEmbedder', 
    'SpeakerClusterer',
]
