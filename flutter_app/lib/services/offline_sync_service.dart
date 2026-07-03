import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../api/api_client.dart';
import 'pdf_cache_service.dart';

class OfflineSyncService {
  static const String _answersBox = 'offline_answers';
  static const String _submitsBox = 'offline_submits';
  static const String _attemptsBox = 'offline_attempts';
  static const String _manifestBox = 'library_manifest';
  
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    
    await Hive.openBox(_answersBox);
    await Hive.openBox(_submitsBox);
    await Hive.openBox(_attemptsBox);
    await Hive.openBox(_manifestBox);
    
    _initialized = true;

    // Attempt a flush whenever connectivity is restored.
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        flushQueue();
      }
    });
  }

  /// Sync library manifest from server and return list of library items
  static Future<List<Map<String, dynamic>>> syncLibraryManifest() async {
    try {
      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        // Offline - return cached items
        return _getCachedLibraryItems();
      }
      
      // Online - fetch from server
      final response = await ApiClient.dio.get('/api/sync/library/manifest/');
      final manifest = List<Map<String, dynamic>>.from(response.data);
      
      // Reconcile with local cache
      await PdfCacheService.reconcileWithManifest(manifest);
      
      // Cache the manifest locally
      final box = Hive.box(_manifestBox);
      await box.put('manifest', jsonEncode(manifest));
      
      return manifest;
    } catch (e) {
      // If server fails, return cached items
      return _getCachedLibraryItems();
    }
  }

  /// Get cached library items from local storage
  static List<Map<String, dynamic>> _getCachedLibraryItems() {
    try {
      final box = Hive.box(_manifestBox);
      final cached = box.get('manifest');
      if (cached != null) {
        return List<Map<String, dynamic>>.from(jsonDecode(cached));
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get library items from local PDF cache
  static Future<List<Map<String, dynamic>>> getLocalLibraryItems() async {
    try {
      final items = await PdfCacheService.listLibraryItems();
      return items.map((item) {
        return {
          'paper_id': item['paper_id'],
          'title': item['title'] ?? 'Paper',
          'pdf_url': 'file://${item['question_path']}',
          'still_accessible': item['still_accessible'] ?? true,
          'paper_type': 'Cached',
          'downloaded_at': item['downloaded_at'],
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

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
    }));
  }

  static Future<void> queueSubmit(int attemptId) async {
    final box = Hive.box(_submitsBox);
    await box.put(attemptId.toString(), jsonEncode({
      'attempt_id': attemptId,
      'submitted_at': DateTime.now().toIso8601String(),
    }));
  }

  static Future<void> saveFullOfflineAttempt({
    required String localId,
    required int paperId,
    required DateTime startedAt,
    required DateTime submittedAt,
    required List<Map<String, dynamic>> answers,
  }) async {
    final box = Hive.box(_attemptsBox);
    await box.put(localId, jsonEncode({
      'local_id': localId,
      'paper_id': paperId,
      'started_at': startedAt.toIso8601String(),
      'submitted_at': submittedAt.toIso8601String(),
      'answers': answers,
    }));
  }

  static Future<void> flushQueue() async {
    await _flushAnswers();
    await _flushSubmits();
    await _flushFullAttempts();
  }

  static Future<void> _flushAnswers() async {
    final box = Hive.box(_answersBox);
    for (final key in box.keys.toList()) {
      final entry = jsonDecode(box.get(key));
      try {
        await ApiClient.dio.patch(
          '/api/exams/attempts/${entry['attempt_id']}/answer/${entry['question_id']}/',
          data: entry['payload'],
        );
        await box.delete(key);
      } catch (_) {
        // Still offline or server error — leave queued, try again next flush.
      }
    }
  }

  static Future<void> _flushSubmits() async {
    final box = Hive.box(_submitsBox);
    for (final key in box.keys.toList()) {
      final entry = jsonDecode(box.get(key));
      try {
        await ApiClient.dio.post('/api/exams/attempts/${entry['attempt_id']}/submit/');
        await box.delete(key);
      } catch (_) {}
    }
  }

  static Future<void> _flushFullAttempts() async {
    final box = Hive.box(_attemptsBox);
    if (box.isEmpty) return;

    final payload = box.keys.map((k) => jsonDecode(box.get(k))).toList();
    try {
      await ApiClient.dio.post('/api/sync/attempts/push/', data: {'attempts': payload});
      await box.clear();
    } catch (_) {
      // Leave queued for next connectivity window.
    }
  }

  static int get pendingCount {
    return Hive.box(_answersBox).length + 
           Hive.box(_submitsBox).length + 
           Hive.box(_attemptsBox).length;
  }
}