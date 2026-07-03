from django.db import models


class TodoItem(models.Model):
    """
    Point #15: user-defined to-do items. Completion percentage feeds the
    rating engine (apps.rating: TODO_DONE / TODO_MISS reasons) via the
    daily cron job `apps.todo.tasks.close_out_expired_todos`.
    """
    user = models.ForeignKey('users.User', related_name='todos', on_delete=models.CASCADE)
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    due_date = models.DateField()
    is_completed = models.BooleanField(default=False)
    completed_at = models.DateTimeField(null=True, blank=True)
    # Set once the due date has passed and rating impact has been applied,
    # so the daily job never double-penalizes/rewards the same item.
    rating_impact_applied = models.BooleanField(default=False)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['due_date']
        indexes = [models.Index(fields=['user', 'due_date'])]