from celery import shared_task
from django.utils import timezone
from .models import TodoItem


@shared_task
def close_out_expired_todos():
    """
    Daily job: for every to-do item whose due_date has passed and hasn't had
    its rating impact applied yet, nudge the user's rating up or down based
    on completion (point #15/#17). Runs once/day via Celery beat.
    """
    from apps.rating.models import RatingHistory, compute_rating_delta

    today = timezone.now().date()
    expired = TodoItem.objects.filter(due_date__lt=today, rating_impact_applied=False)

    for todo in expired:
        user = todo.user
        latest = RatingHistory.objects.filter(user=user).order_by('-created_at').first()
        rating_before = latest.rating_after if latest else 1000

        performance_ratio = 0.3 if todo.is_completed else -0.3
        delta = compute_rating_delta(
            user, 'TODO_DONE' if todo.is_completed else 'TODO_MISS',
            performance_ratio=performance_ratio, weight=0.2,  # low weight vs PAIC/BAIC
        )

        RatingHistory.objects.create(
            user=user,
            rating_before=rating_before,
            rating_after=rating_before + delta,
            delta=delta,
            reason='TODO_DONE' if todo.is_completed else 'TODO_MISS',
        )
        todo.rating_impact_applied = True
        todo.save(update_fields=['rating_impact_applied'])
