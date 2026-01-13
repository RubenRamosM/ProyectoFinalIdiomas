import json
import base64
import tempfile
import os
import traceback
from typing import Optional

from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from asgiref.sync import sync_to_async

from ia.models import TranslatorSession
from ia.services.translator import TranslatorBackend
from ia.services import groq_translator

backend = TranslatorBackend()


def _unwrap_user(raw_user):
    """
    Convierte un UserLazyObject (de Channels) a una instancia real de User,
    o devuelve None si es anónimo.
    """
    try:
        wrapped = getattr(raw_user, "_wrapped", None)
        if wrapped is not None:
            raw_user = wrapped
    except Exception:
        pass

    try:
        if getattr(raw_user, "is_anonymous", True):
            return None
    except Exception:
        return None
    return raw_user


class TranslatorConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        # Aceptamos el handshake
        await self.accept()

        # Resolver usuario autenticado
        self.user = _unwrap_user(self.scope.get("user"))

        # 🔍 DEBUG: mostrar información de conexión
        print(">> CONNECTED USER:", self.user)
        if hasattr(self.user, "is_authenticated"):
            print(">> IS AUTHENTICATED:", self.user.is_authenticated)
        print(">> QUERY_STRING:", self.scope.get("query_string"))

        # Idiomas por defecto
        self.source_lang = "auto"
        self.target_lang = "en"

        # Buffer opcional para texto
        self._buffer = []

        # Crear sesión si hay usuario autenticado
        self.session: Optional[TranslatorSession] = None
        if self.user is not None:
            try:
                self.session = await self._create_session()
            except Exception as e:
                await self.send_json_safe({
                    "type": "warn",
                    "detail": f"No se pudo crear sesión de traducción: {e}"
                })

        # Handshake final
        await self.send_json_safe({
            "type": "ready",
            "auth": self.user is not None and getattr(self.user, "is_authenticated", False)
        })
        # Kick off model preload in background (non-blocking) so downloads don't
        # delay the websocket handshake. This starts a daemon thread in backend.
        try:
            backend.preload_models(self.source_lang, self.target_lang)
        except Exception:
            # non-fatal; preload best-effort
            pass

    async def receive(self, text_data=None, bytes_data=None):
        """
        Mensajes esperados:
          { "type": "config", "source_lang": "auto", "target_lang": "en" }
          { "type": "text",   "chunk": "Hola, ¿cómo estás?" }
          { "type": "audio",  "chunk_b64": "<...>" }
          { "type": "end" }
        """
        try:
            msg = json.loads(text_data or "{}")
        except Exception:
            await self.send_json_safe({"type": "error", "detail": "JSON inválido"})
            return

        t = msg.get("type")
        if t == "config":
            self.source_lang = msg.get("source_lang", "auto") or "auto"
            self.target_lang = msg.get("target_lang", "en") or "en"
            self._buffer = []
            await self.send_json_safe({"type": "ack", "status": "ok"})

        elif t == "text":
            chunk = msg.get("chunk", "")
            if not isinstance(chunk, str):
                await self.send_json_safe({"type": "error", "detail": "chunk debe ser string"})
                return
            self._buffer.append(chunk)

            # Si el mensaje proviene de OCR, intentar una limpieza con Groq antes
            if msg.get("ocr", False):
                try:
                    cleaned = await sync_to_async(lambda: groq_translator.clean_ocr_text(chunk))()
                    # si cambió, reemplazamos chunk por la versión limpia
                    if cleaned and cleaned.strip() != chunk.strip():
                        await self.send_json_safe({"type": "partial", "text": f"ocr_cleaned: {cleaned}"})
                        chunk = cleaned
                except Exception:
                    pass

            try:
                # Traducir usando backend (fuera del loop)
                partials = await sync_to_async(
                    lambda: list(backend.translate_stream([chunk], self.source_lang, self.target_lang))
                )()
                for out in partials:
                    await self.send_json_safe({"type": "partial", "text": out})
                # Enviar resultado final (concatenación de parciales)
                try:
                    final = "\n".join(partials) if partials else ""
                    await self.send_json_safe({"type": "done", "text": final})
                except Exception:
                    # no crítico — ya se enviaron parciales
                    pass
            except Exception as e:
                await self.send_json_safe({
                    "type": "error",
                    "detail": f"translation error: {e}"
                })

        elif t == "audio":
            b64 = msg.get("chunk_b64")
            if not b64:
                await self.send_json_safe({"type": "error", "detail": "no audio chunk provided"})
                return
            
            # Log incoming audio size for debugging
            audio_size = len(b64) if b64 else 0
            print(f"[AUDIO] Received audio data: {audio_size} bytes (base64)")
            
            tmp_path = None
            out_text = ""
            try:
                # Prefer backend.transcribe_b64 which can convert formats (ffmpeg) and
                # accepts data-URI or raw base64. This often handles non-wav uploads.
                try:
                    print(f"[AUDIO] Attempting transcribe_b64...")
                    out_text = await sync_to_async(lambda: backend.transcribe_b64(b64))()
                    print(f"[AUDIO] Transcription result: '{out_text}'")
                except Exception as e1:
                    # Fallback: decode and write to temp file and call transcribe_file
                    print(f"[AUDIO] transcribe_b64 failed: {e1}, trying fallback...")
                    if isinstance(b64, str) and b64.startswith("data:"):
                        try:
                            b64 = b64.split(",", 1)[1]
                        except Exception:
                            pass
                    data = base64.b64decode(b64)
                    print(f"[AUDIO] Decoded {len(data)} bytes of raw audio")
                    # Use generic extension, let ffmpeg detect format
                    fd, tmp_path = tempfile.mkstemp(suffix=".audio")
                    os.close(fd)
                    with open(tmp_path, "wb") as f:
                        f.write(data)
                    print(f"[AUDIO] Written to temp file: {tmp_path}")
                    out_text = await sync_to_async(backend.transcribe_file)(tmp_path)
                    print(f"[AUDIO] Transcription from file: '{out_text}'")

                # Traducir texto transcrito
                print(f"[AUDIO] Translating: '{out_text}' from {self.source_lang} to {self.target_lang}")
                partials = await sync_to_async(
                    lambda: list(backend.translate_stream([out_text], self.source_lang, self.target_lang))
                )()
                for p in partials:
                    await self.send_json_safe({"type": "partial", "text": p})

                final = "\n".join(partials)
                print(f"[AUDIO] Translation result: '{final}'")
                await self.send_json_safe({
                    "type": "done",
                    "text": final,
                    "transcription": out_text
                })

            except Exception as e:
                tb = traceback.format_exc()
                print(f"[AUDIO ERROR] {e}")
                print(f"[AUDIO ERROR TRACE] {tb}")
                # send an informative error so the client doesn't show an empty modal
                await self.send_json_safe({
                    "type": "error",
                    "detail": f"audio processing error: {e}",
                    "trace": tb
                })
            finally:
                if tmp_path and os.path.exists(tmp_path):
                    os.remove(tmp_path)

        elif t == "end":
            await self.send_json_safe({"type": "done"})

        else:
            await self.send_json_safe({"type": "error", "detail": f"Unknown message type: {t}"})

    async def disconnect(self, close_code):
        if self.session is not None:
            try:
                await self._close_session()
            except Exception:
                pass

    # -------------------------
    # Persistencia
    # -------------------------
    @database_sync_to_async
    def _create_session(self):
        """
        Crea un registro de sesión de traducción.
        """
        return TranslatorSession.objects.create(
            user=self.user,  # Puede ser None si el modelo lo permite
            source_lang=self.source_lang,
            target_lang=self.target_lang,
            is_active=True,
        )

    @database_sync_to_async
    def _close_session(self):
        """
        Marca la sesión como inactiva.
        """
        if not self.session:
            return
        try:
            self.session.is_active = False
            self.session.save(update_fields=["is_active"])
        except Exception:
            self.session.save()

    # -------------------------
    # Envío seguro de JSON
    # -------------------------
    async def send_json_safe(self, payload: dict):
        try:
            await self.send(text_data=json.dumps(payload))
        except Exception as e:
            print(f"send_json_safe error: {e}")
            try:
                await self.send(text_data=json.dumps({
                    "type": "error",
                    "detail": "send_json failed"
                }))
            except Exception:
                pass
