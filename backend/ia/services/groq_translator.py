# ia/services/groq_translator.py
import os, hashlib, logging, uuid
from typing import List, Optional
from django.core.cache import cache
from groq import Groq

logger = logging.getLogger(__name__)

DEFAULT_MODEL = os.environ.get("GROQ_MODEL", "llama-3.3-70b-versatile")
API_KEY = os.environ.get("GROQ_API_KEY")

def _norm_lang(lang: Optional[str]) -> Optional[str]:
    if not lang:
        return None
    l = lang.strip().lower()
    if l == "auto":
        return None
    for sep in ("-", "_"):
        if sep in l:
            l = l.split(sep, 1)[0]
            break
    return l

def _k(text: str, src: Optional[str], tgt: Optional[str]) -> str:
    s = _norm_lang(src) or "auto"
    t = _norm_lang(tgt) or "auto"
    h = hashlib.sha1(f"{s}|{t}|{text}".encode("utf-8")).hexdigest()
    return f"gtr:{h}"

def _client() -> Optional[Groq]:
    if not API_KEY:
        logger.warning("GROQ_API_KEY ausente: devolviendo texto original sin traducir")
        return None
    try:
        return Groq(api_key=API_KEY)
    except Exception as e:
        logger.exception("No se pudo inicializar Groq: %s", e)
        return None

def translate_text(text: str, source: Optional[str], target: Optional[str], *, ttl_sec: int = 86400) -> str:
    if not text:
        return text
    s = _norm_lang(source)
    t = _norm_lang(target)
    if s and t and s == t:
        return text

    ck = _k(text, s, t)
    cached = cache.get(ck)
    if cached is not None:
        return cached

    client = _client()
    if not client:
        return text

    try:
        resp = client.chat.completions.create(
            model=DEFAULT_MODEL,
            temperature=0.0,
            messages=[
                {"role": "system",
                 "content": "Eres un traductor. Traduce EXACTAMENTE al idioma destino. Devuelve SOLO el texto traducido."},
                {"role": "user",
                 "content": f"Origen: {s or 'auto'}\nDestino: {t or 'auto'}\nTexto:\n{text}"},
            ],
        )
        out = (resp.choices[0].message.content or "").strip()
        if out:
            cache.set(ck, out, ttl_sec)
            return out
        logger.warning("Groq devolvió respuesta vacía; retorno original")
        return text
    except Exception as e:
        logger.exception("Error llamando a Groq: %s", e)
        return text

def translate_batch(texts: List[str], source: Optional[str], target: Optional[str], *, ttl_sec: int = 86400) -> List[str]:
    if not texts:
        return []
    token = f"<<§§§-{uuid.uuid4().hex}-§§§>>"
    joined = token.join([(t or "") for t in texts])
    try:
        translated = translate_text(joined, source, target, ttl_sec=ttl_sec)
        parts = translated.split(token)
        if len(parts) == len(texts):
            return [p.strip() for p in parts]
        logger.debug("Batch split mismatch (%s != %s). Cayendo a individuales.", len(parts), len(texts))
    except Exception:
        logger.exception("translate_batch falló; cayendo a individuales")
    return [translate_text(t or "", source, target, ttl_sec=ttl_sec) for t in texts]


def clean_ocr_text(text: str) -> str:
    """Usa Groq para limpiar/normalizar texto extraído por OCR.

    El modelo debe corregir errores típicos de OCR, unir líneas rotas,
    arreglar palabras mal segmentadas y devolver una versión limpia en el mismo idioma.
    """
    if not text:
        return text
    client = _client()
    if not client:
        return text
    try:
        resp = client.chat.completions.create(
            model=DEFAULT_MODEL,
            temperature=0.0,
            messages=[
                {
                    "role": "system",
                    "content": (
                        "Eres un asistente que corrige y normaliza texto extraído por OCR.\n"
                        "Recibe texto posiblemente con errores de reconocimiento, saltos de linea,\n"
                        "separaciones incorrectas y caracteres extraños. Devuelve SOLO la versión\n"
                        "corregida, respetando el idioma original y sin añadir explicaciones.\n"
                        "Si el texto está incompleto, intenta predecir razonablemente lo que se quiso decir."
                    ),
                },
                {"role": "user", "content": f"Texto OCR:\n{text}"},
            ],
        )
        out = (resp.choices[0].message.content or "").strip()
        if out:
            return out
        return text
    except Exception:
        logger.exception("clean_ocr_text: error llamando a Groq")
        return text
