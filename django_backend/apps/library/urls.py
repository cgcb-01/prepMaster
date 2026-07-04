from django.urls import path
from . import views

urlpatterns = [
    path('', views.LibraryListView.as_view(), name='library-list'),
    path('add/', views.AddToLibraryView.as_view(), name='library-add'),
    path('<int:pk>/remove/', views.RemoveFromLibraryView.as_view(), name='library-remove'),
]
