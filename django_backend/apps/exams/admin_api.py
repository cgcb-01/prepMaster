"""
Admin paper-builder API (point #12/19/22): assemble a DPP/Chapter Test/PYQ
set/PAIC/BAIC from existing questions, set paper-level config (duration,
premium, downloadable, live contest window), and override marking per
question within this specific paper if needed. Every field remains
editable after creation/publication (point #19).
"""
from rest_framework import serializers, viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import ExamPaper, ExamPaperQuestion
from apps.content.admin_api import IsAdminUser


class ExamPaperQuestionAdminSerializer(serializers.ModelSerializer):
    class Meta:
        model = ExamPaperQuestion
        fields = ['id', 'question', 'order', 'marks_correct_override', 'marks_incorrect_override']


class AdminExamPaperSerializer(serializers.ModelSerializer):
    paper_questions = ExamPaperQuestionAdminSerializer(many=True, read_only=True, source='exampaperquestion_set')

    class Meta:
        model = ExamPaper
        fields = [
            'id', 'title', 'paper_type', 'exam_style', 'class_level',
            'duration_minutes', 'total_marks', 'is_premium', 'is_downloadable',
            'scheduled_start', 'scheduled_end', 'is_live_contest',
            'question_paper_pdf', 'solution_pdf', 'paper_questions',
            'created_by', 'created_at', 'updated_at',
        ]
        read_only_fields = ['question_paper_pdf', 'solution_pdf', 'created_by', 'created_at', 'updated_at']


class AdminExamPaperViewSet(viewsets.ModelViewSet):
    """
    GET/POST   /api/admin/papers/
    GET/PATCH/DELETE /api/admin/papers/<id>/
    POST       /api/admin/papers/<id>/add_question/     { question_id, order, marks_correct_override?, marks_incorrect_override? }
    POST       /api/admin/papers/<id>/remove_question/   { question_id }
    POST       /api/admin/papers/<id>/reorder/            { ordered_question_ids: [...] }
    POST       /api/admin/papers/<id>/generate_pdfs/      triggers the PDF pipeline (async)
    """
    queryset = ExamPaper.objects.all().order_by('-created_at')
    serializer_class = AdminExamPaperSerializer
    permission_classes = [IsAdminUser]

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)

    def get_queryset(self):
        qs = super().get_queryset()
        for field in ['paper_type', 'exam_style', 'class_level']:
            val = self.request.query_params.get(field)
            if val:
                qs = qs.filter(**{field: val})
        return qs

    @action(detail=True, methods=['post'])
    def add_question(self, request, pk=None):
        paper = self.get_object()
        epq, created = ExamPaperQuestion.objects.update_or_create(
            paper=paper,
            question_id=request.data['question_id'],
            defaults={
                'order': request.data.get('order', paper.exampaperquestion_set.count() + 1),
                'marks_correct_override': request.data.get('marks_correct_override'),
                'marks_incorrect_override': request.data.get('marks_incorrect_override'),
            },
        )
        return Response(ExamPaperQuestionAdminSerializer(epq).data, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)

    @action(detail=True, methods=['post'])
    def remove_question(self, request, pk=None):
        paper = self.get_object()
        ExamPaperQuestion.objects.filter(paper=paper, question_id=request.data['question_id']).delete()
        return Response({'ok': True})

    @action(detail=True, methods=['post'])
    def reorder(self, request, pk=None):
        paper = self.get_object()
        ordered_ids = request.data.get('ordered_question_ids', [])
        epqs = {epq.question_id: epq for epq in ExamPaperQuestion.objects.filter(paper=paper)}
        updated = []
        for i, qid in enumerate(ordered_ids, start=1):
            epq = epqs.get(qid)
            if epq:
                epq.order = i
                updated.append(epq)
        ExamPaperQuestion.objects.bulk_update(updated, ['order'])
        return Response({'ok': True})

    @action(detail=True, methods=['post'])
    def generate_pdfs(self, request, pk=None):
        from apps.pdfgen.tasks import generate_paper_pdfs_task
        generate_paper_pdfs_task.delay(pk)
        return Response({'queued': True})
