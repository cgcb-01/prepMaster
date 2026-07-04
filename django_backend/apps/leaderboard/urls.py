from django.urls import path
from .views import GlobalLeaderboardView

urlpatterns = [
    path('global/', GlobalLeaderboardView.as_view(), name='leaderboard-global'),
]
