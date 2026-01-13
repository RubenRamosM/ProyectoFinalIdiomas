from rest_framework import serializers
from .models import TestQuestion, TestOption


class TestOptionSerializer(serializers.ModelSerializer):
    class Meta:
        model = TestOption
        fields = ('id', 'text', 'is_correct')


class TestQuestionSerializer(serializers.ModelSerializer):
    options = TestOptionSerializer(many=True, read_only=True)

    class Meta:
        model = TestQuestion
        fields = ('id', 'question', 'qtype', 'order', 'options')
