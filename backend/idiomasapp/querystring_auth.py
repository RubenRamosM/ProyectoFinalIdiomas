# idiomasapp/querystring_auth.py
from urllib.parse import parse_qs
from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser
from rest_framework_simplejwt.authentication import JWTAuthentication

@database_sync_to_async
def _user_from_token(token: str):
    try:
        auth = JWTAuthentication()
        validated = auth.get_validated_token(token)
        return auth.get_user(validated)
    except Exception:
        return AnonymousUser()

def _get_header(headers: list[tuple[bytes, bytes]], key: bytes) -> str | None:
    for k, v in headers or []:
        if k.lower() == key:
            try:
                return v.decode("utf-8", "ignore")
            except Exception:
                return None
    return None

class QueryStringJWTAuthMiddleware:
    """
    Lee el JWT desde:
      - query param ?token=<JWT>
      - o header 'Authorization: Bearer <JWT>'
    y setea scope['user'] con el usuario autenticado.
    """
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        scope = dict(scope)
        token = None

        # 1) Query param ?token=
        try:
            raw_qs = (scope.get("query_string") or b"").decode("utf-8", "ignore")
            qs = parse_qs(raw_qs)
            token = (qs.get("token") or [None])[0]
        except Exception:
            token = None

        # 2) Header Authorization: Bearer xxx (opcional)
        if not token:
            auth_header = _get_header(scope.get("headers"), b"authorization")
            if auth_header and auth_header.lower().startswith("bearer "):
                token = auth_header.split(" ", 1)[1].strip()

        # Resolver usuario
        if token:
            try:
                # Log token presence (masked) for debugging in development only
                try:
                    import sys
                    masked = (token[:8] + '...') if isinstance(token, str) and len(token) > 8 else token
                    sys.stderr.write(f"QueryStringJWTAuthMiddleware: token provided (masked)={masked}\n")
                except Exception:
                    pass

                user = await _user_from_token(token)
                scope["user"] = user
                try:
                    import sys
                    uname = getattr(user, 'username', None)
                    sys.stderr.write(f"QueryStringJWTAuthMiddleware: resolved user={uname}\n")
                except Exception:
                    pass
            except Exception:
                # If token validation failed, leave scope user as anonymous
                try:
                    import sys
                    sys.stderr.write('QueryStringJWTAuthMiddleware: token validation failed\n')
                except Exception:
                    pass

        return await self.app(scope, receive, send)
