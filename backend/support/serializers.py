from rest_framework import serializers
from .models import FAQ, SupportTicket


class FAQSerializer(serializers.ModelSerializer):
    """Serializer para FAQs"""
    category_display = serializers.CharField(source='get_category_display', read_only=True)

    class Meta:
        model = FAQ
        fields = ['id', 'question', 'answer', 'category', 'category_display', 'order', 'created_at']


class SupportTicketSerializer(serializers.ModelSerializer):
    """Serializer para Tickets de Soporte"""
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    user_email = serializers.EmailField(source='user.email', read_only=True)
    user_username = serializers.CharField(source='user.username', read_only=True)

    class Meta:
        model = SupportTicket
        fields = [
            'id',
            'user',
            'user_username',
            'user_email',
            'subject',
            'message',
            'status',
            'status_display',
            'admin_response',
            'created_at',
            'updated_at'
        ]
        read_only_fields = ['user', 'status', 'admin_response', 'created_at', 'updated_at']


class CreateSupportTicketSerializer(serializers.ModelSerializer):
    """Serializer para crear un nuevo ticket"""
    class Meta:
        model = SupportTicket
        fields = ['subject', 'message']

    def create(self, validated_data):
        # El usuario se obtiene del request en la vista
        return SupportTicket.objects.create(**validated_data)
