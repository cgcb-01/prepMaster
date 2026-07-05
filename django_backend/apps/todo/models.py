from django.db import models


class TodoItem(models.Model):
    """
    Point #15: user-defined to-do items. Two flavors:
      - Module-linked: `module` is set. This is "attempt <module>" — the
        server (not the user) marks it complete once they submit the
        module's `linked_paper`, and the rating impact reflects how well
        they did (apps.todo.services.check_and_complete_module_todos).
      - Free-text: `module` is null, `title` is user-typed. Completion is
        manual (the user ticks it themselves).
    Either way, a missed deadline lowers rating and on-time completion
    raises it, via the daily cron `apps.todo.tasks.close_out_expired_todos`
    for misses and the submission hook for on-time completions.
    """
    user = models.ForeignKey('users.User', related_name='todos', on_delete=models.CASCADE)
    title = models.CharField(max_length=255, blank=True)
    description = models.TextField(blank=True)
    due_date = models.DateField()
    is_completed = models.BooleanField(default=False)
    completed_at = models.DateTimeField(null=True, blank=True)
    module = models.ForeignKey('content.Module', null=True, blank=True, on_delete=models.CASCADE)
    # Set once rating impact has been applied (on-time completion OR missed
    # deadline), so nothing ever double-counts.
    rating_impact_applied = models.BooleanField(default=False)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['due_date']
        indexes = [models.Index(fields=['user', 'due_date'])]

    @property
    def display_title(self):
        if self.module_id:
            return f'{self.module.chapter.name} — {self.module.title}'
        return self.title or 'Untitled task'
