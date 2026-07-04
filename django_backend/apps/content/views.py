from rest_framework import generics, permissions, views
from rest_framework.response import Response
from django.db.models import Count, Q

from .models import Subject, Chapter, Module
from .serializers import SubjectSerializer, ChapterListSerializer, ChapterDetailSerializer


class SubjectListView(generics.ListAPIView):
    """GET /api/content/subjects/?exam=JEE  — Stage 1 subject cards."""
    serializer_class = SubjectSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = Subject.objects.annotate(chapter_count=Count('chapters'))
        exam = self.request.query_params.get('exam')
        if exam:
            qs = qs.filter(exam=exam)
        return qs


class ChapterListView(generics.ListAPIView):
    """
    GET /api/content/subjects/<subject_id>/chapters/?class=12
    Stage 2 — chapter list, restricted to the user's class per point #13
    unless viewing the syllabus-only (public) endpoint.
    """
    serializer_class = ChapterListSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = Chapter.objects.filter(subject_id=self.kwargs['subject_id'])
        class_level = self.request.query_params.get('class', self.request.user.student_class)
        qs = qs.filter(class_level=class_level)

        # Annotate per-user module completion once submissions app is wired;
        # placeholder counts here so the frontend contract is stable.
        qs = qs.annotate(modules_total=Count('modules'))
        return qs


class ChapterDetailView(generics.RetrieveAPIView):
    """GET /api/content/chapters/<id>/ — Stage 3 module tiles."""
    queryset = Chapter.objects.prefetch_related('modules')
    serializer_class = ChapterDetailSerializer
    permission_classes = [permissions.IsAuthenticated]
class AnnouncementListView(generics.ListAPIView):
    """GET /api/content/announcements/ — Home feed (point #3)."""
    from .serializers import AnnouncementSerializer
    from .models import Announcement
    serializer_class = AnnouncementSerializer
    permission_classes = [permissions.IsAuthenticated]
    queryset = Announcement.objects.all()


class AnnouncementCreateView(generics.CreateAPIView):
    """POST /api/content/announcements/ — admin posts an announcement
    (used by the News tab in the reference admin.js pattern)."""
    from .serializers import AnnouncementSerializer
    from .models import Announcement
    serializer_class = AnnouncementSerializer
    permission_classes = [permissions.IsAdminUser]
    queryset = Announcement.objects.all()

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)


class SyllabusView(views.APIView):
    """
    GET /api/content/syllabus/?exam=JEE&class=12
    Point #13: syllabus itself is viewable by all classes, but the actual
    question papers stay class-restricted (enforced in the exams app).
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        exam = request.query_params.get('exam', 'JEE')
        class_level = request.query_params.get('class', '12')
        chapters = (
            Chapter.objects
            .filter(subject__exam=exam, class_level=class_level)
            .select_related('subject')
            .order_by('subject__name', 'order')
        )
        data = {}
        for ch in chapters:
            data.setdefault(ch.subject.name, []).append(ch.name)
        return Response(data)
