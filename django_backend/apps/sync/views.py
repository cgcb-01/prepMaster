from rest_framework import views, permissions, status
from rest_framework.response import Response
from django.utils.dateparse import parse_datetime

from apps.library.models import LibraryItem
from apps.submissions.models import Attempt, Answer
from apps.content.models import Question


class LibraryManifestView(views.APIView):
    """
    GET /api/sync/library/manifest/
    Returns every paper the user is entitled to have offline, with a content
    hash/version so the client only re-downloads what changed. Papers whose
    premium access has lapsed are marked still_accessible=False and the
    client deletes the cached PDF (point #23).
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        items = LibraryItem.objects.filter(user=request.user).select_related('paper')
        return Response([
            {
                'paper_id': item.paper_id,
                'title': item.paper.title,
                'paper_type': item.paper.paper_type,
                'pdf_url': item.paper.question_paper_pdf.url if item.paper.question_paper_pdf else None,
                'solution_url': (
                    item.paper.solution_pdf.url
                    if item.still_accessible and item.paper.solution_pdf else None
                ),
                'still_accessible': item.still_accessible,
                'updated_at': item.paper.updated_at.isoformat(),
            }
            for item in items
        ])


class PushOfflineAttemptsView(views.APIView):
    """
    POST /api/sync/attempts/push/
    Body: { "attempts": [ { local_id, paper_id, started_at, submitted_at,
             answers: [{question_id, selected_options, numerical_response,
                        status, time_spent_seconds}] } ] }

    Called by the Flutter app when connectivity returns, flushing everything
    the user did offline (point #5: attempt Offline, checked once synced).
    Idempotent via local_id so retried pushes don't double-create attempts.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        results = []
        for a in request.data.get('attempts', []):
            local_id = a.get('local_id')

            attempt, created = Attempt.objects.get_or_create(
                user=request.user,
                paper_id=a['paper_id'],
                started_at=parse_datetime(a['started_at']),
                defaults={
                    'is_offline_attempt': True,
                    'status': 'SUBMITTED',
                    'submitted_at': parse_datetime(a.get('submitted_at')) if a.get('submitted_at') else None,
                },
            )

            if created:
                answer_objs = []
                for ans in a.get('answers', []):
                    answer_objs.append(Answer(
                        attempt=attempt,
                        question_id=ans['question_id'],
                        selected_options=ans.get('selected_options', []),
                        numerical_response=ans.get('numerical_response'),
                        status=ans.get('status', 'ANSWERED'),
                        time_spent_seconds=ans.get('time_spent_seconds', 0),
                    ))
                Answer.objects.bulk_create(answer_objs)

                # Trigger scoring synchronously here for simplicity; in
                # production dispatch to apps.submissions.tasks.score_attempt.delay(attempt.id)
                from apps.submissions.scoring import score_attempt
                score_attempt(attempt.id)

            results.append({'local_id': local_id, 'server_attempt_id': attempt.id, 'created': created})

        return Response({'results': results}, status=status.HTTP_200_OK)