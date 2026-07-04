from django.urls import path
from . import views

urlpatterns = [
    path('library/manifest/', views.LibraryManifestView.as_view(), name='sync-library-manifest'),
    path('attempts/push/', views.PushOfflineAttemptsView.as_view(), name='sync-push-attempts'),
]
