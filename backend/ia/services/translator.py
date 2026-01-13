# ia/services/translator.py
from __future__ import annotations
from typing import Tuple, Iterable, Optional
from functools import lru_cache
from urllib.parse import urlparse
import base64
import tempfile
import os
import threading

try:
    # ASR local (envuelve whisper); debe exponer transcribe_file(path)->str
    from . import asr_whisper
except Exception:
    asr_whisper = None

try:
    from langdetect import detect
except Exception:
    detect = None

# Opcional: mapear variantes a códigos de opus-mt
_LANG_MAP = {
    "en-us": "en", "en-gb": "en",
    "es-es": "es", "es-419": "es", "es-mx": "es", "es-ar": "es",
    "pt-br": "pt", "pt-pt": "pt",
    "zh-cn": "zh", "zh-tw": "zh", "zh-hans": "zh", "zh-hant": "zh",
    "fr-fr": "fr",
    "de-de": "de",
    "it-it": "it",
    "ru-ru": "ru",
}

def _normalize_lang(code: str) -> str:
    if not code:
        return code
    c = code.strip().lower().replace('_', '-')
    return _LANG_MAP.get(c, c.split('-', 1)[0])  # toma la base si queda “xx-YY”

class TranslatorBackend:
    """
    Backend de traducción + ASR con carga perezosa y caché.
    Seguro ante carrera y más eficiente.
    """
    def __init__(self):
        self._models: dict[str, tuple[object, object]] = {}
        self._lock = threading.Lock()

    @staticmethod
    def _pair_name(src: str, tgt: str) -> str:
        src = _normalize_lang(src)
        tgt = _normalize_lang(tgt)
        return f"Helsinki-NLP/opus-mt-{src}-{tgt}"

    @lru_cache(maxsize=64)
    def _load_pair(self, src: str, tgt: str) -> Tuple[object, object]:
        try:
            from transformers import MarianMTModel, MarianTokenizer  # lazy
            import torch
        except Exception as e:
            raise RuntimeError(
                "Falta backend de traducción: instala transformers, torch y sentencepiece."
            ) from e

        name = self._pair_name(src, tgt)
        tok = MarianTokenizer.from_pretrained(name)
        mod = MarianMTModel.from_pretrained(name)
        mod.eval()

        # Si hay CUDA/MPS, úsalo
        try:
            if torch.cuda.is_available():
                mod.to("cuda")
            elif hasattr(torch.backends, "mps") and torch.backends.mps.is_available():  # mac
                mod.to("mps")
        except Exception:
            pass

        return tok, mod

    def _get_model(self, source: str, target: str) -> Tuple[object, object]:
        key = f"{_normalize_lang(source)}-{_normalize_lang(target)}"
        # Evita doble carga en carreras
        with self._lock:
            if key not in self._models:
                self._models[key] = self._load_pair(source, target)
            return self._models[key]

    def preload_models(self, source: str, target: str) -> None:
        """
        Inicia la carga de modelos en un hilo en background sin bloquear el caller.
        Útil para pre-cargar weights al recibir la primera conexión y evitar que
        la carga bloqueante de transformers interrumpa el loop principal.
        """
        src = _normalize_lang(source)
        tgt = _normalize_lang(target)

        def _worker():
            # Si alguno es 'auto', no intentar cargar el par directo (no existe en HF)
            if src != 'auto' and tgt != 'auto':
                # Intentar cargar par directo
                try:
                    self._get_model(src, tgt)
                    return
                except Exception:
                    try:
                        import logging
                        logging.exception("preload_models: direct load failed for %s-%s, trying pivots", src, tgt)
                    except Exception:
                        pass
            else:
                # evita intentar nombres como 'auto-en' que no existen
                try:
                    import logging
                    logging.debug("preload_models: skipping direct load because of 'auto' source/target: %s-%s", src, tgt)
                except Exception:
                    pass

            # Lista de pivotes a intentar (ordenada por probabilidad/uso)
            pivots = ["en", "fr", "es", "de", "it", "pt"]
            for p in pivots:
                if p == src or p == tgt:
                    continue
                try:
                    # precargar src->p
                    self._get_model(src, p)
                except Exception:
                    pass
                try:
                    # precargar p->tgt
                    self._get_model(p, tgt)
                except Exception:
                    pass

        th = threading.Thread(target=_worker, daemon=True)
        th.start()

    def _auto_detect(self, text: str, fallback: Optional[str] = "en") -> Optional[str]:
        """
        Intenta detectar el idioma del texto. Si no hay soporte para detección
        o falla la detección, devuelve el `fallback` (si se pasó) o None.
        """
        if detect is None:
            return fallback
        try:
            code = detect(text)
            if not code:
                return fallback
            return _normalize_lang(code)
        except Exception:
            return fallback

    def _to_brazilian_pt(self, text: str) -> str:
        """
        Pequeñas correcciones para acercar una traducción en portugués
        a la variante brasileña (pt-BR). No es exhaustivo: aplica reglas
        sencillas para expresiones comunes.
        """
        if not text:
            return text
        s = text
        # ejemplos simples y no exhaustivos
        replacements = {
            # formalidades / falsos amigos
            "está tudo bem": "tudo bem",
            "está tudo certo": "tudo certo",
            "está bem": "tudo bem",
            "bom dia": "bom dia",
            # portugués europeo -> brasileño (pequeñas muestras)
            "pequeno": "pequeno",
        }
        for k, v in replacements.items():
            s = s.replace(k, v)
            s = s.replace(k.capitalize(), v.capitalize())
        return s

    def _translate_once(self, text: str, src: str, tgt: str, max_len: int = 96) -> str:
        from transformers import MarianTokenizer  # type: ignore
        import torch

        tok, mod = self._get_model(src, tgt)
        # Asegura truncation y device correcto
        device = next(mod.parameters()).device
        with torch.no_grad():
            tokens = tok(text, return_tensors="pt", truncation=True).to(device)
            out = mod.generate(**tokens, max_length=max_len)
            # MarianTokenizer decode correcto:
            return tok.decode(out[0], skip_special_tokens=True)

    def translate_stream(self, chunks: Iterable[str], source_lang='auto', target_lang='en'):
        """
        Traduce iterativamente. Si source_lang='auto', detecta con el primer
        chunk suficientemente largo y lo fija para el resto.
        """
        detected: Optional[str] = None

        for chunk in chunks:
            if not chunk:
                yield ""
                continue

            src = source_lang
            if src == "auto":
                # Para transcripciones desde audio los textos suelen ser cortos,
                # intentar detectar siempre el idioma (mejor que asumir 'en').
                if detected is None:
                    detected = self._auto_detect(chunk, fallback=None)
                # Si no conseguimos detectar, dejar 'en' como fallback para
                # mantener compatibilidad con la versión anterior.
                src = detected or "en"

            src = _normalize_lang(src)
            tgt = _normalize_lang(target_lang)
            if src == tgt:
                yield chunk
                continue

            # Intentar traducción directa
            try:
                out = self._translate_once(chunk, src, tgt)
                yield out
                continue
            except Exception:
                # intentar pivotes en orden preferente: en, pt (BR friendly), fr, es, de, it
                pivots = ["en", "pt", "fr", "es", "de", "it"]
                translated = None
                for p in pivots:
                    if p == src or p == tgt:
                        continue
                    # src -> p
                    mid = None
                    try:
                        mid = self._translate_once(chunk, src, p)
                    except Exception:
                        mid = None
                    if not mid:
                        continue
                    # p -> tgt
                    try:
                        out2 = self._translate_once(mid, p, tgt)
                        translated = out2
                        break
                    except Exception:
                            # si p->tgt falla, pero tenemos mid, devolvemos mid SOLO si detectamos
                            # que mid ya está en el idioma destino (ej. el pivot ya produjo el
                            # resultado correcto). Esto evita devolver textos en italiano
                            # cuando el usuario pidió portugués.
                            try:
                                lang_mid = self._auto_detect(mid, fallback=None)
                            except Exception:
                                lang_mid = None
                            if lang_mid and lang_mid == tgt:
                                translated = mid
                                break
                            # intentar siguiente pivote para ver si da mejor resultado
                            continue

                if translated:
                    # post-procesos: si el destino es portugués aplicamos pequeñas
                    # transformaciones para acercar a pt-BR
                    if tgt == 'pt':
                        try:
                            translated = self._to_brazilian_pt(translated)
                        except Exception:
                            pass
                    yield translated
                    continue

                # Como último recurso devolvemos el chunk original (sin traducir)
                yield chunk

    # ---------- ASR (Whisper wrapper) ----------

    def transcribe_file(self, path: str) -> str:
        if asr_whisper is None:
            raise RuntimeError("ASR backend no disponible en el servidor")
        return asr_whisper.transcribe_file(path)

    def transcribe_b64(self, audio_b64: str) -> str:
        """
        Acepta base64 de audio en WAV/MP3/M4A (data URI o crudo).
        Si no es WAV, intenta convertir a WAV con ffmpeg si está disponible.
        """
        if not audio_b64:
            return ""

        if asr_whisper is None:
            raise RuntimeError("ASR backend no disponible en el servidor")

        # Quitar prefijo data URI si llega
        if audio_b64.startswith("data:"):
            try:
                audio_b64 = audio_b64.split(",", 1)[1]
            except Exception:
                pass

        try:
            data = base64.b64decode(audio_b64, validate=False)
        except Exception as e:
            raise RuntimeError(f"Audio base64 inválido: {e}")

        fd_in, tmp_in = tempfile.mkstemp(suffix=".blob")
        os.close(fd_in)
        with open(tmp_in, "wb") as f:
            f.write(data)

        tmp_wav = None
        try:
            # Si ya es wav, intenta directo
            try:
                return asr_whisper.transcribe_file(tmp_in)
            except Exception:
                # Intentar convertir a WAV (requiere ffmpeg en PATH)
                tmp_wav = tempfile.mktemp(suffix=".wav")
                import subprocess
                cmd = ["ffmpeg", "-y", "-i", tmp_in, "-ac", "1", "-ar", "16000", tmp_wav]
                subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
                return asr_whisper.transcribe_file(tmp_wav)
        finally:
            try:
                if os.path.exists(tmp_in):
                    os.remove(tmp_in)
            except Exception:
                pass
            try:
                if tmp_wav and os.path.exists(tmp_wav):
                    os.remove(tmp_wav)
            except Exception:
                pass
