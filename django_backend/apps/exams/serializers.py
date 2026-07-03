from rest_framework import serializers
from .models import ExamPaper


class ExamPaperListSerializer(serializers.ModelSerializer):
    is_locked = serializers.SerializerMethodField()

    class Meta:
        model = ExamPaper
        fields = [
            'id', 'title', 'paper_type', 'exam_style', 'class_level',
            'duration_minutes', 'total_marks', 'is_premium', 'is_downloadable',
            'scheduled_start', 'scheduled_end', 'is_live_contest', 'is_locked',
        ]

    def get_is_locked(self, obj):
        user = self.context['request'].user
        return obj.is_premium and not user.is_premium


class ExamPaperQuestionForAttemptSerializer(serializers.Serializer):
    """What's sent to the client when *starting* an attempt — never includes
    is_correct/solution, since the exam is in progress (point #20)."""
    id = serializers.IntegerField(source='question.id')
    order = serializers.IntegerField()
    subject = serializers.CharField(source='question.subject.name')
    category_name = serializers.CharField(source='question.category.name')
    question_type = serializers.CharField(source='question.category.question_type')
    body = serializers.CharField(source='question.body')
    image = serializers.SerializerMethodField()
    options = serializers.SerializerMethodField()

    def get_image(self, obj):
        return obj.question.image.url if obj.question.image else None

    def get_options(self, obj):
        return [
            {'label': chr(65 + i), 'text': o.get('text'), 'image': o.get('image')}
            for i, o in enumerate(obj.question.options or [])
        ]