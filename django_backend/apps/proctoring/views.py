from rest_framework import serializers, views, permissions, status
from rest_framework.response import Response

from apps.submissions.models import Attempt
from .models import ProctoringSession, ProctoringFlag


class StartProctoringView(views.APIView):
    """POST /api/proctoring/start/  { attempt_id }
    Called when the user toggles proctoring ON before starting an exam
    (opt-in per point #8)."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        attempt_id = request.data.get('attempt_id')
        attempt = Attempt.objects.get(id=attempt_id, user=request.user)
        attempt.proctoring_enabled = True
        attempt.save(update_fields=['proctoring_enabled'])
        session, _ = ProctoringSession.objects.get_or_create(attempt=attempt)
        return Response({'session_id': session.id}, status=status.HTTP_201_CREATED)


class FlagSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProctoringFlag
        fields = ['flag_type', 'snapshot', 'timestamp_in_exam_seconds']


class SubmitProctoringFlagView(views.APIView):
    """
    POST /api/proctoring/<session_id>/flag/
    multipart form: flag_type, timestamp_in_exam_seconds, snapshot (optional image)

    The client (Flutter) runs on-device face detection (google_mlkit_face_detection)
    at a low sample rate (e.g. every 5-10s) and only calls this endpoint when
    something is actually wrong (no face / >1 face) — not every frame. This
    keeps bandwidth and storage minimal and matches the "just checks... that's
    all it must check" scope from the spec, i.e. no continuous video upload.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, session_id):
        session = ProctoringSession.objects.get(id=session_id, attempt__user=request.user)
        serializer = FlagSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save(session=session)

        session.total_flags = session.flags.count()
        session.save(update_fields=['total_flags'])

        attempt = session.attempt
        attempt.proctoring_flag_count = session.total_flags
        attempt.save(update_fields=['proctoring_flag_count'])

        return Response({'total_flags': session.total_flags}, status=status.HTTP_201_CREATED)


class EndProctoringView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, session_id):
        from django.utils import timezone
        session = ProctoringSession.objects.get(id=session_id, attempt__user=request.user)
        session.ended_at = timezone.now()
        session.save(update_fields=['ended_at'])
        return Response({'ok': True})
