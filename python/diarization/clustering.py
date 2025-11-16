"""
Speaker Clustering Module
Air-gapped compatible - uses HDBSCAN or spectral clustering
Groups speaker embeddings to identify unique speakers
"""

import numpy as np
from typing import List, Tuple, Optional
from sklearn.cluster import SpectralClustering
from sklearn.preprocessing import StandardScaler


class SpeakerClusterer:
    """
    Cluster speaker embeddings to identify unique speakers
    Optimized for Raspberry Pi 5 - CPU-only operation
    """

    def __init__(
        self, 
        method: str = "hdbscan",
        min_cluster_size: int = 3,
        min_samples: int = 2
    ):
        """
        Initialize speaker clusterer
        
        Args:
            method: Clustering method ('hdbscan' or 'spectral')
            min_cluster_size: Minimum cluster size for HDBSCAN
            min_samples: Minimum samples for HDBSCAN core points
        """
        self.method = method.lower()
        self.min_cluster_size = min_cluster_size
        self.min_samples = min_samples
        self.scaler = StandardScaler()
        
        if self.method not in ['hdbscan', 'spectral']:
            raise ValueError(f"Unknown clustering method: {method}")
    
    def cluster_embeddings(
        self, 
        embeddings: List[np.ndarray],
        num_speakers: Optional[int] = None
    ) -> np.ndarray:
        """
        Cluster embeddings into speaker groups
        
        Args:
            embeddings: List of embedding vectors
            num_speakers: Number of speakers (required for spectral, optional for HDBSCAN)
            
        Returns:
            Array of cluster labels (speaker IDs), -1 indicates noise/uncertain
        """
        if len(embeddings) == 0:
            return np.array([])
        
        # Handle single segment case - assign all to speaker 0
        if len(embeddings) == 1:
            return np.array([0])
        
        # Stack embeddings into matrix
        embedding_matrix = np.stack(embeddings)
        
        # Normalize embeddings
        embedding_matrix_scaled = self.scaler.fit_transform(embedding_matrix)
        
        if self.method == 'hdbscan':
            return self._cluster_hdbscan(embedding_matrix_scaled)
        elif self.method == 'spectral':
            if num_speakers is None:
                # Auto-detect number of speakers using elbow method
                num_speakers = self._estimate_num_speakers(embedding_matrix_scaled)
            return self._cluster_spectral(embedding_matrix_scaled, num_speakers)
        
        return np.array([])
    
    def _cluster_hdbscan(self, embeddings: np.ndarray) -> np.ndarray:
        """
        Cluster using HDBSCAN (density-based, auto-detects speaker count)
        
        Args:
            embeddings: Normalized embedding matrix
            
        Returns:
            Cluster labels
        """
        try:
            import hdbscan
            
            clusterer = hdbscan.HDBSCAN(
                min_cluster_size=self.min_cluster_size,
                min_samples=self.min_samples,
                metric='euclidean',
                cluster_selection_method='eom'
            )
            
            labels = clusterer.fit_predict(embeddings)
            
            # HDBSCAN returns -1 for noise points
            # Convert to sequential speaker IDs
            unique_labels = np.unique(labels[labels != -1])
            speaker_labels = labels.copy()
            
            for new_id, old_id in enumerate(sorted(unique_labels)):
                speaker_labels[labels == old_id] = new_id
            
            return speaker_labels
            
        except ImportError:
            print("Warning: hdbscan not installed, falling back to spectral clustering")
            num_speakers = self._estimate_num_speakers(embeddings)
            return self._cluster_spectral(embeddings, num_speakers)
    
    def _cluster_spectral(self, embeddings: np.ndarray, num_speakers: int) -> np.ndarray:
        """
        Cluster using Spectral Clustering (requires known speaker count)
        
        Args:
            embeddings: Normalized embedding matrix
            num_speakers: Number of speakers
            
        Returns:
            Cluster labels
        """
        if num_speakers < 1:
            num_speakers = 2  # Default to 2 speakers
        
        # Ensure we don't request more clusters than samples
        num_speakers = min(num_speakers, len(embeddings))
        
        clusterer = SpectralClustering(
            n_clusters=num_speakers,
            affinity='nearest_neighbors',
            n_neighbors=min(10, len(embeddings)),
            assign_labels='kmeans',
            random_state=42
        )
        
        labels = clusterer.fit_predict(embeddings)
        
        return labels
    
    def _estimate_num_speakers(self, embeddings: np.ndarray, max_speakers: int = 10) -> int:
        """
        Estimate number of speakers using silhouette analysis
        
        Args:
            embeddings: Normalized embedding matrix
            max_speakers: Maximum number of speakers to consider
            
        Returns:
            Estimated number of speakers
        """
        from sklearn.metrics import silhouette_score
        
        if len(embeddings) < 2:
            return 1
        
        max_speakers = min(max_speakers, len(embeddings))
        
        best_score = -1
        best_k = 2
        
        for k in range(2, max_speakers + 1):
            try:
                clusterer = SpectralClustering(
                    n_clusters=k,
                    affinity='nearest_neighbors',
                    n_neighbors=min(10, len(embeddings)),
                    assign_labels='kmeans',
                    random_state=42
                )
                labels = clusterer.fit_predict(embeddings)
                score = silhouette_score(embeddings, labels)
                
                if score > best_score:
                    best_score = score
                    best_k = k
                    
            except Exception as e:
                print(f"Warning: Failed to compute silhouette for k={k}: {e}")
                continue
        
        return best_k
    
    def assign_speakers_to_segments(
        self,
        embeddings_with_times: List[Tuple[np.ndarray, float, float]],
        num_speakers: Optional[int] = None
    ) -> List[Tuple[int, float, float]]:
        """
        Assign speaker labels to time segments
        
        Args:
            embeddings_with_times: List of (embedding, start_time, end_time) tuples
            num_speakers: Number of speakers (optional)
            
        Returns:
            List of (speaker_id, start_time, end_time) tuples
        """
        if len(embeddings_with_times) == 0:
            return []
        
        # Extract embeddings
        embeddings = [emb for emb, _, _ in embeddings_with_times]
        
        # Cluster
        labels = self.cluster_embeddings(embeddings, num_speakers)
        
        # Combine with time information
        segments = []
        for i, (_, start_time, end_time) in enumerate(embeddings_with_times):
            speaker_id = int(labels[i])
            segments.append((speaker_id, start_time, end_time))
        
        return segments
    
    def merge_adjacent_segments(
        self,
        segments: List[Tuple[int, float, float]],
        max_gap: float = 0.5
    ) -> List[Tuple[int, float, float]]:
        """
        Merge adjacent segments from the same speaker
        
        Args:
            segments: List of (speaker_id, start_time, end_time) tuples
            max_gap: Maximum gap between segments to merge (seconds)
            
        Returns:
            Merged list of (speaker_id, start_time, end_time) tuples
        """
        if len(segments) == 0:
            return []
        
        # Sort by start time
        segments = sorted(segments, key=lambda x: x[1])
        
        merged = []
        current_speaker, current_start, current_end = segments[0]
        
        for speaker_id, start_time, end_time in segments[1:]:
            # Check if same speaker and within max_gap
            if speaker_id == current_speaker and (start_time - current_end) <= max_gap:
                # Merge segments
                current_end = end_time
            else:
                # Save current segment and start new one
                merged.append((current_speaker, current_start, current_end))
                current_speaker = speaker_id
                current_start = start_time
                current_end = end_time
        
        # Add final segment
        merged.append((current_speaker, current_start, current_end))
        
        return merged


def test_clustering():
    """Test clustering with dummy embeddings"""
    # Generate fake embeddings (3 speakers, 10 segments each)
    np.random.seed(42)
    
    embeddings = []
    true_labels = []
    
    # Speaker 1: embeddings around [1, 0, 0, ...]
    for _ in range(10):
        emb = np.random.randn(256) * 0.1
        emb[0] = 1.0
        embeddings.append(emb)
        true_labels.append(0)
    
    # Speaker 2: embeddings around [0, 1, 0, ...]
    for _ in range(10):
        emb = np.random.randn(256) * 0.1
        emb[1] = 1.0
        embeddings.append(emb)
        true_labels.append(1)
    
    # Speaker 3: embeddings around [0, 0, 1, ...]
    for _ in range(10):
        emb = np.random.randn(256) * 0.1
        emb[2] = 1.0
        embeddings.append(emb)
        true_labels.append(2)
    
    # Shuffle
    indices = np.random.permutation(30)
    embeddings = [embeddings[i] for i in indices]
    true_labels = [true_labels[i] for i in indices]
    
    # Test HDBSCAN
    print("Testing HDBSCAN clustering...")
    clusterer = SpeakerClusterer(method='hdbscan')
    labels = clusterer.cluster_embeddings(embeddings)
    print(f"Predicted {len(np.unique(labels[labels != -1]))} speakers")
    print(f"Labels: {labels}")
    
    # Test Spectral
    print("\nTesting Spectral clustering...")
    clusterer = SpeakerClusterer(method='spectral')
    labels = clusterer.cluster_embeddings(embeddings, num_speakers=3)
    print(f"Predicted labels: {labels}")
    
    # Test segment assignment
    print("\nTesting segment assignment...")
    embeddings_with_times = [
        (emb, i * 1.0, (i + 1) * 1.0) 
        for i, emb in enumerate(embeddings[:10])
    ]
    segments = clusterer.assign_speakers_to_segments(embeddings_with_times)
    
    print("Speaker segments:")
    for speaker_id, start, end in segments:
        print(f"  Speaker {speaker_id}: {start:.1f}s - {end:.1f}s")


if __name__ == "__main__":
    test_clustering()
