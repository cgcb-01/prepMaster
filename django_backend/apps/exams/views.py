from rest_framework import generics, views, permissions, status
from rest_framework.response import Response
from django.http import HttpResponse
from django.core.exceptions import PermissionDenied
from django.utils import timezone

from .models import ExamPaper, ExamPaperQuestion
from .serializers import ExamPaperListSerializer, ExamPaperQuestionForAttemptSerializer
from apps.submissions.models import Attempt, Answer
from apps.pdfgen.tasks import request_download


class ExamPaperListView(generics.ListAPIView):
    """
    GET /api/exams/papers/?paper_type=PAIC&exam_style=NEET&class=12
    Backs DPP list, PYQ browser, chapterwise test list, PAIC/BAIC list.
    Point #12/13: any user can attempt NEET or JEE papers, but class
    restricts which are shown by default (client can override).
    """
    serializer_class = ExamPaperListSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = ExamPaper.objects.all().order_by('-scheduled_start', '-created_at')
        for field in ['paper_type', 'exam_style', 'class_level']:
            val = self.request.query_params.get(field)
            if val:
                qs = qs.filter(**{field: val})
        return qs


class ExamPaperDetailView(generics.RetrieveAPIView):
    queryset = ExamPaper.objects.all()
    serializer_class = ExamPaperListSerializer
    permission_classes = [permissions.IsAuthenticated]


class StartAttemptView(views.APIView):
    """
    POST /api/exams/papers/<id>/start/
    Creates (or resumes) an Attempt, blocks premium-locked papers for
    non-premium users, and returns the question set (sans answers).
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        paper = ExamPaper.objects.get(id=pk)
        if paper.is_premium and not request.user.is_premium:
            return Response({'detail': 'Premium required.'}, status=status.HTTP_403_FORBIDDEN)

        attempt, created = Attempt.objects.get_or_create(
            user=request.user, paper=paper, status='IN_PROGRESS',
            defaults={'proctoring_enabled': request.data.get('proctoring_enabled', False)},
        )
        if created:
            epqs = ExamPaperQuestion.objects.filter(paper=paper).order_by('order')
            Answer.objects.bulk_create([
                Answer(attempt=attempt, question=epq.question, status='NOT_VISITED')
                for epq in epqs
            ])

        epqs = (
            ExamPaperQuestion.objects
            .filter(paper=paper)
            .select_related('question', 'question__subject', 'question__category')
            .order_by('order')
        )
        questions = ExamPaperQuestionForAttemptSerializer(epqs, many=True).data

        return Response({
            'attempt_id': attempt.id,
            'duration_minutes': paper.duration_minutes,
            'started_at': attempt.started_at,
            'questions': questions,
        }, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)


class SubmitAnswerView(views.APIView):
    """PATCH /api/exams/attempts/<attempt_id>/answer/<question_id>/
    Body: { selected_options, numerical_response, omr_bubble, status, time_spent_seconds }
    Called on every 'Save & Next' / bubble tap — keeps state resumable if
    the connection drops mid-exam."""
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, attempt_id, question_id):
        answer = Answer.objects.get(
            attempt_id=attempt_id, question_id=question_id, attempt__user=request.user
        )
        for field in ['selected_options', 'numerical_response', 'omr_bubble', 'status', 'time_spent_seconds']:
            if field in request.data:
                setattr(answer, field, request.data[field])
        answer.save()
        return Response({'ok': True})


class SubmitAttemptView(views.APIView):
    """POST /api/exams/attempts/<attempt_id>/submit/"""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, attempt_id):
        attempt = Attempt.objects.get(id=attempt_id, user=request.user)
        attempt.status = 'SUBMITTED'
        attempt.submitted_at = timezone.now()
        attempt.save(update_fields=['status', 'submitted_at'])

        from apps.submissions.scoring import score_attempt
        score_attempt(attempt.id)

        attempt.refresh_from_db()
        return Response({
            'total_score': attempt.total_score,
            'accuracy_percent': attempt.accuracy_percent,
        })


class DownloadPaperView(views.APIView):
    """GET /api/exams/papers/<id>/download/ — enforces max-3/day (point #9)."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, pk):
        paper = ExamPaper.objects.get(id=pk)
        try:
            pdf_bytes = request_download(request.user, paper)
        except PermissionDenied as e:
            return Response({'detail': str(e)}, status=status.HTTP_403_FORBIDDEN)

        response = HttpResponse(pdf_bytes, content_type='application/pdf')
        response['Content-Disposition'] = f'attachment; filename="{paper.title}.pdf"'
        return response
