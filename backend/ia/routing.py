from django.urls import path, re_path
from .consumers import TranslatorConsumer


# Exponer varias variantes del endpoint WebSocket usadas por distintos clientes.
# Algunos clientes esperan `/api/ws/translator/`, otros `/api/ia/ws/translator/` o
# simplemente `/ws/translator/`. Usamos un `re_path` tolerante y dejamos entradas
# explícitas para mayor claridad.
websocket_urlpatterns = [
    # Flexible matcher: acepta /ws/translator/, /api/ws/translator/ y /api/ia/ws/translator/
    re_path(r'^/?(api/)?(ia/)?ws/translator/?$', TranslatorConsumer.as_asgi()),

    # Patrones explícitos (por compatibilidad y lectura)
    path('api/ia/ws/translator/', TranslatorConsumer.as_asgi()),
    path('api/ws/translator/', TranslatorConsumer.as_asgi()),
    path('ws/translator/', TranslatorConsumer.as_asgi()),
]
