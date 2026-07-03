from django.urls import path
from . import views

urlpatterns = [
    path('start/', views.StartProctoringView.as_view(), name='proctoring-start'),
    path('<int:session_id>/flag/', views.SubmitProctoringFlagView.as_view(), name='proctoring-flag'),
    path('<int:session_id>/end/', views.EndProctoringView.as_view(), name='proctoring-end'),
]