from rest_framework import serializers
from django.db.models import Q
from .models import User, Friendship


class PublicProfileSerializer(serializers.ModelSerializer):
    """Everything visible to any user (point #4's 'public' section)."""
    rating = serializers.SerializerMethodField()
    rating_title = serializers.SerializerMethodField()
    is_online = serializers.BooleanField(read_only=True)
    friend_count = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id', 'username', 'first_name', 'last_name', 'photo', 'school_name',
            'state', 'country', 'roll_no', 'student_class', 'rating', 'rating_title',
            'registered_at', 'last_seen_at', 'is_online', 'friend_count',
            'current_streak_days', 'max_streak_days', 'max_submissions_in_a_day',
        ]

    def get_rating(self, obj):
        from apps.rating.models import RatingHistory
        latest = RatingHistory.objects.filter(user=obj).order_by('-created_at').first()
        return latest.rating_after if latest else 1000

    def get_rating_title(self, obj):
        from apps.rating.models import title_for_rating
        return title_for_rating(self.get_rating(obj))

    def get_friend_count(self, obj):
        return Friendship.objects.filter(
            Q(from_user=obj) | Q(to_user=obj), status='ACCEPTED'
        ).count()


class PrivateProfileSerializer(PublicProfileSerializer):
    """Adds the owner-only fields (point #4's 'private' section)."""
    weak_subjects = serializers.SerializerMethodField()
    weak_chapters = serializers.SerializerMethodField()

    class Meta(PublicProfileSerializer.Meta):
        fields = PublicProfileSerializer.Meta.fields + [
            'email', 'target_exam', 'is_premium', 'premium_expires_at', 'is_staff',
            'weak_subjects', 'weak_chapters',
        ]

    def get_weak_chapters(self, obj):
        return list(
            obj.weak_areas.order_by('-mistake_count').values_list('chapter__name', flat=True)[:5]
        )

    def get_weak_subjects(self, obj):
        subjects = (
            obj.weak_areas.order_by('-mistake_count')
            .values_list('chapter__subject__name', flat=True)
            .distinct()
        )
        return list(subjects[:3])


class ClassSwitchSerializer(serializers.Serializer):
    student_class = serializers.ChoiceField(choices=User.CLASS_CHOICES)


class FriendshipSerializer(serializers.ModelSerializer):
    class Meta:
        model = Friendship
        fields = ['id', 'from_user', 'to_user', 'status', 'created_at']
        read_only_fields = ['from_user', 'status', 'created_at']