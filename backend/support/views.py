from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from .models import FAQ, SupportTicket
from .serializers import FAQSerializer, SupportTicketSerializer, CreateSupportTicketSerializer


class FAQViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet para listar FAQs (solo lectura)
    GET /api/support/faqs/ - Lista todas las FAQs activas
    GET /api/support/faqs/{id}/ - Detalle de una FAQ
    """
    queryset = FAQ.objects.filter(is_active=True)
    serializer_class = FAQSerializer
    permission_classes = []  # Público, no requiere autenticación

    def get_queryset(self):
        queryset = super().get_queryset()
        # Filtrar por categoría si se proporciona
        category = self.request.query_params.get('category', None)
        if category:
            queryset = queryset.filter(category=category)
        return queryset


class SupportTicketViewSet(viewsets.ModelViewSet):
    """
    ViewSet para gestionar tickets de soporte
    GET /api/support/tickets/ - Lista tickets del usuario autenticado
    POST /api/support/tickets/ - Crear nuevo ticket
    GET /api/support/tickets/{id}/ - Detalle de un ticket
    """
    serializer_class = SupportTicketSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        # Los usuarios solo ven sus propios tickets
        return SupportTicket.objects.filter(user=self.request.user)

    def get_serializer_class(self):
        if self.action == 'create':
            return CreateSupportTicketSerializer
        return SupportTicketSerializer

    def create(self, request, *args, **kwargs):
        """Crear un nuevo ticket de soporte"""
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        # Asignar el usuario autenticado al ticket
        ticket = serializer.save(user=request.user)

        # Retornar con el serializer completo
        response_serializer = SupportTicketSerializer(ticket)
        return Response(response_serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['get'])
    def my_tickets(self, request):
        """Endpoint adicional para obtener todos los tickets del usuario"""
        tickets = self.get_queryset()
        serializer = self.get_serializer(tickets, many=True)
        return Response(serializer.data)
