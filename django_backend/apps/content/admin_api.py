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
from django.core.files.storage import default_storage

from .models import Question, QuestionCategory, Subject, Chapter, Module


class IsAdminUser(permissions.BasePermission):
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_staff)


class AdminImageUploadView(viewsets.ViewSet):
    """
    POST /api/admin/upload-image/  multipart: file=<image>
    Saves the file to the real backend storage (Backblaze B2 in production,
    local MEDIA in demo mode) and returns its permanent path + URL. This is
    the only way an image ever gets attached to a question — the client
    never sends a blob: URL or a local device path to the server; it always
    uploads bytes here first and then references the returned `path`.
    """
    permission_classes = [IsAdminUser]
    parser_classes = [parsers.MultiPartParser]

    def create(self, request):
        file_obj = request.FILES.get('file')
        if not file_obj:
            return Response({'detail': 'No file provided.'}, status=status.HTTP_400_BAD_REQUEST)

        saved_path = default_storage.save(f'admin_uploads/{file_obj.name}', file_obj)
        return Response({
            'path': saved_path,
            'url': default_storage.url(saved_path),
        }, status=status.HTTP_201_CREATED)


class QuestionOptionField(serializers.Serializer):
    """One MCQ option — text and/or image, matching point #20's requirement
    that text/LaTeX/image be supported simultaneously in every question
    AND every option."""
    text = serializers.CharField(allow_blank=True, required=False, default='')
    image_url = serializers.CharField(allow_blank=True, required=False, default='')
    is_correct = serializers.BooleanField(default=False)


class SubjectField(serializers.PrimaryKeyRelatedField):
    """
    Accepts either a real Subject id (int) or a plain name string like
    "PHYSICS"/"Physics". The quick-add question form sends a simple subject
    name (matching the reference admin.js UX) rather than making the admin
    look up an id first — this resolves that name to an existing Subject or
    creates one on the fly, so the request never 400s on a type mismatch.
    """
    def to_internal_value(self, data):
        if isinstance(data, str) and not data.isdigit():
            subject = Subject.objects.filter(name__iexact=data).first()
            if not subject:
                subject = Subject.objects.create(name=data.title(), exam='JEE')
            return subject
        return super().to_internal_value(data)


class AdminQuestionSerializer(serializers.ModelSerializer):
    """
    Full read/write serializer used by the admin authoring UI.

    Images are never sent as raw multipart files or blob: URLs in this
    payload. The client first uploads bytes to AdminImageUploadView, gets
    back a real storage path, and passes that path here via `image_path` /
    `solution_image_path` (write-only). We assign it straight to the
    ImageField's `.name` — the file is already persisted in storage, so
    this just points the question at it, no re-upload.

    Per-option images work the same way but don't need a dedicated model
    field: `options` is plain JSON, so the uploaded path/URL is just
    embedded as `image_url` in each option dict directly by the client.
    """
    options = serializers.ListField(child=QuestionOptionField(), required=False, default=list)
    subject = SubjectField(queryset=Subject.objects.all())
    image_path = serializers.CharField(write_only=True, required=False, allow_blank=True)
    solution_image_path = serializers.CharField(write_only=True, required=False, allow_blank=True)
    image = serializers.SerializerMethodField(read_only=True)
    solution_image = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = Question
        fields = [
            'id', 'subject', 'chapter', 'category', 'body', 'image', 'image_path',
            'options', 'numerical_answer', 'solution_text', 'solution_image', 'solution_image_path',
            'year', 'exam_shift', 'created_by', 'created_at', 'updated_at',
        ]
        read_only_fields = ['created_by', 'created_at', 'updated_at']

    def get_image(self, obj):
        return obj.image.url if obj.image else None

    def get_solution_image(self, obj):
        return obj.solution_image.url if obj.solution_image else None

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
        image_path = validated_data.pop('image_path', '')
        solution_image_path = validated_data.pop('solution_image_path', '')
        validated_data['created_by'] = self.context['request'].user
        instance = super().create(validated_data)
        self._apply_stored_paths(instance, image_path, solution_image_path)
        return instance

    def update(self, instance, validated_data):
        image_path = validated_data.pop('image_path', None)
        solution_image_path = validated_data.pop('solution_image_path', None)
        instance = super().update(instance, validated_data)
        self._apply_stored_paths(instance, image_path, solution_image_path)
        return instance

    def _apply_stored_paths(self, instance, image_path, solution_image_path):
        changed = False
        if image_path:
            instance.image.name = image_path
            changed = True
        if solution_image_path:
            instance.solution_image.name = solution_image_path
            changed = True
        if changed:
            instance.save()


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
        fields = ['id', 'chapter', 'module_type', 'title', 'order', 'is_premium', 'linked_paper']


class ModuleAdminViewSet(viewsets.ModelViewSet):
    """Admin can add more modules to a chapter at any time (point #19)."""
    queryset = Module.objects.all()
    serializer_class = ModuleAdminSerializer
    permission_classes = [IsAdminUser]
