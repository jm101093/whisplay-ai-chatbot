"""
Complete Speaker Diarization Pipeline
Integrates VAD, embedding extraction, and clustering
Air-gapped compatible for Raspberry Pi 5
"""

import numpy as np
import soundfile as sf
from typing import List, Tuple, Optional
import sys
import argparse

from diarization import VoiceActivityDetector, SpeakerEmbedder, SpeakerClusterer


class SpeakerDiarizationPipeline:
    """
    Complete speaker diarization pipeline
    Processes audio file and outputs speaker-labeled segments
    """

    def __init__(
        self,
        vad_aggressiveness: int = 3,
        clustering_method: str = "hdbscan",
        min_cluster_size: int = 3
    ):
        """
        Initialize diarization pipeline
        
        Args:
            vad_aggressiveness: VAD aggressiveness (0-3)
            clustering_method: 'hdbscan' or 'spectral'
            min_cluster_size: Minimum cluster size for HDBSCAN
        """
        self.vad = VoiceActivityDetector(aggressiveness=vad_aggressiveness)
        self.embedder = SpeakerEmbedder()
        self.clusterer = SpeakerClusterer(
            method=clustering_method,
            min_cluster_size=min_cluster_size
        )
    
    def process_audio_file(
        self,
        audio_path: str,
        num_speakers: Optional[int] = None
    ) -> List[Tuple[int, float, float]]:
        """
        Process audio file and return speaker segments
        
        Args:
            audio_path: Path to audio file (wav format)
            num_speakers: Number of speakers (optional, auto-detect if None)
            
        Returns:
            List of (speaker_id, start_time, end_time) tuples
        """
        # Load audio
        audio, sample_rate = sf.read(audio_path)
        
        # Convert stereo to mono if needed
        if len(audio.shape) > 1:
            audio = audio.mean(axis=1)
        
        # Resample to 16kHz if needed
        if sample_rate != 16000:
            from scipy import signal
            audio = signal.resample_poly(audio, 16000, sample_rate)
            sample_rate = 16000
        
        # Ensure float32
        audio = audio.astype(np.float32)
        
        # Step 1: Voice Activity Detection
        print(f"[VAD] Detecting speech segments...")
        speech_segments = self.vad.segment_audio(audio, padding_duration_ms=300)
        print(f"[VAD] Found {len(speech_segments)} speech segments")
        
        if len(speech_segments) == 0:
            print("[WARN] No speech detected in audio")
            return []
        
        # Step 2: Extract speaker embeddings
        print(f"[EMBEDDING] Extracting speaker embeddings...")
        embeddings_with_times = self.embedder.embed_segments(speech_segments)
        print(f"[EMBEDDING] Extracted {len(embeddings_with_times)} embeddings")
        
        if len(embeddings_with_times) == 0:
            print("[WARN] No embeddings extracted")
            return []
        
        # Step 3: Cluster embeddings to identify speakers
        print(f"[CLUSTERING] Clustering speakers...")
        speaker_segments = self.clusterer.assign_speakers_to_segments(
            embeddings_with_times,
            num_speakers=num_speakers
        )
        
        # Step 4: Merge adjacent segments from same speaker
        print(f"[MERGE] Merging adjacent segments...")
        merged_segments = self.clusterer.merge_adjacent_segments(
            speaker_segments,
            max_gap=0.5
        )
        
        # Count unique speakers
        unique_speakers = len(set(sp for sp, _, _ in merged_segments if sp >= 0))
        print(f"[DONE] Identified {unique_speakers} unique speakers")
        print(f"[DONE] Generated {len(merged_segments)} speaker segments")
        
        return merged_segments
    
    def process_audio_array(
        self,
        audio: np.ndarray,
        sample_rate: int = 16000,
        num_speakers: Optional[int] = None
    ) -> List[Tuple[int, float, float]]:
        """
        Process audio numpy array and return speaker segments
        
        Args:
            audio: Audio samples as float32 numpy array
            sample_rate: Audio sample rate
            num_speakers: Number of speakers (optional)
            
        Returns:
            List of (speaker_id, start_time, end_time) tuples
        """
        # Convert stereo to mono if needed
        if len(audio.shape) > 1:
            audio = audio.mean(axis=1)
        
        # Resample to 16kHz if needed
        if sample_rate != 16000:
            from scipy import signal
            audio = signal.resample_poly(audio, 16000, sample_rate)
        
        # Ensure float32
        audio = audio.astype(np.float32)
        
        # Process segments
        speech_segments = self.vad.segment_audio(audio)
        embeddings_with_times = self.embedder.embed_segments(speech_segments)
        speaker_segments = self.clusterer.assign_speakers_to_segments(
            embeddings_with_times, 
            num_speakers
        )
        merged_segments = self.clusterer.merge_adjacent_segments(speaker_segments)
        
        return merged_segments


def format_time(seconds: float) -> str:
    """Format time in seconds to MM:SS.mmm"""
    minutes = int(seconds // 60)
    secs = seconds % 60
    return f"{minutes:02d}:{secs:06.3f}"


def print_segments(segments: List[Tuple[int, float, float]]):
    """Print speaker segments in readable format"""
    print("\nSpeaker Segments:")
    print("-" * 60)
    for speaker_id, start_time, end_time in segments:
        duration = end_time - start_time
        if speaker_id == -1:
            print(f"[UNCERTAIN] {format_time(start_time)} - {format_time(end_time)} ({duration:.2f}s)")
        else:
            print(f"[SPEAKER {speaker_id}] {format_time(start_time)} - {format_time(end_time)} ({duration:.2f}s)")
    print("-" * 60)


def save_rttm(segments: List[Tuple[int, float, float]], output_path: str, audio_filename: str = "audio"):
    """
    Save segments in RTTM format (Rich Transcription Time Marked)
    Standard format for speaker diarization evaluation
    
    Args:
        segments: List of (speaker_id, start_time, end_time) tuples
        output_path: Output RTTM file path
        audio_filename: Name to use in RTTM file
    """
    with open(output_path, 'w') as f:
        for speaker_id, start_time, end_time in segments:
            if speaker_id == -1:
                continue  # Skip uncertain segments
            duration = end_time - start_time
            # RTTM format: SPEAKER filename channel start duration <NA> <NA> speaker <NA> <NA>
            f.write(f"SPEAKER {audio_filename} 1 {start_time:.3f} {duration:.3f} <NA> <NA> speaker_{speaker_id} <NA> <NA>\n")
    
    print(f"Saved RTTM to: {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Speaker Diarization Pipeline - Air-gapped compatible"
    )
    parser.add_argument(
        "audio_file",
        type=str,
        help="Path to audio file (WAV format)"
    )
    parser.add_argument(
        "--num-speakers",
        type=int,
        default=None,
        help="Number of speakers (optional, auto-detect if not specified)"
    )
    parser.add_argument(
        "--vad-aggressiveness",
        type=int,
        default=3,
        choices=[0, 1, 2, 3],
        help="VAD aggressiveness level (0-3, default: 3)"
    )
    parser.add_argument(
        "--clustering-method",
        type=str,
        default="hdbscan",
        choices=["hdbscan", "spectral"],
        help="Clustering method (default: hdbscan)"
    )
    parser.add_argument(
        "--output-rttm",
        type=str,
        default=None,
        help="Save output in RTTM format to specified file"
    )
    parser.add_argument(
        "--output-json",
        action="store_true",
        help="Output results in JSON format (for programmatic use)"
    )
    
    args = parser.parse_args()
    
    # Initialize pipeline
    print("Initializing diarization pipeline...")
    pipeline = SpeakerDiarizationPipeline(
        vad_aggressiveness=args.vad_aggressiveness,
        clustering_method=args.clustering_method
    )
    
    # Process audio
    print(f"Processing: {args.audio_file}", file=sys.stderr)
    segments = pipeline.process_audio_file(
        args.audio_file,
        num_speakers=args.num_speakers
    )
    
    # Output JSON if requested
    if args.output_json:
        import json
        result = {
            "segments": [
                {
                    "speaker_id": int(speaker_id),
                    "start_time": float(start_time),
                    "end_time": float(end_time)
                }
                for speaker_id, start_time, end_time in segments
                if speaker_id >= 0  # Skip uncertain segments
            ],
            "num_speakers": len(set(s for s, _, _ in segments if s >= 0))
        }
        print(json.dumps(result))
    else:
        # Print results in human-readable format
        print_segments(segments)
    
    # Save RTTM if requested
    if args.output_rttm:
        import os
        audio_basename = os.path.splitext(os.path.basename(args.audio_file))[0]
        save_rttm(segments, args.output_rttm, audio_basename)
    
    return segments


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
