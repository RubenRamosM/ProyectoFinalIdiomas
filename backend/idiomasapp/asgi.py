import os
from django.core.asgi import get_asgi_application
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack
from channels.security.websocket import AllowedHostsOriginValidator

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'idiomasapp.settings')
django_asgi_app = get_asgi_application()

from ia import routing as ia_routing
from .querystring_auth import QueryStringJWTAuthMiddleware

application = ProtocolTypeRouter({
    "http": django_asgi_app,

    "websocket": AllowedHostsOriginValidator(
        AuthMiddlewareStack(  # <- primero Auth
            QueryStringJWTAuthMiddleware(  # <- luego tu middleware personalizado
                URLRouter(ia_routing.websocket_urlpatterns)
            )
        )
    ),
})

