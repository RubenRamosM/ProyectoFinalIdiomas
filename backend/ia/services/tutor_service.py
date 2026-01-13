# ia/services/tutor_service.py
import os
import logging
import base64
import tempfile
from typing import List, Dict, Optional
from groq import Groq

logger = logging.getLogger(__name__)

DEFAULT_MODEL = os.environ.get("GROQ_MODEL", "llama-3.3-70b-versatile")
API_KEY = os.environ.get("GROQ_API_KEY")


def _get_client() -> Optional[Groq]:
    """Inicializa y retorna el cliente de Groq."""
    if not API_KEY:
        logger.warning("GROQ_API_KEY no configurada")
        return None
    try:
        return Groq(api_key=API_KEY)
    except Exception as e:
        logger.exception("Error inicializando Groq: %s", e)
        return None


def get_tutor_system_prompt(user_target_language: str = "inglés") -> str:
    """
    Genera el prompt del sistema para el tutor inteligente.
    
    Args:
        user_target_language: El idioma que el usuario está aprendiendo
    
    Returns:
        El prompt del sistema optimizado para el tutor
    """
    return f"""Eres un tutor de idiomas inteligente, amigable y paciente que está disponible 24/7 para ayudar a estudiantes a aprender {user_target_language}.

Tu objetivo principal es:
- Responder consultas sobre gramática, vocabulario, pronunciación y cultura
- Explicar conceptos de forma clara y concisa
- Proporcionar ejemplos prácticos y contextualizados
- Corregir errores de forma constructiva
- Adaptar tus respuestas al nivel del estudiante
- Motivar y alentar el aprendizaje continuo
- Sugerir ejercicios y prácticas cuando sea relevante

Directrices importantes:
1. Usa un tono amigable, motivador y profesional
2. Proporciona explicaciones claras y estructuradas
3. Da ejemplos relevantes cuando expliques conceptos
4. Si el estudiante comete errores, corrígelos de forma amable y explica por qué
5. Adapta la complejidad de tus respuestas al nivel que detectes
6. Usa emojis ocasionalmente para hacer la conversación más amena 😊
7. Si no sabes algo con certeza, admítelo honestamente
8. Mantén las respuestas concisas pero completas (máximo 300 palabras por respuesta)
9. Ofrece recursos adicionales o ejercicios cuando sea apropiado

Recuerda: Tu misión es hacer que el aprendizaje de idiomas sea accesible, efectivo y divertido."""


def chat_with_tutor(
    message: str,
    conversation_history: List[Dict[str, str]] = None,
    user_target_language: str = "inglés",
    temperature: float = 0.7,
    max_tokens: int = 1024
) -> str:
    """
    Interactúa con el tutor inteligente usando Groq.
    
    Args:
        message: El mensaje del usuario
        conversation_history: Lista de mensajes previos [{"role": "user"/"assistant", "content": "..."}]
        user_target_language: El idioma que está aprendiendo el usuario
        temperature: Creatividad de la respuesta (0.0-1.0)
        max_tokens: Máximo de tokens en la respuesta
    
    Returns:
        La respuesta del tutor
    """
    if not message or not message.strip():
        return "Por favor, escribe tu pregunta o consulta. 😊"
    
    client = _get_client()
    if not client:
        return "Lo siento, el servicio de tutoría no está disponible en este momento. Por favor, intenta más tarde."
    
    # Construir el historial de mensajes
    messages = [
        {
            "role": "system",
            "content": get_tutor_system_prompt(user_target_language)
        }
    ]
    
    # Agregar historial previo (limitado a últimos 10 mensajes para no exceder contexto)
    if conversation_history:
        recent_history = conversation_history[-10:]
        messages.extend(recent_history)
    
    # Agregar mensaje actual del usuario
    messages.append({
        "role": "user",
        "content": message.strip()
    })
    
    try:
        response = client.chat.completions.create(
            model=DEFAULT_MODEL,
            temperature=temperature,
            max_tokens=max_tokens,
            messages=messages,
        )
        
        answer = (response.choices[0].message.content or "").strip()
        
        if not answer:
            logger.warning("Groq devolvió respuesta vacía para mensaje: %s", message[:50])
            return "Lo siento, no pude generar una respuesta. ¿Podrías reformular tu pregunta?"
        
        return answer
        
    except Exception as e:
        logger.exception("Error en chat_with_tutor: %s", e)
        return "Disculpa, ocurrió un error al procesar tu consulta. Por favor, intenta nuevamente."


def generate_conversation_title(first_message: str) -> str:
    """
    Genera un título breve para la conversación basado en el primer mensaje.
    
    Args:
        first_message: El primer mensaje del usuario
    
    Returns:
        Un título descriptivo de máximo 50 caracteres
    """
    if not first_message or not first_message.strip():
        return "Nueva conversación"
    
    client = _get_client()
    if not client:
        # Fallback: usar los primeros 50 caracteres
        return first_message.strip()[:50]
    
    try:
        response = client.chat.completions.create(
            model=DEFAULT_MODEL,
            temperature=0.3,
            max_tokens=20,
            messages=[
                {
                    "role": "system",
                    "content": "Genera un título descriptivo y conciso (máximo 5 palabras) para esta conversación. Responde SOLO con el título, sin comillas ni puntuación adicional."
                },
                {
                    "role": "user",
                    "content": f"Primera consulta del usuario: {first_message[:200]}"
                }
            ],
        )
        
        title = (response.choices[0].message.content or "").strip()
        
        # Limpiar comillas si las hay
        title = title.strip('"').strip("'")
        
        # Limitar a 50 caracteres
        if len(title) > 50:
            title = title[:47] + "..."
        
        return title if title else first_message.strip()[:50]
        
    except Exception as e:
        logger.exception("Error generando título: %s", e)
        return first_message.strip()[:50]


def generate_tts_audio(text: str, language: str = "en") -> Optional[str]:
    """
    Genera audio TTS usando gTTS y lo devuelve en base64.
    
    Args:
        text: El texto a convertir en audio
        language: Código de idioma (en, es, fr, etc.)
    
    Returns:
        Audio en base64 o None si falla
    """
    try:
        from gtts import gTTS
        
        if not text or not text.strip():
            return None
        
        # Crear archivo temporal
        fd, tmp_path = tempfile.mkstemp(suffix=".mp3")
        os.close(fd)
        
        try:
            # Generar TTS
            tts = gTTS(text=text.strip(), lang=language, slow=False)
            tts.save(tmp_path)
            
            # Leer y convertir a base64
            with open(tmp_path, "rb") as f:
                audio_bytes = f.read()
                audio_b64 = base64.b64encode(audio_bytes).decode('utf-8')
                return audio_b64
                
        finally:
            # Limpiar archivo temporal
            try:
                if os.path.exists(tmp_path):
                    os.remove(tmp_path)
            except Exception:
                pass
                
    except ImportError:
        logger.warning("gTTS no está instalado. Instala con: pip install gTTS")
        return None
    except Exception as e:
        logger.exception("Error generando TTS: %s", e)
        return None


def evaluate_pronunciation(
    transcribed_text: str,
    expected_text: str,
    target_language: str = "inglés"
) -> str:
    """
    Evalúa la pronunciación del usuario comparando transcripción con texto esperado.
    
    Args:
        transcribed_text: Lo que Whisper transcribió del audio del usuario
        expected_text: El texto que el usuario intentaba pronunciar
        target_language: Idioma objetivo
    
    Returns:
        Evaluación y consejos de pronunciación
    """
    if not transcribed_text or not transcribed_text.strip():
        return "No pude escuchar audio claro. Por favor, intenta grabar nuevamente en un lugar más silencioso. 🎤"
    
    client = _get_client()
    if not client:
        return "El servicio de evaluación no está disponible. Por favor, intenta más tarde."
    
    try:
        response = client.chat.completions.create(
            model=DEFAULT_MODEL,
            temperature=0.5,
            max_tokens=400,
            messages=[
                {
                    "role": "system",
                    "content": f"""Eres un tutor experto en pronunciación de {target_language}. 
Compara lo que el usuario dijo (transcripción) con lo que intentaba decir (texto esperado).
Da una calificación constructiva:
1. Precisión: qué tan cerca estuvo
2. Errores específicos (si los hay)
3. Consejos prácticos para mejorar
4. Motivación

Usa un tono amable y motivador. Máximo 150 palabras."""
                },
                {
                    "role": "user",
                    "content": f"""Texto que intentaba pronunciar: "{expected_text}"
Transcripción de lo que dijo: "{transcribed_text}"

Por favor, evalúa la pronunciación."""
                }
            ],
        )
        
        evaluation = (response.choices[0].message.content or "").strip()
        return evaluation if evaluation else "No pude evaluar la pronunciación. Intenta nuevamente."
        
    except Exception as e:
        logger.exception("Error evaluando pronunciación: %s", e)
        return "Ocurrió un error al evaluar tu pronunciación. Por favor, intenta nuevamente."


def should_generate_audio(response_text: str, target_language: str = "inglés") -> bool:
    """
    Usa Groq para determinar si la respuesta del tutor contiene ejemplos
    en el idioma objetivo que necesitan pronunciación en audio.
    
    Args:
        response_text: La respuesta del tutor
        target_language: El idioma que está aprendiendo el usuario
    
    Returns:
        True si debe generar audio, False si no
    """
    if not response_text or len(response_text.strip()) < 10:
        return False
    
    client = _get_client()
    if not client:
        return False
    
    try:
        response = client.chat.completions.create(
            model=DEFAULT_MODEL,
            temperature=0.3,
            max_tokens=10,
            messages=[
                {
                    "role": "system",
                    "content": f"""Analiza si el texto contiene palabras, frases o ejemplos en {target_language} que un estudiante necesitaría escuchar para aprender la pronunciación correcta.

Responde SOLO con "SI" o "NO".

Ejemplos que necesitan audio:
- "Se dice 'goodbye'"
- "Hello se pronuncia..."
- "La frase es 'How are you?'"
- Cualquier palabra/frase en {target_language} entre comillas

Ejemplos que NO necesitan audio:
- Explicaciones de gramática sin ejemplos
- Respuestas solo en español
- Conceptos teóricos"""
                },
                {
                    "role": "user",
                    "content": response_text[:500]  # Primeros 500 caracteres
                }
            ],
        )
        
        decision = (response.choices[0].message.content or "").strip().upper()
        return decision == "SI"
        
    except Exception as e:
        logger.exception("Error detectando necesidad de audio: %s", e)
        # Fallback: buscar comillas que suelen indicar ejemplos
        return "'" in response_text or '"' in response_text
