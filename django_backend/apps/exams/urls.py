from django.urls import path
from . import views

urlpatterns = [
    path('papers/', views.ExamPaperListView.as_view(), name='paper-list'),
    path('papers/<int:pk>/', views.ExamPaperDetailView.as_view(), name='paper-detail'),
    path('papers/<int:pk>/start/', views.StartAttemptView.as_view(), name='paper-start'),
    path('papers/<int:pk>/download/', views.DownloadPaperView.as_view(), name='paper-download'),
    path('attempts/<int:attempt_id>/answer/<int:question_id>/', views.SubmitAnswerView.as_view(), name='attempt-answer'),
    path('attempts/<int:attempt_id>/submit/', views.SubmitAttemptView.as_view(), name='attempt-submit'),
]