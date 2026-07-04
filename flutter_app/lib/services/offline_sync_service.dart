import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../api/api_client.dart';

/// Offline-first sync layer (point #5: attempt DPP/PYQ/chapter tests offline,
/// checked once connectivity returns). Uses two Hive boxes:
///   - 'queued_answers'   : per-question PATCH payloads not yet confirmed by the server
///   - 'queued_submits'   : attempt IDs whose final submit call hasn't gone through
///
/// Call OfflineSyncService.init() once at app startup, and
/// OfflineSyncService.flush() whenever connectivity is restored (e.g. from
/// a connectivity_plus listener) or periodically in the background.
class OfflineSyncService {
  static const _answersBox = 'queued_answers';
  static const _submitsBox = 'queued_submits';
  static const _libraryBox = 'library_papers';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_answersBox);
    await Hive.openBox(_submitsBox);
    await Hive.openBox(_libraryBox);
  }

  // ---- Queueing (called when a live API call fails) ----

  static Future<void> queueAnswer({
    required int attemptId,
    required int questionId,
    required Map<String, dynamic> payload,
  }) async {
    final box = Hive.box(_answersBox);
    final key = '$attemptId:$questionId';
    await box.put(key, jsonEncode({
      'attempt_id': attemptId,
      'question_id': questionId,
      'payload': payload,
      'queued_at': DateTime.now().toIso8601String(),
    }));
  }

  static Future<void> queueSubmit(int attemptId) async {
    final box = Hive.box(_submitsBox);
    await box.put(attemptId.toString(), DateTime.now().toIso8601String());
  }

  // ---- Flushing (called when connectivity returns) ----

  /// Pushes every queued answer + submit to the backend. Safe to call
  /// repeatedly; already-flushed entries are removed as they succeed so a
  /// partial failure (e.g. mid-flush disconnect) just resumes next time.
  static Future<void> flush() async {
    await _flushAnswers();
    await _flushSubmits();
  }

  static Future<void> _flushAnswers() async {
    final box = Hive.box(_answersBox);
    for (final key in box.keys.toList()) {
      final entry = jsonDecode(box.get(key) as String);
      try {
        await ApiClient.dio.patch(
          '/api/exams/attempts/${entry['attempt_id']}/answer/${entry['question_id']}/',
          data: entry['payload'],
        );
        await box.delete(key);
      } catch (_) {
        // Still offline or server error — leave queued, try again next flush.
        break;
      }
    }
  }

  static Future<void> _flushSubmits() async {
    final box = Hive.box(_submitsBox);
    for (final key in box.keys.toList()) {
      try {
        await ApiClient.dio.post('/api/exams/attempts/$key/submit/');
        await box.delete(key);
      } catch (_) {
        break;
      }
    }
  }

  // ---- My Library manifest sync (point #23: revoke access on premium expiry) ----

  static Future<List<Map<String, dynamic>>> syncLibraryManifest() async {
    try {
      final resp = await ApiClient.dio.get('/api/sync/library/manifest/');
      final box = Hive.box(_libraryBox);
      final items = List<Map<String, dynamic>>.from(resp.data);

      for (final item in items) {
        await box.put(item['paper_id'].toString(), jsonEncode(item));
        if (item['still_accessible'] == false) {
          // Premium lapsed — drop any cached PDF bytes for this paper.
          await box.delete('pdf_bytes_${item['paper_id']}');
        }
      }
      return items;
    } catch (_) {
      // Offline — fall back to whatever's cached locally.
      final box = Hive.box(_libraryBox);
      return box.values
          .where((v) => v is String && v.startsWith('{'))
          .map((v) => Map<String, dynamic>.from(jsonDecode(v as String)))
          .toList();
    }
  }

  static int get pendingCount {
    return Hive.box(_answersBox).length + Hive.box(_submitsBox).length;
  }
}
