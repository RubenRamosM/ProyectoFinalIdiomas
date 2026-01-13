"""Pequeño script de diagnóstico para ejecutar en el entorno (venv) del proyecto.
Ejecuta: python diagnose_asgi.py
Imprime si `channels` y `ia.routing` importan correctamente y si la construcción de
ProtocolTypeRouter falla, imprime el traceback completo.
"""
import traceback
import sys
import os

print('CWD:', os.getcwd())

try:
    import channels
    print('channels import ok, version=', getattr(channels, '__version__', 'unknown'))
except Exception:
    print('channels import FAILED')
    traceback.print_exc()

try:
    import ia.routing as ia_routing
    print('ia.routing import ok, websocket patterns=', len(getattr(ia_routing, 'websocket_urlpatterns', [])))
except Exception:
    print('ia.routing import FAILED')
    traceback.print_exc()

try:
    # Intentar construir el ProtocolTypeRouter similar a asgi.py
    from channels.routing import ProtocolTypeRouter, URLRouter
    from channels.auth import AuthMiddlewareStack
    import ia.routing as ia_routing
    ws_app = URLRouter(ia_routing.websocket_urlpatterns)
    application = ProtocolTypeRouter({
        'http': __import__('django.core.asgi').core.asgi.get_asgi_application(),
        'websocket': AuthMiddlewareStack(ws_app),
    })
    print('ProtocolTypeRouter constructed OK')
except Exception:
    print('ProtocolTypeRouter construction FAILED')
    traceback.print_exc()

print('Done')
