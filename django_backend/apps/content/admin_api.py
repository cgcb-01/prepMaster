"""
Admin question-authoring API (point #19/#20/#22). This is the API surface
a native admin UI (Flutter admin screens, or any other client) uses instead
of the Django admin website. Django admin (apps/adminpanel/admin.py) and
this API both operate on the same models, so content stays consistent
regardless of which interface staff use.

Key guarantees implemented here per the spec:
  - A question's `body` can mix plain text and LaTeX ($...$/$$...$$),
    optionally with a standalone image (point #20).
  - Each option can itself carry text AND/OR an image (point #20's
    "simultaneously supported" requirement) — options are stored as JSON:
      [{"text": "...", "image_url": "...", "is_correct": true}, ...]
  - Every question is editable at any time by an admin (point #19) — this
    is a normal DRF update endpoint, no locking once "published".
  - Category (and therefore marking scheme) is assigned at authoring time,
    admin-defined per point #22.
"""
from rest_framework import serializers, viewsets, permissions, parsers, status
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import Question, QuestionCategory, Subject, Chapter, Module


class IsAdminUser(permissions.BasePermission):
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_staff)


class QuestionOptionField(serializers.Serializer):
    """One MCQ option — text and/or image, matching point #20's requirement
    that text/LaTeX/image be supported simultaneously in every question
    AND every option."""
    text = serializers.CharField(allow_blank=True, required=False, default='')
    image_url = serializers.CharField(allow_blank=True, required=False, default='')
    is_correct = serializers.BooleanField(default=False)


class AdminQuestionSerializer(serializers.ModelSerializer):
    """
    Full read/write serializer used by the admin authoring UI.
    `options` accepts a raw JSON list (validated against QuestionOptionField
    shape) rather than nested multipart fields, so a single PATCH can
    reorder/edit/add/remove options in one call — important for "every
    question can be edited" (point #19) to feel instant rather than
    requiring N sub-requests.
    """
    options = serializers.ListField(child=QuestionOptionField(), required=False, default=list)

    class Meta:
        model = Question
        fields = [
            'id', 'subject', 'chapter', 'category', 'body', 'image',
            'options', 'numerical_answer', 'solution_text', 'solution_image',
            'year', 'exam_shift', 'created_by', 'created_at', 'updated_at',
        ]
        read_only_fields = ['created_by', 'created_at', 'updated_at']

    def validate_options(self, value):
        category_id = self.initial_data.get('category')
        if category_id:
            category = QuestionCategory.objects.filter(id=category_id).first()
            if category and category.question_type in ('MCQ_SINGLE', 'ASSERTION_REASON'):
                correct_count = sum(1 for o in value if o.get('is_correct'))
                if correct_count != 1:
                    raise serializers.ValidationError(
                        'This category requires exactly one correct option.'
                    )
        return value

    def create(self, validated_data):
        validated_data['created_by'] = self.context['request'].user
        return super().create(validated_data)


class AdminQuestionViewSet(viewsets.ModelViewSet):
    """
    Full CRUD for admin question authoring.

    GET    /api/admin/questions/                 list (filterable)
    POST   /api/admin/questions/                  create (multipart: image, solution_image files + JSON fields)
    GET    /api/admin/questions/<id>/             retrieve
    PATCH  /api/admin/questions/<id>/              partial edit — ANY field, ANY time (point #19)
    DELETE /api/admin/questions/<id>/              delete
    POST   /api/admin/questions/<id>/duplicate/    clone as a starting point for a variant question
    """
    queryset = Question.objects.select_related('subject', 'chapter', 'category').order_by('-updated_at')
    serializer_class = AdminQuestionSerializer
    permission_classes = [IsAdminUser]
    parser_classes = [parsers.MultiPartParser, parsers.FormParser, parsers.JSONParser]

    def get_queryset(self):
        qs = super().get_queryset()
        for field in ['subject', 'chapter', 'category', 'year']:
            val = self.request.query_params.get(field)
            if val:
                qs = qs.filter(**{field: val})
        search = self.request.query_params.get('search')
        if search:
            qs = qs.filter(body__icontains=search)
        return qs

    @action(detail=True, methods=['post'])
    def duplicate(self, request, pk=None):
        original = self.get_object()
        original.pk = None
        original.id = None
        original.created_by = request.user
        original.save()
        return Response(self.get_serializer(original).data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['get'])
    def preview_pdf_snippet(self, request, pk=None):
        """Renders just this one question through the same LaTeX pipeline
        used for full papers, so admin can sanity-check rendering without
        building a whole paper first."""
        from apps.pdfgen.latex_render import render_mixed_body
        question = self.get_object()
        html = render_mixed_body(question.body, latex_fontsize=16)
        return Response({'rendered_html': html})


class QuestionCategoryViewSet(viewsets.ModelViewSet):
    """Admin manages marking schemes here (point #22)."""
    from .serializers import QuestionCategorySerializer
    queryset = QuestionCategory.objects.all()
    serializer_class = QuestionCategorySerializer
    permission_classes = [IsAdminUser]


class SubjectAdminViewSet(viewsets.ModelViewSet):
    from .serializers import SubjectSerializer
    queryset = Subject.objects.all()
    serializer_class = SubjectSerializer
    permission_classes = [IsAdminUser]


class ChapterAdminSerializer(serializers.ModelSerializer):
    class Meta:
        model = Chapter
        fields = ['id', 'subject', 'name', 'order', 'class_level', 'difficulty', 'estimated_hours']


class ChapterAdminViewSet(viewsets.ModelViewSet):
    """Admin can add chapters, reorder them, add years/shifts context for
    PYQs (point #19)."""
    queryset = Chapter.objects.all()
    serializer_class = ChapterAdminSerializer
    permission_classes = [IsAdminUser]


class ModuleAdminSerializer(serializers.ModelSerializer):
    class Meta:
        model = Module
        fields = ['id', 'chapter', 'module_type', 'title', 'order', 'is_premium']


class ModuleAdminViewSet(viewsets.ModelViewSet):
    """Admin can add more modules to a chapter at any time (point #19)."""
    queryset = Module.objects.all()
    serializer_class = ModuleAdminSerializer
    permission_classes = [IsAdminUser]
