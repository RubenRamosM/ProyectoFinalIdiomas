# ia/serializers.py
from rest_framework import serializers
from .models import TutorConversation, TutorMessage


class TutorMessageSerializer(serializers.ModelSerializer):
    """Serializer para mensajes individuales del tutor."""
    
    class Meta:
        model = TutorMessage
        fields = ['id', 'role', 'content', 'audio_b64', 'created_at']
        read_only_fields = ['id', 'created_at']


class TutorConversationSerializer(serializers.ModelSerializer):
    """Serializer para conversaciones con el tutor."""
    messages = TutorMessageSerializer(many=True, read_only=True)
    message_count = serializers.SerializerMethodField()
    
    class Meta:
        model = TutorConversation
        fields = [
            'id', 
            'title', 
            'target_language', 
            'created_at', 
            'updated_at',
            'is_active',
            'messages',
            'message_count'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']
    
    def get_message_count(self, obj):
        return obj.messages.count()


class TutorConversationListSerializer(serializers.ModelSerializer):
    """Serializer simplificado para listar conversaciones."""
    message_count = serializers.SerializerMethodField()
    last_message = serializers.SerializerMethodField()
    
    class Meta:
        model = TutorConversation
        fields = [
            'id',
            'title',
            'target_language',
            'created_at',
            'updated_at',
            'is_active',
            'message_count',
            'last_message'
        ]
    
    def get_message_count(self, obj):
        return obj.messages.count()
    
    def get_last_message(self, obj):
        last = obj.messages.last()
        if last:
            return {
                'role': last.role,
                'content': last.content[:100],  # Primeros 100 caracteres
                'created_at': last.created_at
            }
        return None


class SendMessageSerializer(serializers.Serializer):
    """Serializer para enviar un mensaje al tutor."""
    message = serializers.CharField(max_length=2000, required=False, allow_blank=True)
    audio_b64 = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    audio_language = serializers.CharField(max_length=10, required=False, default='en')
    conversation_id = serializers.IntegerField(required=False, allow_null=True)
    
    def validate(self, data):
        # Al menos uno debe estar presente
        if not data.get('message') and not data.get('audio_b64'):
            raise serializers.ValidationError(
                "Debe proporcionar 'message' o 'audio_b64'."
            )
        return data
