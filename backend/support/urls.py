from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import FAQViewSet, SupportTicketViewSet

router = DefaultRouter()
router.register(r'faqs', FAQViewSet, basename='faq')
router.register(r'tickets', SupportTicketViewSet, basename='ticket')

urlpatterns = [
    path('', include(router.urls)),
]
