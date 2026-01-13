# ia/services/embeddings.py
from typing import Iterable, Optional
import numpy as np

_model = None
_dim: Optional[int] = None

def get_model(name: str = "sentence-transformers/all-MiniLM-L6-v2"):
    """
    Carga perezosa del modelo. Requiere:
      pip install sentence-transformers
    """
    global _model, _dim
    if _model is None:
        from sentence_transformers import SentenceTransformer
        _model = SentenceTransformer(name)
        _dim = _model.get_sentence_embedding_dimension()
    return _model

def embedding_dim() -> int:
    global _dim
    if _dim is None:
        get_model()
    return int(_dim or 384)

def encode_texts(texts: Iterable[str]) -> np.ndarray:
    model = get_model()
    embs = model.encode(list(texts), normalize_embeddings=True)
    return np.asarray(embs, dtype=np.float32)

def to_bytes(vec: np.ndarray) -> bytes:
    vec = np.asarray(vec, dtype=np.float32)
    return vec.tobytes(order="C")

def from_bytes(buf: bytes, dim: int) -> np.ndarray:
    return np.frombuffer(buf, dtype=np.float32, count=dim)
