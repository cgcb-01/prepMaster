from django.urls import path
from . import views

urlpatterns = [
    path('', views.TodoListCreateView.as_view(), name='todo-list-create'),
    path('<int:pk>/complete/', views.TodoCompleteView.as_view(), name='todo-complete'),
    path('<int:pk>/delete/', views.TodoDeleteView.as_view(), name='todo-delete'),
]