import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../api/api_client.dart';

/// Downloads a paper's PDF (question paper + solution, streamed from the
/// Backblaze B2-backed signed URL the API returns) into local device
/// storage for the "My Library" offline viewing feature (point #5).
///
/// Metadata (paper id, title, local file paths, whether it's still
/// accessible under the user's premium status) lives in the 'library_meta'
/// Hive box; the actual PDF bytes live as plain files under the app's
/// documents directory so the PDF viewer can open them by path without
/// re-downloading.
class PdfCacheService {
  static const _metaBox = 'library_meta';

  static Future<void> init() async {
    await Hive.openBox(_metaBox);
  }

  static Future<Directory> _libraryDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final libDir = Directory('${dir.path}/library');
    if (!await libDir.exists()) await libDir.create(recursive: true);
    return libDir;
  }

  /// Downloads and caches a paper. Call after the user taps "Save to
  /// Library" on a paper's detail screen.
  static Future<void> downloadPaper({
    required int paperId,
    required String title,
    required String pdfUrl,
    String? solutionUrl,
  }) async {
    final dir = await _libraryDir();
    final questionPath = '${dir.path}/paper_$paperId.pdf';
    await ApiClient.dio.download(pdfUrl, questionPath);

    String? solutionPath;
    if (solutionUrl != null) {
      solutionPath = '${dir.path}/paper_${paperId}_solution.pdf';
      await ApiClient.dio.download(solutionUrl, solutionPath);
    }

    final box = Hive.box(_metaBox);
    await box.put(paperId.toString(), {
      'paper_id': paperId,
      'title': title,
      'question_path': questionPath,
      'solution_path': solutionPath,
      'still_accessible': true,
      'downloaded_at': DateTime.now().toIso8601String(),
    });
  }

  static List<Map> listLibraryItems() {
    final box = Hive.box(_metaBox);
    return box.values.cast<Map>().toList();
  }

  /// Called after pulling /api/sync/library/manifest/: flips
  /// `still_accessible` to false and deletes the cached solution PDF for
  /// any paper whose premium access has lapsed (point #23). The question
  /// paper itself and the user's own attempt stats remain.
  static Future<void> reconcileWithManifest(List<Map<String, dynamic>> manifest) async {
    final box = Hive.box(_metaBox);
    for (final entry in manifest) {
      final key = entry['paper_id'].toString();
      final local = box.get(key);
      if (local == null) continue;

      if (entry['still_accessible'] == false) {
        final solutionPath = local['solution_path'];
        if (solutionPath != null) {
          final f = File(solutionPath);
          if (await f.exists()) await f.delete();
        }
        local['still_accessible'] = false;
        local['solution_path'] = null;
        await box.put(key, local);
      }
    }
  }

  static Future<void> deletePaper(int paperId) async {
    final box = Hive.box(_metaBox);
    final entry = box.get(paperId.toString());
    if (entry != null) {
      for (final path in [entry['question_path'], entry['solution_path']]) {
        if (path != null) {
          final f = File(path);
          if (await f.exists()) await f.delete();
        }
      }
      await box.delete(paperId.toString());
    }
  }
}
