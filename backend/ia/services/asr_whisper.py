"""
Simple Whisper ASR wrapper used by the ia translator flow.
Loads a small whisper model lazily and exposes `transcribe_file`.
This module tolerates `whisper` missing and raises a clear RuntimeError.

Requirements:
 - pip install -U openai-whisper   # or whisper package you prefer
 - ffmpeg available in PATH
"""
from typing import Optional
import os

WHISPER = None
WHISPER_MODEL = None
WHISPER_LOAD_ERROR: Optional[str] = None

def _ensure_whisper():
    global WHISPER, WHISPER_MODEL, WHISPER_LOAD_ERROR
    if WHISPER_MODEL is not None or WHISPER_LOAD_ERROR is not None:
        return
    try:
        import whisper  # type: ignore
        WHISPER = whisper
    except Exception as e:
        WHISPER = None
        WHISPER_MODEL = None
        WHISPER_LOAD_ERROR = f"whisper import failed: {e}"
        return

    try:
        # choose model size according to your infra: tiny, base, small, medium, large
        WHISPER_MODEL = WHISPER.load_model(os.environ.get("WHISPER_MODEL", "tiny"))
    except Exception as e:
        WHISPER_MODEL = None
        WHISPER_LOAD_ERROR = f"whisper model load failed: {e}"


def transcribe_file(path: str, language: Optional[str] = None) -> str:
    """Transcribe an audio file path and return the recognized text.

    Raises RuntimeError with helpful message when whisper/ffmpeg are missing.
    """
    _ensure_whisper()
    if WHISPER_MODEL is None:
        raise RuntimeError(f"Whisper model not available: {WHISPER_LOAD_ERROR}")

    if not os.path.exists(path):
        raise RuntimeError("audio file not found")

    try:
        # whisper.transcribe accepts many formats (ffmpeg required on system)
        opts = {}
        if language:
            opts["language"] = language
        res = WHISPER_MODEL.transcribe(path, **opts)
        txt = (res.get("text") or "").strip()
        return txt
    except FileNotFoundError as e:
        # often indicates ffmpeg is not installed/visible
        raise RuntimeError("ffmpeg not found: ensure ffmpeg is installed and in PATH") from e
    except Exception as e:
        raise RuntimeError(f"whisper transcribe error: {e}") from e
