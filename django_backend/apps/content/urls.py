from django.urls import path
from . import views

urlpatterns = [
    path('subjects/', views.SubjectListView.as_view(), name='subject-list'),
    path('subjects/<int:subject_id>/chapters/', views.ChapterListView.as_view(), name='chapter-list'),
    path('chapters/<int:pk>/', views.ChapterDetailView.as_view(), name='chapter-detail'),
    path('syllabus/', views.SyllabusView.as_view(), name='syllabus'),
]