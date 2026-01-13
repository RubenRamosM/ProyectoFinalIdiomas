# ia/urls.py
from django.urls import path
from .api import LearningAIViewSet, TranslatorViewSet
from .views_tutor import (
    list_conversations,
    get_conversation,
    send_message,
    delete_conversation,
    clear_conversation
)

learning_record_attempt = LearningAIViewSet.as_view({'post': 'record_attempt'})
learning_srs_due = LearningAIViewSet.as_view({'get': 'srs_due'})
learning_recommendations = LearningAIViewSet.as_view({'get': 'recommendations'})

translator_translate = TranslatorViewSet.as_view({'post': 'translate'})

urlpatterns = [
    # EXACTO como los usa el front:
    path('record_attempt/', learning_record_attempt, name='ia-record-attempt'),
    path('srs_due/', learning_srs_due, name='ia-srs-due'),
    path('recommendations/', learning_recommendations, name='ia-recommendations'),

    # traductor simple (texto -> texto)
    path('translate/', translator_translate, name='ia-translate'),
    
    # Tutor inteligente
    path('tutor/conversations/', list_conversations, name='tutor-conversations-list'),
    path('tutor/conversations/<int:conversation_id>/', get_conversation, name='tutor-conversation-detail'),
    path('tutor/send/', send_message, name='tutor-send-message'),
    path('tutor/conversations/<int:conversation_id>/delete/', delete_conversation, name='tutor-conversation-delete'),
    path('tutor/conversations/<int:conversation_id>/clear/', clear_conversation, name='tutor-conversation-clear'),
]
