"""
Speaker Embedding Extraction using Resemblyzer
Air-gapped compatible - models downloaded and cached locally
Generates 256-dimensional speaker embeddings for clustering
"""

import numpy as np
from typing import List, Tuple, Optional
import os


class SpeakerEmbedder:
    """
    Extract speaker embeddings using Resemblyzer
    Optimized for Raspberry Pi 5 - CPU-only operation
    """

    def __init__(self, model_path: Optional[str] = None):
        """
        Initialize speaker embedder
        
        Args:
            model_path: Path to cached resemblyzer model (optional, will download if not exists)
        """
        from resemblyzer import VoiceEncoder
        
        # Initialize encoder (downloads model on first run, then caches)
        if model_path and os.path.exists(model_path):
            self.encoder = VoiceEncoder(model_path)
        else:
            # Will download to ~/.cache/resemblyzer/ on first run
            # For air-gapped: pre-download and copy to Pi
            self.encoder = VoiceEncoder()
        
        self.sample_rate = 16000  # Resemblyzer expects 16kHz
        
    def embed_segment(self, audio: np.ndarray) -> np.ndarray:
        """
        Extract embedding from audio segment
        
        Args:
            audio: Audio samples as float32 numpy array (16kHz)
            
        Returns:
            256-dimensional embedding vector
        """
        # Resemblyzer expects shape (samples,) or (samples, channels)
        if len(audio.shape) > 1:
            audio = audio.mean(axis=1)  # Convert stereo to mono
        
        # Extract embedding
        embedding = self.encoder.embed_utterance(audio)
        
        return embedding
    
    def embed_segments(
        self, 
        audio_segments: List[Tuple[np.ndarray, float, float]]
    ) -> List[Tuple[np.ndarray, float, float]]:
        """
        Extract embeddings from multiple audio segments
        
        Args:
            audio_segments: List of (audio_chunk, start_time, end_time) tuples
            
        Returns:
            List of (embedding, start_time, end_time) tuples
        """
        embeddings = []
        
        for audio_chunk, start_time, end_time in audio_segments:
            try:
                embedding = self.embed_segment(audio_chunk)
                embeddings.append((embedding, start_time, end_time))
            except Exception as e:
                print(f"Warning: Failed to extract embedding for segment {start_time:.2f}s-{end_time:.2f}s: {e}")
                # Skip segments that fail (e.g., too short)
                continue
        
        return embeddings
    
    def embed_continuous(
        self, 
        audio: np.ndarray, 
        window_size: float = 1.0,
        overlap: float = 0.5
    ) -> List[Tuple[np.ndarray, float, float]]:
        """
        Extract embeddings from continuous audio using sliding window
        Useful for real-time/streaming scenarios
        
        Args:
            audio: Audio samples as float32 numpy array (16kHz)
            window_size: Window size in seconds
            overlap: Overlap ratio (0.0 to 1.0)
            
        Returns:
            List of (embedding, start_time, end_time) tuples
        """
        window_samples = int(window_size * self.sample_rate)
        step_samples = int(window_samples * (1 - overlap))
        
        embeddings = []
        
        for start_sample in range(0, len(audio) - window_samples + 1, step_samples):
            end_sample = start_sample + window_samples
            audio_chunk = audio[start_sample:end_sample]
            
            start_time = start_sample / self.sample_rate
            end_time = end_sample / self.sample_rate
            
            try:
                embedding = self.embed_segment(audio_chunk)
                embeddings.append((embedding, start_time, end_time))
            except Exception as e:
                print(f"Warning: Failed to extract embedding for window {start_time:.2f}s-{end_time:.2f}s: {e}")
                continue
        
        return embeddings
    
    def compute_similarity(self, embedding1: np.ndarray, embedding2: np.ndarray) -> float:
        """
        Compute cosine similarity between two embeddings
        
        Args:
            embedding1: First embedding vector
            embedding2: Second embedding vector
            
        Returns:
            Similarity score (0.0 to 1.0)
        """
        # Cosine similarity
        similarity = np.dot(embedding1, embedding2) / (
            np.linalg.norm(embedding1) * np.linalg.norm(embedding2)
        )
        
        # Normalize to 0-1 range
        return (similarity + 1) / 2


def test_embedder():
    """Test embedder with dummy audio"""
    import soundfile as sf
    
    # Load test audio
    audio, sr = sf.read("test_audio.wav")
    
    # Resample to 16kHz if needed
    if sr != 16000:
        from scipy import signal
        audio = signal.resample_poly(audio, 16000, sr)
        sr = 16000
    
    # Extract embeddings
    embedder = SpeakerEmbedder()
    
    # Test single segment
    embedding = embedder.embed_segment(audio[:sr * 3])  # First 3 seconds
    print(f"Embedding shape: {embedding.shape}")
    print(f"Embedding norm: {np.linalg.norm(embedding):.4f}")
    
    # Test continuous extraction
    embeddings = embedder.embed_continuous(audio, window_size=2.0, overlap=0.5)
    print(f"Extracted {len(embeddings)} embeddings from continuous audio")
    
    # Test similarity
    if len(embeddings) >= 2:
        sim = embedder.compute_similarity(embeddings[0][0], embeddings[1][0])
        print(f"Similarity between first two windows: {sim:.4f}")
    
    return embeddings


if __name__ == "__main__":
    test_embedder()
