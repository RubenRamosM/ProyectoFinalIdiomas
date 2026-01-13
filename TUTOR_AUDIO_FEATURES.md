# Funcionalidades de Audio del Tutor Inteligente

## Características Implementadas

### 1. **Envío de Audio por el Usuario** 🎤

- Grabación de audio usando flutter_sound
- Conversión automática a base64
- Transcripción con Whisper en el backend
- Soporte para formato AAC

**Cómo usar:**

1. Presiona el botón del micrófono (🎤) en la parte inferior izquierda
2. Graba tu pregunta o pronunciación
3. Presiona el botón rojo de stop cuando termines
4. El audio se envía automáticamente al tutor

### 2. **Recepción de Audio del Tutor** 🔊

- Generación automática de audio TTS (Text-to-Speech) usando gTTS
- Detección inteligente con Groq para determinar cuándo generar audio
- Audio en formato MP3 codificado en base64

**El tutor genera audio cuando:**

- Responde con palabras o frases en inglés entre comillas
- Proporciona ejemplos de pronunciación
- Usa expresiones como "se dice...", "pronuncia...", etc.
- Groq detecta que la respuesta contiene contenido audible necesario

### 3. **Controles de Velocidad de Reproducción** ⚡

Tres velocidades disponibles:

- **0.75x** 🐢 Lento - Ideal para principiantes
- **1.0x** ▶️ Normal - Velocidad natural
- **1.25x** ⚡ Rápido - Para práctica avanzada

**Cómo cambiar la velocidad:**

1. Toca el botón de velocidad (⚙️) junto al audio
2. Selecciona la velocidad deseada
3. El audio se reproducirá automáticamente a la nueva velocidad

### 4. **Evaluación de Pronunciación** 📝

- Envía texto + audio para evaluación
- Whisper transcribe tu pronunciación
- Groq compara y califica tu pronunciación
- Recibes feedback constructivo con consejos

**Cómo usar:**

1. Escribe la palabra/frase que quieres practicar
2. Presiona el micrófono y pronúnciala
3. El tutor evaluará tu pronunciación y te dará consejos

## Flujo Técnico

### Backend (Django)

1. **Transcripción**: `ia/services/translator.py` → `transcribe_b64()`
2. **Generación TTS**: `ia/services/tutor_service.py` → `generate_tts_audio()`
3. **Detección inteligente**: `tutor_service.py` → `should_generate_audio()` (usa Groq)
4. **Evaluación**: `tutor_service.py` → `evaluate_pronunciation()`

### Frontend (Flutter)

1. **Grabación**: `flutter_sound` con codec AAC
2. **Reproducción**: `audioplayers` con control de velocidad
3. **UI**: Botones de play/stop, selector de velocidad
4. **Estado**: Indicadores visuales de reproducción activa

## Dependencias

### Backend

```python
gTTS==2.5.0          # Text-to-Speech
whisper              # ASR (ya instalado)
groq                 # IA conversacional
```

### Frontend

```yaml
flutter_sound: ^9.3.0 # Grabación de audio
audioplayers: ^6.5.1 # Reproducción con velocidad variable
permission_handler: ^11.3.1 # Permisos de micrófono
```

## Permisos Android

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE"/>
```

## Casos de Uso

### Caso 1: Preguntar pronunciación

**Usuario:** "¿Cómo se dice hasta luego en inglés?"
**Tutor:** "Se dice 'goodbye' o 'see you later'" + 🔊 Audio TTS

### Caso 2: Evaluar pronunciación

**Usuario:** (Escribe) "goodbye" + (Graba audio pronunciando)
**Tutor:** Evaluación detallada con calificación y consejos

### Caso 3: Práctica con velocidades

**Usuario:** Escucha "How are you doing today?" a 0.75x para entender mejor
**Usuario:** Escucha a 1.25x para acostumbrarse a velocidad nativa

## Notas Técnicas

- Audio temporal se guarda en `getTemporaryDirectory()` y se elimina después
- Formato de grabación: AAC (compatible con Whisper)
- Formato de reproducción: MP3 (generado por gTTS)
- Velocidad se mantiene entre reproducciones
- Detección de necesidad de TTS usa primeros 500 caracteres de respuesta
- Fallback: Si Groq falla, busca comillas en el texto

## Próximas Mejoras Posibles

1. Cache de audios TTS para respuestas comunes
2. Visualización de forma de onda durante grabación
3. Más velocidades de reproducción (0.5x, 1.5x, 2x)
4. Descarga de audios para práctica offline
5. Comparación visual de pronunciación (espectrograma)
6. Soporte para más idiomas en TTS
