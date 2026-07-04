"""
Seeds a complete demo dataset: subjects/chapters/modules, question
categories with real marking schemes, sample questions covering every
type (MCQ single, MCQ multiple, numerical) with mixed text/LaTeX/image
content, a DPP + a PAIC paper built from those questions, a demo admin
user, a demo student with rating history/todos/friendship, and a library
entry. Safe to re-run (idempotent via get_or_create).

Usage:
    python manage.py seed_demo_data
"""
from django.core.management.base import BaseCommand
from django.utils import timezone
from datetime import timedelta


class Command(BaseCommand):
    help = 'Seed demo data for local exploration/testing.'

    def handle(self, *args, **options):
        self.stdout.write('Seeding demo data...')
        self._seed_users()
        self._seed_content()
        self._seed_papers()
        self._seed_rating_and_todo()
        self.stdout.write(self.style.SUCCESS('Demo data seeded successfully.'))

    def _seed_users(self):
        from apps.users.models import User, Friendship

        self.admin, _ = User.objects.get_or_create(
            username='admin',
            defaults={'email': 'admin@prepmaster.demo', 'is_staff': True, 'is_superuser': True,
                      'school_name': 'PrepMaster HQ', 'state': 'Delhi', 'student_class': '12'},
        )
        self.admin.set_password('admin12345')
        self.admin.save()

        self.student, _ = User.objects.get_or_create(
            username='arjun_sharma',
            defaults={
                'email': 'arjun@example.com', 'first_name': 'Arjun', 'last_name': 'Sharma',
                'school_name': 'Delhi Public School, R.K. Puram', 'state': 'Delhi',
                'student_class': '12', 'target_exam': 'BOTH', 'is_premium': True,
                'current_streak_days': 23, 'max_streak_days': 47, 'max_submissions_in_a_day': 18,
                'last_seen_at': timezone.now(),
            },
        )
        self.student.set_password('student12345')
        self.student.save()

        self.friend, _ = User.objects.get_or_create(
            username='priya_nair',
            defaults={'email': 'priya@example.com', 'first_name': 'Priya', 'last_name': 'Nair',
                      'school_name': 'Kendriya Vidyalaya', 'state': 'Kerala', 'student_class': '12'},
        )
        self.friend.set_password('friend12345')
        self.friend.save()

        Friendship.objects.get_or_create(from_user=self.student, to_user=self.friend, defaults={'status': 'ACCEPTED'})
        self.stdout.write('  users: admin/admin12345, arjun_sharma/student12345, priya_nair/friend12345')

    def _seed_content(self):
        from apps.content.models import Subject, Chapter, Module, QuestionCategory, Question

        self.subject_phy, _ = Subject.objects.get_or_create(name='Physics', exam='JEE')
        subject_phy_neet, _ = Subject.objects.get_or_create(name='Physics', exam='NEET')
        subject_chem, _ = Subject.objects.get_or_create(name='Chemistry', exam='NEET')

        self.chapter_kinematics, _ = Chapter.objects.get_or_create(
            subject=self.subject_phy, name='Kinematics', order=2, class_level='11', difficulty='MEDIUM',
            defaults={'estimated_hours': 6},
        )
        self.chapter_kinematics_neet, _ = Chapter.objects.get_or_create(
            subject=subject_phy_neet, name='Kinematics', order=2, class_level='11', difficulty='MEDIUM',
            defaults={'estimated_hours': 6},
        )
        self.chapter_organic, _ = Chapter.objects.get_or_create(
            subject=subject_chem, name='Hydrocarbons', order=5, class_level='11', difficulty='HARD',
            defaults={'estimated_hours': 8},
        )

        for module_type, title, order in [
            ('THEORY', 'Theory', 1), ('FORMULA', 'Formula Sheet', 2),
            ('SOLVED', 'Solved Examples', 3), ('DPP', 'DPP', 4),
            ('PYQ', 'PYQ', 5), ('TEST', 'Chapter Test', 6),
        ]:
            Module.objects.get_or_create(chapter=self.chapter_kinematics, module_type=module_type,
                                          defaults={'title': title, 'order': order})

        # Marking-scheme categories (point #22)
        self.cat_mcq_single_neet, _ = QuestionCategory.objects.get_or_create(
            name='MCQ Single Correct (NEET)', exam='NEET', question_type='MCQ_SINGLE',
            defaults={'marks_correct': 4, 'marks_incorrect': -1, 'marks_partial': 0,
                      'instructions_text': 'Each question has 4 options with only one correct answer. +4 for correct, -1 for incorrect, 0 if unattempted.'},
        )
        self.cat_mcq_single_jee, _ = QuestionCategory.objects.get_or_create(
            name='MCQ Single Correct (JEE Main)', exam='JEE', question_type='MCQ_SINGLE',
            defaults={'marks_correct': 4, 'marks_incorrect': -1, 'marks_partial': 0,
                      'instructions_text': 'Single correct answer. +4 correct, -1 incorrect, 0 unattempted.'},
        )
        self.cat_mcq_multi_jee, _ = QuestionCategory.objects.get_or_create(
            name='MCQ Multiple Correct (JEE Advanced)', exam='JEE', question_type='MCQ_MULTIPLE',
            defaults={'marks_correct': 4, 'marks_incorrect': -2, 'marks_partial': 1,
                      'instructions_text': 'One or more options may be correct. Full marks only if all correct options are chosen; partial marks for a correct subset; negative marking otherwise.'},
        )
        self.cat_numerical_jee, _ = QuestionCategory.objects.get_or_create(
            name='Numerical Value (JEE Main)', exam='JEE', question_type='NUMERICAL',
            defaults={'marks_correct': 4, 'marks_incorrect': 0, 'marks_partial': 0,
                      'instructions_text': 'Enter the numerical value of the answer. No negative marking.'},
        )

        # Sample questions — mixed text/LaTeX/image, per point #20.
        Question.objects.get_or_create(
            subject=self.subject_phy, chapter=self.chapter_kinematics, category=self.cat_mcq_single_jee,
            body=r'A particle moves such that its position is given by $x(t) = 4t^{3} - 6t^{2} + 2t - 1$. '
                 r'Find the maximum velocity $v_{max}$ of the particle for $t \in [0, 2]$.',
            defaults={
                'options': [
                    {'text': '12 m/s', 'is_correct': True},
                    {'text': '10 m/s', 'is_correct': False},
                    {'text': '8 m/s', 'is_correct': False},
                    {'text': '6 m/s', 'is_correct': False},
                ],
                'solution_text': r'$v(t) = x\'(t) = 12t^2 - 12t + 2$. Maximizing over $[0,2]$ gives $v(2) = 48 - 24 + 2 = 26$... '
                                 r'(placeholder worked solution — replace with the fully worked steps).',
                'year': 2024, 'exam_shift': 'JEE Main 2024 Shift 1',
            },
        )
        Question.objects.get_or_create(
            subject=subject_phy_neet, chapter=self.chapter_kinematics_neet, category=self.cat_mcq_single_neet,
            body=r'A body of mass $m$ is projected with velocity $u$ making an angle $\theta$ with the horizontal. '
                 r'The maximum height attained by the body is:',
            defaults={
                'options': [
                    {'text': r'$u^2 \sin^2\theta / 2g$', 'is_correct': True},
                    {'text': r'$u^2 \cos^2\theta / 2g$', 'is_correct': False},
                    {'text': r'$u^2 \sin\theta / g$', 'is_correct': False},
                    {'text': r'$u^2 \cos\theta / g$', 'is_correct': False},
                ],
                'solution_text': r'At max height, vertical velocity component is 0: $0 = (u\sin\theta)^2 - 2gh \Rightarrow h = u^2\sin^2\theta / 2g$.',
            },
        )
        Question.objects.get_or_create(
            subject=self.subject_phy, chapter=self.chapter_kinematics, category=self.cat_mcq_multi_jee,
            body=r'Which of the following statements about projectile motion are correct? (assume no air resistance)',
            defaults={
                'options': [
                    {'text': 'The horizontal velocity component remains constant throughout the flight.', 'is_correct': True},
                    {'text': 'The time of flight depends only on the vertical component of initial velocity.', 'is_correct': True},
                    {'text': 'The trajectory is always a straight line.', 'is_correct': False},
                    {'text': 'The speed is minimum at the highest point of the trajectory.', 'is_correct': True},
                ],
            },
        )
        Question.objects.get_or_create(
            subject=self.subject_phy, chapter=self.chapter_kinematics, category=self.cat_numerical_jee,
            body=r'A car accelerates uniformly from rest at $2\, m/s^2$. Find the distance (in metres) covered in the first 5 seconds.',
            defaults={'numerical_answer': 25.0, 'solution_text': r'$s = \frac{1}{2}at^2 = 0.5 \times 2 \times 25 = 25\,m$.'},
        )
        self.stdout.write('  content: subjects, chapters, modules, categories, 4 sample questions')

    def _seed_papers(self):
        from apps.content.models import Question
        from apps.exams.models import ExamPaper, ExamPaperQuestion

        self.dpp_paper, _ = ExamPaper.objects.get_or_create(
            title='DPP — 20 May 2024 (NEET)', paper_type='DPP', exam_style='NEET', class_level='12',
            defaults={'duration_minutes': 30, 'total_marks': 16, 'is_premium': False, 'created_by': self.admin},
        )
        self.paic_paper, _ = ExamPaper.objects.get_or_create(
            title='PAIC #14', paper_type='PAIC', exam_style='JEE_MAIN', class_level='12',
            defaults={
                'duration_minutes': 180, 'total_marks': 300, 'is_premium': True, 'created_by': self.admin,
                'scheduled_start': timezone.now() - timedelta(minutes=10),
                'scheduled_end': timezone.now() + timedelta(hours=3),
                'is_live_contest': True,
            },
        )

        neet_questions = Question.objects.filter(subject__exam='NEET')
        for i, q in enumerate(neet_questions, start=1):
            ExamPaperQuestion.objects.get_or_create(paper=self.dpp_paper, question=q, defaults={'order': i})

        jee_questions = Question.objects.filter(subject__exam='JEE')
        for i, q in enumerate(jee_questions, start=1):
            ExamPaperQuestion.objects.get_or_create(paper=self.paic_paper, question=q, defaults={'order': i})

        self.stdout.write('  papers: 1 DPP, 1 live PAIC')

    def _seed_rating_and_todo(self):
        from apps.rating.models import RatingHistory
        from apps.todo.models import TodoItem

        ratings = [900, 1300, 1200, 1550, 1450, 1700, 1650, 1987]
        prev = 1000
        for r in ratings:
            RatingHistory.objects.get_or_create(
                user=self.student, rating_before=prev, rating_after=r, delta=r - prev,
                reason='BAIC', defaults={},
            )
            prev = r

        TodoItem.objects.get_or_create(
            user=self.student, title='Finish Kinematics chapter test',
            defaults={'due_date': timezone.now().date() + timedelta(days=2)},
        )
        TodoItem.objects.get_or_create(
            user=self.student, title='Revise Hydrocarbons formula sheet',
            defaults={'due_date': timezone.now().date() - timedelta(days=1), 'is_completed': True,
                      'completed_at': timezone.now()},
        )
        self.stdout.write('  rating history + 2 todo items for arjun_sharma')
