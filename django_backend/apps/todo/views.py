from rest_framework import serializers, generics, views, permissions, status
from rest_framework.response import Response
from django.utils import timezone

from .models import TodoItem


class TodoItemSerializer(serializers.ModelSerializer):
    display_title = serializers.CharField(read_only=True)
    module_type = serializers.CharField(source='module.module_type', read_only=True, default=None)
    chapter_name = serializers.CharField(source='module.chapter.name', read_only=True, default=None)
    is_module_linked = serializers.SerializerMethodField()

    class Meta:
        model = TodoItem
        fields = [
            'id', 'title', 'description', 'due_date', 'is_completed', 'completed_at',
            'module', 'display_title', 'module_type', 'chapter_name', 'is_module_linked',
        ]
        read_only_fields = ['completed_at']

    def get_is_module_linked(self, obj):
        return obj.module_id is not None

    def validate(self, data):
        # Need either a free-text title or a module — not neither.
        if not data.get('module') and not (data.get('title') or '').strip():
            raise serializers.ValidationError('Provide either a title or a module to attempt.')
        return data


class TodoListCreateView(generics.ListCreateAPIView):
    serializer_class = TodoItemSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return TodoItem.objects.filter(user=self.request.user).select_related('module', 'module__chapter')

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class TodoCompleteView(views.APIView):
    """
    POST /api/todo/<id>/complete/
    Manual completion — only valid for free-text (non-module) to-dos. A
    module-linked to-do can ONLY be completed by the server, once the
    linked paper is actually submitted (apps.todo.services); this endpoint
    rejects trying to fake that by ticking the box.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        todo = TodoItem.objects.get(id=pk, user=request.user)
        if todo.module_id:
            return Response(
                {'detail': 'This to-do is linked to a module — attempt and submit it to complete this automatically.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        todo.is_completed = True
        todo.completed_at = timezone.now()
        todo.save(update_fields=['is_completed', 'completed_at'])
        return Response(TodoItemSerializer(todo).data)


class TodoDeleteView(generics.DestroyAPIView):
    serializer_class = TodoItemSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return TodoItem.objects.filter(user=self.request.user)
