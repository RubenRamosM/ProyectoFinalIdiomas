from django.contrib import admin
from .models import TestQuestion, TestOption


class TestOptionInline(admin.TabularInline):
	model = TestOption
	extra = 1


@admin.register(TestQuestion)
class TestQuestionAdmin(admin.ModelAdmin):
	list_display = ('order', 'question', 'qtype')
	inlines = (TestOptionInline,)
	ordering = ('order',)


@admin.register(TestOption)
class TestOptionAdmin(admin.ModelAdmin):
	list_display = ('question', 'text', 'is_correct', 'order')
	list_filter = ('is_correct',)
