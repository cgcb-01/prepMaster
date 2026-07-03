from rest_framework import serializers, generics, filters
from django_filters.rest_framework import DjangoFilterBackend
from apps.users.models import User


class GlobalLeaderboardSerializer(serializers.ModelSerializer):
    rating = serializers.IntegerField(source='rating_current', default=0)  # annotate in view

    class Meta:
        model = User
        fields = ['id', 'username', 'first_name', 'last_name', 'school_name', 'state',
                  'student_class', 'target_exam', 'rating']


class GlobalLeaderboardView(generics.ListAPIView):
    """
    GET /api/leaderboard/global/?exam=JEE&class=12&state=Delhi
    Global / state / school / friend rank views all reuse this with
    different querysets (point #16). Rating is pulled from the user's
    latest RatingHistory.rating_after for speed; consider a denormalized
    `current_rating` field on User for very large scale instead of a subquery.
    """
    serializer_class = GlobalLeaderboardSerializer
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ['target_exam', 'student_class', 'state', 'school_name']
    search_fields = ['username', 'school_name']

    def get_queryset(self):
        from django.db.models import OuterRef, Subquery
        from apps.rating.models import RatingHistory

        latest_rating = (
            RatingHistory.objects.filter(user=OuterRef('pk')).order_by('-created_at')
        )
        qs = User.objects.annotate(
            rating_current=Subquery(latest_rating.values('rating_after')[:1])
        ).order_by('-rating_current')

        friends_only = self.request.query_params.get('friends_only')
        if friends_only:
            from apps.users.models import Friendship
            friend_ids = Friendship.objects.filter(
                from_user=self.request.user, status='ACCEPTED'
            ).values_list('to_user_id', flat=True)
            qs = qs.filter(id__in=friend_ids)

        return qs