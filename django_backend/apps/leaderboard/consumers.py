"""
Live leaderboard over WebSockets (Django Channels).

Flow:
  - Client connects to ws://<host>/ws/leaderboard/<paper_id>/
  - On connect, server sends the current top-N snapshot.
  - Whenever a submission is scored during a live PAIC/BAIC,
    `broadcast_leaderboard_update(paper_id)` is called (from the scoring
    task), which pushes the fresh top-N + the requesting user's own rank
    to every connected client in that paper's group.
  - Group is only "live" while contest.is_currently_running; after the
    contest ends the leaderboard stays visible but becomes read-only
    (frontend can just stop listening / show a "Final" badge).
"""
import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync, sync_to_async

from apps.exams.models import ExamPaper
from .models import ContestLeaderboardEntry


class LeaderboardConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.paper_id = self.scope['url_route']['kwargs']['paper_id']
        self.group_name = f'leaderboard_{self.paper_id}'

        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

        snapshot = await self._get_snapshot()
        await self.send(text_data=json.dumps({'type': 'snapshot', 'data': snapshot}))

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def receive(self, text_data=None, bytes_data=None):
        # Clients can ping for a refresh; no client-initiated writes allowed.
        if text_data:
            msg = json.loads(text_data)
            if msg.get('action') == 'refresh':
                snapshot = await self._get_snapshot()
                await self.send(text_data=json.dumps({'type': 'snapshot', 'data': snapshot}))

    async def leaderboard_update(self, event):
        """Handler for group_send messages of type 'leaderboard.update'."""
        await self.send(text_data=json.dumps({'type': 'update', 'data': event['data']}))

    @sync_to_async
    def _get_snapshot(self, top_n: int = 50):
        entries = (
            ContestLeaderboardEntry.objects
            .filter(paper_id=self.paper_id)
            .select_related('user')
            .order_by('rank')[:top_n]
        )
        return [
            {
                'rank': e.rank,
                'user': e.user.get_full_name() or e.user.username,
                'school': e.user.school_name,
                'score': e.score,
                'accuracy': round(e.accuracy, 1),
                'time_taken_seconds': e.time_taken_seconds,
            }
            for e in entries
        ]


def broadcast_leaderboard_update(paper_id: int, top_n: int = 50):
    """Call this synchronously (e.g. from the scoring Celery task) right
    after `recompute_ranks(paper_id)` to push fresh standings to everyone
    watching the live leaderboard."""
    from .models import recompute_ranks
    entries = recompute_ranks(paper_id)[:top_n]
    data = [
        {
            'rank': e.rank,
            'user': e.user.get_full_name() or e.user.username,
            'school': e.user.school_name,
            'score': e.score,
            'accuracy': round(e.accuracy, 1),
            'time_taken_seconds': e.time_taken_seconds,
        }
        for e in entries
    ]
    channel_layer = get_channel_layer()
    async_to_sync(channel_layer.group_send)(
        f'leaderboard_{paper_id}',
        {'type': 'leaderboard.update', 'data': data},
    )
