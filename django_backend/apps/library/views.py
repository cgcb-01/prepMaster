from rest_framework import serializers, generics, views, permissions, status
from rest_framework.response import Response
from .models import LibraryItem
from apps.exams.models import ExamPaper


class LibraryItemSerializer(serializers.ModelSerializer):
    paper_title = serializers.CharField(source='paper.title', read_only=True)

    class Meta:
        model = LibraryItem
        fields = ['id', 'paper', 'paper_title', 'downloaded_at', 'was_premium_at_download', 'still_accessible']


class LibraryListView(generics.ListAPIView):
    serializer_class = LibraryItemSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return LibraryItem.objects.filter(user=self.request.user).select_related('paper')


class AddToLibraryView(views.APIView):
    """POST /api/library/add/ { paper_id } — point #5."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        paper = ExamPaper.objects.get(id=request.data['paper_id'])
        if paper.paper_type in ('PAIC', 'BAIC') and paper.is_currently_running:
            return Response({'detail': 'Cannot save a live contest to Library while running.'}, status=status.HTTP_403_FORBIDDEN)

        item, _ = LibraryItem.objects.get_or_create(
            user=request.user, paper=paper,
            defaults={'was_premium_at_download': paper.is_premium},
        )
        return Response(LibraryItemSerializer(item).data, status=status.HTTP_201_CREATED)


class RemoveFromLibraryView(generics.DestroyAPIView):
    serializer_class = LibraryItemSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return LibraryItem.objects.filter(user=self.request.user)
