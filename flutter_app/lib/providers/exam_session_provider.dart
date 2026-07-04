import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/exam_models.dart';

/// Holds the in-progress AttemptSession + local answer state so the CBT/OMR
/// screens, the question palette, and a future "resume attempt" flow can
/// all share one source of truth instead of re-fetching. Currently the exam
/// screens manage their own local state directly (see cbt_exam_screen.dart)
/// for simplicity; migrate to this provider if a resume-across-screens flow
/// is needed (e.g. minimizing the exam to check something in another tab).
class ExamSessionState {
  final AttemptSession? session;
  final int currentIndex;
  const ExamSessionState({this.session, this.currentIndex = 0});

  ExamSessionState copyWith({AttemptSession? session, int? currentIndex}) => ExamSessionState(
        session: session ?? this.session,
        currentIndex: currentIndex ?? this.currentIndex,
      );
}

class ExamSessionNotifier extends StateNotifier<ExamSessionState> {
  ExamSessionNotifier() : super(const ExamSessionState());

  void start(AttemptSession session) => state = ExamSessionState(session: session, currentIndex: 0);
  void goTo(int index) => state = state.copyWith(currentIndex: index);
  void clear() => state = const ExamSessionState();
}

final examSessionProvider = StateNotifierProvider<ExamSessionNotifier, ExamSessionState>(
  (ref) => ExamSessionNotifier(),
);
