"""
Voice Activity Detection (VAD) module for speaker diarization
Air-gapped compatible - no cloud dependencies
Uses WebRTC VAD for lightweight, real-time speech detection
"""

import webrtcvad
import numpy as np
from typing import List, Tuple
import struct


class VoiceActivityDetector:
    """
    Detects speech segments in audio using WebRTC VAD
    Optimized for Raspberry Pi 5 - CPU-only, low memory
    """

    def __init__(self, aggressiveness: int = 3, sample_rate: int = 16000):
        """
        Initialize VAD
        
        Args:
            aggressiveness: 0-3, where 3 is most aggressive filtering (recommended for Pi)
            sample_rate: Audio sample rate (must be 8000, 16000, 32000, or 48000)
        """
        if sample_rate not in [8000, 16000, 32000, 48000]:
            raise ValueError(f"Sample rate must be 8000, 16000, 32000, or 48000, got {sample_rate}")
        
        self.vad = webrtcvad.Vad(aggressiveness)
        self.sample_rate = sample_rate
        self.frame_duration_ms = 30  # 10, 20, or 30 ms frames
        self.frame_size = int(sample_rate * self.frame_duration_ms / 1000)
        
    def _frame_generator(self, audio: np.ndarray) -> List[bytes]:
        """
        Generate fixed-size frames from audio array
        
        Args:
            audio: Audio samples as float32 numpy array (-1.0 to 1.0)
            
        Returns:
            List of audio frames as bytes
        """
        # Convert float32 to int16
        audio_int16 = (audio * 32767).astype(np.int16)
        
        # Generate frames
        frames = []
        offset = 0
        while offset + self.frame_size <= len(audio_int16):
            frame = audio_int16[offset:offset + self.frame_size]
            frames.append(frame.tobytes())
            offset += self.frame_size
            
        return frames
    
    def detect_speech_segments(
        self, 
        audio: np.ndarray, 
        padding_duration_ms: int = 300,
        min_speech_duration_ms: int = 250
    ) -> List[Tuple[float, float]]:
        """
        Detect speech segments in audio
        
        Args:
            audio: Audio samples as float32 numpy array
            padding_duration_ms: Padding around speech segments
            min_speech_duration_ms: Minimum duration to consider as speech
            
        Returns:
            List of (start_time, end_time) tuples in seconds
        """
        frames = self._frame_generator(audio)
        
        # Calculate padding in frames
        num_padding_frames = int(padding_duration_ms / self.frame_duration_ms)
        min_speech_frames = int(min_speech_duration_ms / self.frame_duration_ms)
        
        # Ring buffer for padding
        ring_buffer = [False] * num_padding_frames
        triggered = False
        
        speech_segments = []
        segment_start = None
        
        for i, frame in enumerate(frames):
            is_speech = self.vad.is_speech(frame, self.sample_rate)
            
            # Update ring buffer
            ring_buffer.append(is_speech)
            ring_buffer.pop(0)
            
            # Determine if we should trigger speech detection
            num_voiced = sum(ring_buffer)
            
            if not triggered:
                # Start of speech segment
                if num_voiced > 0.9 * num_padding_frames:
                    triggered = True
                    segment_start = max(0, (i - num_padding_frames) * self.frame_duration_ms / 1000.0)
            else:
                # End of speech segment
                if num_voiced < 0.1 * num_padding_frames:
                    triggered = False
                    segment_end = (i + num_padding_frames) * self.frame_duration_ms / 1000.0
                    
                    # Check minimum duration
                    if (segment_end - segment_start) * 1000 >= min_speech_duration_ms:
                        speech_segments.append((segment_start, segment_end))
                    
                    segment_start = None
        
        # Handle case where audio ends during speech
        if triggered and segment_start is not None:
            segment_end = len(frames) * self.frame_duration_ms / 1000.0
            if (segment_end - segment_start) * 1000 >= min_speech_duration_ms:
                speech_segments.append((segment_start, segment_end))
        
        return speech_segments
    
    def segment_audio(
        self, 
        audio: np.ndarray, 
        padding_duration_ms: int = 300
    ) -> List[Tuple[np.ndarray, float, float]]:
        """
        Segment audio into speech chunks
        
        Args:
            audio: Audio samples as float32 numpy array
            padding_duration_ms: Padding around speech segments
            
        Returns:
            List of (audio_chunk, start_time, end_time) tuples
        """
        segments = self.detect_speech_segments(audio, padding_duration_ms)
        
        audio_segments = []
        for start_time, end_time in segments:
            start_sample = int(start_time * self.sample_rate)
            end_sample = int(end_time * self.sample_rate)
            audio_chunk = audio[start_sample:end_sample]
            audio_segments.append((audio_chunk, start_time, end_time))
        
        return audio_segments


def test_vad():
    """Test VAD with dummy audio"""
    import soundfile as sf
    
    # Load test audio
    audio, sr = sf.read("test_audio.wav")
    
    # Resample to 16kHz if needed
    if sr != 16000:
        from scipy import signal
        audio = signal.resample_poly(audio, 16000, sr)
        sr = 16000
    
    # Detect speech
    vad = VoiceActivityDetector(aggressiveness=3, sample_rate=sr)
    segments = vad.detect_speech_segments(audio)
    
    print(f"Found {len(segments)} speech segments:")
    for i, (start, end) in enumerate(segments):
        print(f"  Segment {i+1}: {start:.2f}s - {end:.2f}s ({end-start:.2f}s)")
    
    return segments


if __name__ == "__main__":
    test_vad()
