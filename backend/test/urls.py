from django.urls import path
from .views import PlacementQuestionsView, PlacementSubmitView

urlpatterns = [
    path('placement/', PlacementQuestionsView.as_view(), name='placement-questions'),
    path('placement/submit/', PlacementSubmitView.as_view(), name='placement-submit'),
]
