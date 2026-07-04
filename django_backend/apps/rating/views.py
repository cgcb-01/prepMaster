from rest_framework import serializers, generics, permissions
from .models import RatingHistory


class RatingHistorySerializer(serializers.ModelSerializer):
    class Meta:
        model = RatingHistory
        fields = ['rating_before', 'rating_after', 'delta', 'reason', 'created_at']


class RatingGraphView(generics.ListAPIView):
    """GET /api/rating/history/ — backs the Codeforces-style rating graph
    on My Dashboard (point #4)."""
    serializer_class = RatingHistorySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return RatingHistory.objects.filter(user=self.request.user).order_by('created_at')
