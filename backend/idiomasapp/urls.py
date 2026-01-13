from django.contrib import admin
from django.urls import path, include
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

urlpatterns = [
    path("admin/", admin.site.urls),

    # --- API principales ---
    path("api/users/", include("users.urls")),
    path("api/lessons/", include("leccion.urls")),
    path("api/support/", include("support.urls")),

    # --- IA inteligente (recomendador + traductor ML) ---
    path("api/ia/", include("ia.urls")),
    path("api/test/", include("test.urls")),

    # --- Autenticación JWT ---
    path("api/auth/token/", TokenObtainPairView.as_view(), name="token_obtain_pair"),
    path("api/auth/token/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
]
