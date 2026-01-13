from django.urls import path
from .views import RegisterView, MeView, UserStatsView, UserProgressView, LearningStatsView

urlpatterns = [
    path("register/", RegisterView.as_view(), name="users-register"),
    path("me/", MeView.as_view(), name="users-me"),
    path("stats/", UserStatsView.as_view(), name="users-stats"),
    path("progress/", UserProgressView.as_view(), name="users-progress"),
    path("learning-stats/", LearningStatsView.as_view(), name="users-learning-stats"),
]
