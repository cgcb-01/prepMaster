"""
Shared scoring logic for an Attempt. Applies each ExamPaperQuestion's
marking scheme (with per-paper overrides, point #22) to every Answer,
supporting MCQ single/multiple, numerical, and match-the-column types.
"""
from django.db.models import Sum, Count
from .models import Attempt, Answer
from apps.exams.models import ExamPaperQuestion


def _score_single_answer(answer: Answer, epq: ExamPaperQuestion) -> float:
    q = answer.question
    cat = q.category
    correct_marks = epq.marks_correct_override if epq.marks_correct_override is not None else cat.marks_correct
    incorrect_marks = epq.marks_incorrect_override if epq.marks_incorrect_override is not None else cat.marks_incorrect

    if answer.status in ('NOT_ANSWERED', 'NOT_VISITED') and not answer.selected_options and answer.numerical_response is None:
        return 0.0

    if cat.question_type == 'NUMERICAL':
        if answer.numerical_response is None:
            return 0.0
        is_correct = abs(answer.numerical_response - (q.numerical_answer or 0)) < 1e-6
        answer.is_correct = is_correct
        return correct_marks if is_correct else incorrect_marks

    correct_indices = {i for i, opt in enumerate(q.options or []) if opt.get('is_correct')}
    selected = set(answer.selected_options or [])

    if cat.question_type == 'MCQ_SINGLE' or cat.question_type == 'ASSERTION_REASON':
        is_correct = selected == correct_indices and len(selected) == 1
        answer.is_correct = is_correct
        return correct_marks if is_correct else (incorrect_marks if selected else 0.0)

    if cat.question_type == 'MCQ_MULTIPLE':
        if selected == correct_indices:
            answer.is_correct = True
            return correct_marks
        if selected and selected.issubset(correct_indices):
            answer.is_correct = False
            return cat.marks_partial  # partial credit for a correct subset
        answer.is_correct = False
        return incorrect_marks if selected else 0.0

    # MATCH_COLUMN and anything else: treat as exact-set-match for now
    is_correct = selected == correct_indices
    answer.is_correct = is_correct
    return correct_marks if is_correct else incorrect_marks


def score_attempt(attempt_id: int):
    attempt = Attempt.objects.select_related('paper').get(id=attempt_id)
    epq_by_question = {
        epq.question_id: epq
        for epq in ExamPaperQuestion.objects.filter(paper=attempt.paper)
    }

    answers = list(attempt.answers.select_related('question', 'question__category'))
    total_score = 0.0
    attempted = 0
    correct = 0

    for answer in answers:
        epq = epq_by_question.get(answer.question_id)
        if epq is None:
            continue
        marks = _score_single_answer(answer, epq)
        answer.marks_awarded = marks
        total_score += marks
        if answer.selected_options or answer.numerical_response is not None:
            attempted += 1
            if answer.is_correct:
                correct += 1

    Answer.objects.bulk_update(answers, ['marks_awarded', 'is_correct'])

    attempt.total_score = total_score
    attempt.accuracy_percent = (correct / attempted * 100) if attempted else 0.0
    attempt.save(update_fields=['total_score', 'accuracy_percent'])

    # If this attempt completes a module-linked to-do, mark it done and
    # apply a performance-weighted rating bump (point #15).
    from apps.todo.services import check_and_complete_module_todos
    check_and_complete_module_todos(attempt)

    # If this paper is a live contest, push the leaderboard update.
    if attempt.paper.paper_type in ('PAIC', 'BAIC'):
        _update_leaderboard(attempt)

    return attempt


def _update_leaderboard(attempt: Attempt):
    from apps.leaderboard.models import ContestLeaderboardEntry
    from apps.leaderboard.consumers import broadcast_leaderboard_update
    from django.utils import timezone

    time_taken = 0
    if attempt.submitted_at and attempt.started_at:
        time_taken = int((attempt.submitted_at - attempt.started_at).total_seconds())

    ContestLeaderboardEntry.objects.update_or_create(
        paper=attempt.paper,
        user=attempt.user,
        defaults={
            'attempt': attempt,
            'score': attempt.total_score or 0,
            'accuracy': attempt.accuracy_percent or 0,
            'time_taken_seconds': time_taken,
        },
    )
    broadcast_leaderboard_update(attempt.paper_id)
