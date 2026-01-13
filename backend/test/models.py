from django.db import models


class TestQuestion(models.Model):
	TYPE_CHOICES = (
		('choice', 'Choice'),
		('speak', 'Speak'),
	)
	question = models.TextField()
	qtype = models.CharField(max_length=16, choices=TYPE_CHOICES, default='choice')
	order = models.PositiveIntegerField(default=0)

	class Meta:
		ordering = ['order']

	def __str__(self):
		return f"{self.order} - {self.question[:50]}"


class TestOption(models.Model):
	question = models.ForeignKey(TestQuestion, on_delete=models.CASCADE, related_name='options')
	text = models.CharField(max_length=256)
	is_correct = models.BooleanField(default=False)
	order = models.PositiveIntegerField(default=0)

	class Meta:
		ordering = ['order']

	def __str__(self):
		return f"{self.text} ({'ok' if self.is_correct else 'no'})"
