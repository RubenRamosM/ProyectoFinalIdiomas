from django.contrib import admin
from .models import (
    ExerciseEmbedding,
    ExerciseAttempt,
    UserWeakness,
    RecommendationQueue,
    TranslatorSession,
    TutorConversation,
    TutorMessage
)


@admin.register(TutorConversation)
class TutorConversationAdmin(admin.ModelAdmin):
    list_display = ['id', 'user', 'title', 'target_language', 'created_at', 'updated_at', 'is_active']
    list_filter = ['is_active', 'target_language', 'created_at']
    search_fields = ['title', 'user__username', 'user__email']
    date_hierarchy = 'created_at'
    readonly_fields = ['created_at', 'updated_at']


@admin.register(TutorMessage)
class TutorMessageAdmin(admin.ModelAdmin):
    list_display = ['id', 'conversation', 'role', 'content_preview', 'created_at']
    list_filter = ['role', 'created_at']
    search_fields = ['content', 'conversation__title']
    date_hierarchy = 'created_at'
    
    def content_preview(self, obj):
        return obj.content[:100] + '...' if len(obj.content) > 100 else obj.content
    content_preview.short_description = 'Contenido'


# Registra otros modelos si aún no lo están
admin.site.register(ExerciseEmbedding)
admin.site.register(ExerciseAttempt)
admin.site.register(UserWeakness)
admin.site.register(RecommendationQueue)
admin.site.register(TranslatorSession)
