from rest_framework import serializers, generics, views, permissions, status
from rest_framework.response import Response
from django.utils import timezone

from .models import TodoItem


class TodoItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = TodoItem
        fields = ['id', 'title', 'description', 'due_date', 'is_completed', 'completed_at']
        read_only_fields = ['completed_at']


class TodoListCreateView(generics.ListCreateAPIView):
    serializer_class = TodoItemSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return TodoItem.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class TodoCompleteView(views.APIView):
    """POST /api/todo/<id>/complete/"""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        todo = TodoItem.objects.get(id=pk, user=request.user)
        todo.is_completed = True
        todo.completed_at = timezone.now()
        todo.save(update_fields=['is_completed', 'completed_at'])
        return Response(TodoItemSerializer(todo).data)


class TodoDeleteView(generics.DestroyAPIView):
    serializer_class = TodoItemSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return TodoItem.objects.filter(user=self.request.user)
