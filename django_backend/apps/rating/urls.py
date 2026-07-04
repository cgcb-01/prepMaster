from django.urls import path
from .views import RatingGraphView

urlpatterns = [
    path('history/', RatingGraphView.as_view(), name='rating-history'),
]
