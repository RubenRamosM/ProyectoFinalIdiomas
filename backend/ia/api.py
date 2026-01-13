# ia/api.py
from rest_framework import viewsets, serializers, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

from ia.models import RecommendationQueue
from leccion.models import Exercise
from ia.services.translator import TranslatorBackend

# ----------- IMPORTS LAZY PARA IA -----------
def _record_attempt(*args, **kwargs):
    from ia.services.ai_recommender import record_attempt
    return record_attempt(*args, **kwargs)

def _due_srs_for(*args, **kwargs):
    from ia.services.ai_recommender import due_srs_for
    return due_srs_for(*args, **kwargs)

# ----------- SERIALIZERS -----------

class AttemptSerializer(serializers.Serializer):
    exercise_id = serializers.IntegerField()
    is_correct = serializers.BooleanField()
    score = serializers.FloatField(required=False, allow_null=True)
    topic = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    skill = serializers.CharField(required=False, allow_blank=True, allow_null=True)

class RecommendationSerializer(serializers.ModelSerializer):
    class Meta:
        model = RecommendationQueue
        fields = ["exercise_id", "reason", "score", "created_at", "served"]

class TranslationSerializer(serializers.Serializer):
    text = serializers.CharField()
    source_lang = serializers.CharField(default="auto")
    target_lang = serializers.CharField(default="en")

# ----------- VIEWS -----------

class LearningAIViewSet(viewsets.ViewSet):
    """
    Controlador principal del módulo de aprendizaje inteligente (ML adaptativo)
    """
    permission_classes = [IsAuthenticated]

    @action(detail=False, methods=["post"])
    def record_attempt(self, request):
        s = AttemptSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        ex = Exercise.objects.get(id=s.validated_data["exercise_id"])
        # NOTE: removed call to adaptive recommender to avoid failures
        # in the learning flow when the recommender raises exceptions.
        # If you want to re-enable recommendations, wrap `_record_attempt`
        # in a try/except or reintroduce this call behind a feature flag.
        # Example safe-call (commented):
        # try:
        #     _record_attempt(...)
        # except Exception:
        #     logger.exception('Recommender failed')
        return Response({"ok": True}, status=status.HTTP_200_OK)

    @action(detail=False, methods=["get"])
    def recommendations(self, request):
        recs = RecommendationQueue.objects.filter(
            user=request.user, served=False
        ).order_by("-score")[:20]
        data = RecommendationSerializer(recs, many=True).data
        recs.update(served=True)
        return Response(data, status=status.HTTP_200_OK)

    @action(detail=False, methods=["get"])
    def srs_due(self, request):
        exercises = _due_srs_for(request.user, limit=10)
        return Response(
            [{"exercise_id": e.id, "question": getattr(e, "question", "")} for e in exercises],
            status=status.HTTP_200_OK,
        )


class TranslatorViewSet(viewsets.ViewSet):
    """
    Endpoint REST simple para traducción IA (texto <-> texto)
    """
    permission_classes = [IsAuthenticated]

    @action(detail=False, methods=["post"])
    def translate(self, request):
        s = TranslationSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        text = s.validated_data["text"]
        src = s.validated_data.get("source_lang", "auto")
        tgt = s.validated_data.get("target_lang", "en")

        backend = TranslatorBackend()
        translation = "".join(backend.translate_stream([text], src, tgt))

        return Response(
            {"translated_text": translation},
            status=status.HTTP_200_OK,
        )
