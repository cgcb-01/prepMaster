import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:dio/dio.dart';

/// Optional exam proctoring (point #8): periodically samples the front
/// camera, runs on-device face detection, and only uploads a snapshot to
/// the backend when something is actually wrong (no face / multiple faces).
/// No continuous video is streamed or stored — this keeps it lightweight
/// and just checks no outside people... that's all
class ProctoringService {
  final Dio dio;
  final int sessionId;
  final Duration sampleInterval;

  CameraController? _controller;
  Timer? _timer;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
  );
  int _examSeconds = 0;

  ProctoringService({
    required this.dio,
    required this.sessionId,
    this.sampleInterval = const Duration(seconds: 8),
  });

  Future<void> start() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _controller = CameraController(front, ResolutionPreset.low, enableAudio: false);
    await _controller!.initialize();

    _timer = Timer.periodic(sampleInterval, (_) => _sampleFrame());
  }

  Future<void> _sampleFrame() async {
    _examSeconds += sampleInterval.inSeconds;
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final file = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        await _reportFlag('NO_FACE', file.path);
      } else if (faces.length > 1) {
        await _reportFlag('MULTIPLE_FACES', file.path);
      } else {
        await File(file.path).delete().catchError((_) => file);
      }
    } catch (_) {
      
    }
  }

  Future<void> _reportFlag(String flagType, String imagePath) async {
    final formData = FormData.fromMap({
      'flag_type': flagType,
      'timestamp_in_exam_seconds': _examSeconds,
      'snapshot': await MultipartFile.fromFile(imagePath, filename: 'flag.jpg'),
    });
    try {
      await dio.post('/api/proctoring/$sessionId/flag/', data: formData);
    } catch (_) {
      // Network hiccup — non-fatal, just skip this sample.
    } finally {
      await File(imagePath).delete().catchError((_) => File(imagePath));
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    await _controller?.dispose();
    _faceDetector.close();
    try {
      await dio.post('/api/proctoring/$sessionId/end/');
    } catch (_) {}
  }
}