from rest_framework import serializers
from .models import Subject, Chapter, Module, Question, QuestionCategory, Announcement


class ModuleSerializer(serializers.ModelSerializer):
    class Meta:
        model = Module
        fields = ['id', 'module_type', 'title', 'order', 'is_premium', 'linked_paper']


class ChapterListSerializer(serializers.ModelSerializer):
    """Chapter row for the 'Stage 2' list screen — includes computed
    progress fields the view annotates in (pyq_count, dpp_count, completion)."""
    modules_completed = serializers.IntegerField(default=0)
    modules_total = serializers.IntegerField(default=0)
    completion_percent = serializers.FloatField(default=0)

    class Meta:
        model = Chapter
        fields = [
            'id', 'name', 'order', 'class_level', 'difficulty', 'estimated_hours',
            'modules_completed', 'modules_total', 'completion_percent',
        ]


class ChapterDetailSerializer(serializers.ModelSerializer):
    modules = ModuleSerializer(many=True, read_only=True)

    class Meta:
        model = Chapter
        fields = ['id', 'name', 'class_level', 'difficulty', 'estimated_hours', 'modules']


class SubjectSerializer(serializers.ModelSerializer):
    chapter_count = serializers.IntegerField(default=0)
    overall_completion_percent = serializers.FloatField(default=0)

    class Meta:
        model = Subject
        fields = ['id', 'name', 'exam', 'chapter_count', 'overall_completion_percent']


class QuestionOptionSerializer(serializers.Serializer):
    label = serializers.CharField()
    text = serializers.CharField()
    image = serializers.CharField(allow_null=True, required=False)


class QuestionSerializer(serializers.ModelSerializer):
    """Used both by admin authoring and by attempt/paper endpoints (with
    is_correct/solution stripped for students via `to_representation` override
    at the exam-serving layer, not here — this is the canonical admin view)."""

    class Meta:
        model = Question
        fields = [
            'id', 'subject', 'chapter', 'category', 'body', 'image', 'options',
            'numerical_answer', 'solution_text', 'solution_image', 'year', 'exam_shift',
        ]


class QuestionCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = QuestionCategory
        fields = [
            'id', 'name', 'exam', 'question_type', 'marks_correct',
            'marks_incorrect', 'marks_partial', 'instructions_text',
        ]


class AnnouncementSerializer(serializers.ModelSerializer):
    class Meta:
        model = Announcement
        fields = ['id', 'title', 'body', 'exam_type', 'related_paper', 'created_at']
