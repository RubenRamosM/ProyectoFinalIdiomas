# ia/views_tutor.py
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.pagination import PageNumberPagination
from django.shortcuts import get_object_or_404
from django.db import transaction

from .models import TutorConversation, TutorMessage
from .serializers import (
    TutorConversationSerializer,
    TutorConversationListSerializer,
    SendMessageSerializer,
    TutorMessageSerializer
)
from .services.tutor_service import (
    chat_with_tutor, 
    generate_conversation_title,
    generate_tts_audio,
    evaluate_pronunciation,
    should_generate_audio
)
from .services.translator import TranslatorBackend

import logging
logger = logging.getLogger(__name__)

# Instancia global del backend de traducción/ASR
_translator_backend = TranslatorBackend()


class ConversationPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_conversations(request):
    """
    Lista todas las conversaciones del usuario autenticado.
    
    GET /api/tutor/conversations/
    Query params:
        - page: número de página
        - page_size: tamaño de página (default 20)
        - active_only: true/false (filtrar solo activas)
    """
    user = request.user
    active_only = request.query_params.get('active_only', 'false').lower() == 'true'
    
    conversations = TutorConversation.objects.filter(user=user)
    
    if active_only:
        conversations = conversations.filter(is_active=True)
    
    paginator = ConversationPagination()
    page = paginator.paginate_queryset(conversations, request)
    
    if page is not None:
        serializer = TutorConversationListSerializer(page, many=True)
        return paginator.get_paginated_response(serializer.data)
    
    serializer = TutorConversationListSerializer(conversations, many=True)
    return Response(serializer.data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_conversation(request, conversation_id):
    """
    Obtiene una conversación específica con todos sus mensajes.
    
    GET /api/tutor/conversations/{id}/
    """
    conversation = get_object_or_404(
        TutorConversation,
        id=conversation_id,
        user=request.user
    )
    
    serializer = TutorConversationSerializer(conversation)
    return Response(serializer.data)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_message(request):
    """
    Envía un mensaje al tutor y obtiene una respuesta.
    
    POST /api/tutor/send/
    Body:
        {
            "message": "¿Cómo se dice 'hello' en francés?",  // opcional si hay audio
            "audio_b64": "base64_encoded_audio",  // opcional
            "audio_language": "en",  // idioma del audio (default: en)
            "conversation_id": 123  // opcional, si no se provee crea nueva conversación
        }
    
    Response:
        {
            "conversation_id": 123,
            "conversation_title": "...",
            "user_message": {...},
            "assistant_message": {...}  // incluye audio_b64 si es apropiado
        }
    """
    serializer = SendMessageSerializer(data=request.data)
    
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    user = request.user
    message_text = serializer.validated_data.get('message', '').strip()
    audio_b64 = serializer.validated_data.get('audio_b64')
    audio_language = serializer.validated_data.get('audio_language', 'en')
    conversation_id = serializer.validated_data.get('conversation_id')
    
    # Variables para el flujo
    transcribed_text = None
    is_pronunciation_check = False
    
    try:
        # Si hay audio, transcribirlo
        if audio_b64:
            try:
                transcribed_text = _translator_backend.transcribe_b64(audio_b64)
                logger.info(f"Audio transcrito: {transcribed_text}")
                
                # Si el usuario envió texto Y audio, es evaluación de pronunciación
                if message_text:
                    is_pronunciation_check = True
                else:
                    # Solo audio sin texto: usar transcripción como mensaje
                    message_text = transcribed_text
                    
            except Exception as e:
                logger.exception(f"Error transcribiendo audio: {e}")
                return Response(
                    {'error': 'No pude procesar el audio. Asegúrate de enviar un formato válido (WAV, MP3, M4A).'},
                    status=status.HTTP_400_BAD_REQUEST
                )
        
        if not message_text:
            return Response(
                {'error': 'Debes proporcionar un mensaje de texto o audio.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Obtener el idioma objetivo del usuario
        target_language = getattr(user, 'target_language', 'inglés')
        if not target_language or target_language == 'en':
            target_language = 'inglés'
        elif target_language == 'es':
            target_language = 'español'
        elif target_language == 'pt':
            target_language = 'portugués'
        elif target_language == 'fr':
            target_language = 'francés'
        elif target_language == 'de':
            target_language = 'alemán'
        elif target_language == 'it':
            target_language = 'italiano'
        
        with transaction.atomic():
            # Obtener o crear conversación
            if conversation_id:
                conversation = get_object_or_404(
                    TutorConversation,
                    id=conversation_id,
                    user=user
                )
            else:
                # Crear nueva conversación
                conversation = TutorConversation.objects.create(
                    user=user,
                    target_language=target_language,
                    title='Nueva conversación'  # Se actualizará después
                )
            
            # Guardar mensaje del usuario
            user_message_content = message_text
            if is_pronunciation_check:
                user_message_content = f"🎤 [Audio pronunciando: {message_text}]"
            
            user_message = TutorMessage.objects.create(
                conversation=conversation,
                role='user',
                content=user_message_content
            )
            
            # Obtener historial de la conversación (últimos 10 mensajes antes del actual)
            history_messages = TutorMessage.objects.filter(
                conversation=conversation
            ).exclude(id=user_message.id).order_by('-created_at')[:10]
            
            # Convertir a formato para tutor_service
            conversation_history = [
                {
                    'role': msg.role,
                    'content': msg.content
                }
                for msg in reversed(list(history_messages))
            ]
            
            # Determinar respuesta según el caso
            tutor_response = None
            response_audio_b64 = None
            
            if is_pronunciation_check:
                # Caso: Usuario quiere evaluación de pronunciación
                tutor_response = evaluate_pronunciation(
                    transcribed_text=transcribed_text,
                    expected_text=message_text,
                    target_language=target_language
                )
            else:
                # Caso normal: conversación con el tutor
                tutor_response = chat_with_tutor(
                    message=message_text,
                    conversation_history=conversation_history,
                    user_target_language=target_language
                )
                
                # Usar Groq para detectar si necesita audio TTS
                if should_generate_audio(tutor_response, target_language):
                    # Generar audio TTS para la respuesta
                    tts_lang_code = audio_language  # Usar el idioma que el usuario está aprendiendo
                    response_audio_b64 = generate_tts_audio(tutor_response, language=tts_lang_code)
                    logger.info(f"Audio TTS generado para respuesta con {len(tutor_response)} caracteres")
                else:
                    logger.info("No se detectó necesidad de audio TTS para esta respuesta")
            
            # Guardar respuesta del tutor
            assistant_message = TutorMessage.objects.create(
                conversation=conversation,
                role='assistant',
                content=tutor_response,
                audio_b64=response_audio_b64
            )
            
            # Si es el primer mensaje, generar título para la conversación
            if conversation.messages.count() == 2:  # user + assistant
                try:
                    title = generate_conversation_title(message_text)
                    conversation.title = title
                    conversation.save()
                except Exception as e:
                    logger.warning(f"No se pudo generar título: {e}")
            
            # Actualizar updated_at
            conversation.save()
        
        # Serializar respuesta
        return Response({
            'conversation_id': conversation.id,
            'conversation_title': conversation.title,
            'user_message': TutorMessageSerializer(user_message).data,
            'assistant_message': TutorMessageSerializer(assistant_message).data
        }, status=status.HTTP_201_CREATED)
        
    except Exception as e:
        logger.exception(f"Error en send_message: {e}")
        return Response(
            {'error': 'Ocurrió un error al procesar tu mensaje. Por favor intenta nuevamente.'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_conversation(request, conversation_id):
    """
    Marca una conversación como inactiva (soft delete).
    
    DELETE /api/tutor/conversations/{id}/
    """
    conversation = get_object_or_404(
        TutorConversation,
        id=conversation_id,
        user=request.user
    )
    
    conversation.is_active = False
    conversation.save()
    
    return Response({'message': 'Conversación eliminada exitosamente'}, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def clear_conversation(request, conversation_id):
    """
    Elimina todos los mensajes de una conversación.
    
    POST /api/tutor/conversations/{id}/clear/
    """
    conversation = get_object_or_404(
        TutorConversation,
        id=conversation_id,
        user=request.user
    )
    
    conversation.messages.all().delete()
    conversation.title = 'Nueva conversación'
    conversation.save()
    
    return Response({'message': 'Conversación limpiada exitosamente'}, status=status.HTTP_200_OK)
