import 'dart:async';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum CameraTaskStatus { queued, processingOcr, savingNote, completed, failed }

class CameraTaskEvent {
  final String taskId;
  final int subjectId;
  final String imagePath;
  final DateTime createdAt;
  final CameraTaskStatus status;
  final String? ocrText;
  final Object? error;

  const CameraTaskEvent({
    required this.taskId,
    required this.subjectId,
    required this.imagePath,
    required this.createdAt,
    required this.status,
    this.ocrText,
    this.error,
  });
}

/// Handles camera access and persists captured images to the app's
/// documents directory so they survive app restarts.
class CameraService {
  CameraService._();
  static final CameraService instance = CameraService._();

  final _picker = ImagePicker();
  final _eventController = StreamController<CameraTaskEvent>.broadcast();
  String? _imagesDirPath;

  /// Emits lifecycle updates for background OCR tasks.
  Stream<CameraTaskEvent> get taskEvents => _eventController.stream;

  /// Opens the device camera. On success, copies the captured image to a
  /// permanent location and returns that absolute path.
  ///
  /// Returns `null` if the user dismissed the camera without taking a photo.
  Future<String?> capturePhoto({bool saveToGallery = false}) async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (file == null) return null;
    return _persist(file, saveToGallery: saveToGallery);
  }

  /// Preloads camera dependencies and storage paths to reduce first-use latency.
  Future<void> preload() async {
    await _ensureImagesDir();
  }

  /// Starts OCR + persistence in the background and returns immediately.
  ///
  /// Important: ML Kit uses platform channels and should run on the main
  /// isolate. This pipeline is still non-blocking because all steps are async
  /// and the UI thread is never synchronously blocked waiting for completion.
  ///
  /// [runOcr] extracts text from [imagePath].
  /// [saveNote] persists the extracted text in DB.
  ///
  /// Returns a generated task id that can be tracked via [taskEvents].
  String enqueueBackgroundOcr({
    required int subjectId,
    required String imagePath,
    required DateTime createdAt,
    required Future<String?> Function(String imagePath) runOcr,
    required Future<void> Function(String? ocrText) saveNote,
  }) {
    final taskId = DateTime.now().microsecondsSinceEpoch.toString();

    _emit(
      CameraTaskEvent(
        taskId: taskId,
        subjectId: subjectId,
        imagePath: imagePath,
        createdAt: createdAt,
        status: CameraTaskStatus.queued,
      ),
    );

    unawaited(
      _runTask(
        taskId: taskId,
        subjectId: subjectId,
        imagePath: imagePath,
        createdAt: createdAt,
        runOcr: runOcr,
        saveNote: saveNote,
      ),
    );

    return taskId;
  }

  Future<void> _runTask({
    required String taskId,
    required int subjectId,
    required String imagePath,
    required DateTime createdAt,
    required Future<String?> Function(String imagePath) runOcr,
    required Future<void> Function(String? ocrText) saveNote,
  }) async {
    try {
      _emit(
        CameraTaskEvent(
          taskId: taskId,
          subjectId: subjectId,
          imagePath: imagePath,
          createdAt: createdAt,
          status: CameraTaskStatus.processingOcr,
        ),
      );

      final ocrText = await runOcr(imagePath);

      _emit(
        CameraTaskEvent(
          taskId: taskId,
          subjectId: subjectId,
          imagePath: imagePath,
          createdAt: createdAt,
          status: CameraTaskStatus.savingNote,
          ocrText: ocrText,
        ),
      );

      await saveNote(ocrText);

      _emit(
        CameraTaskEvent(
          taskId: taskId,
          subjectId: subjectId,
          imagePath: imagePath,
          createdAt: createdAt,
          status: CameraTaskStatus.completed,
          ocrText: ocrText,
        ),
      );
    } catch (e) {
      _emit(
        CameraTaskEvent(
          taskId: taskId,
          subjectId: subjectId,
          imagePath: imagePath,
          createdAt: createdAt,
          status: CameraTaskStatus.failed,
          error: e,
        ),
      );
    }
  }

  Future<String> _persist(XFile file, {required bool saveToGallery}) async {
    final dirPath = await _ensureImagesDir();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final dest = p.join(dirPath, 'wb_$ts.jpg');
    await File(file.path).copy(dest);

    // Keep `dest` as the canonical in-app path. Gallery export is optional
    // and best-effort, so failures never break note capture or internal storage.
    if (saveToGallery) {
      try {
        await Gal.putImage(dest, album: 'Aulens');
      } catch (_) {
        // Ignore gallery export errors to preserve capture reliability.
      }
    }

    return dest;
  }

  Future<String> _ensureImagesDir() async {
    final cached = _imagesDirPath;
    if (cached != null) return cached;

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'aulens_images'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _imagesDirPath = dir.path;
    return dir.path;
  }

  Future<void> deleteCapturedPhotoIfOwned(String imagePath) async {
    if (!await _isManagedImagePath(imagePath)) {
      return;
    }

    final file = File(imagePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<bool> _isManagedImagePath(String imagePath) async {
    final docs = await getApplicationDocumentsDirectory();
    final imagesDir = p.normalize(p.join(docs.path, 'aulens_images'));
    final candidate = p.normalize(imagePath);
    return p.isWithin(imagesDir, candidate);
  }

  void _emit(CameraTaskEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  Future<void> dispose() async {
    await _eventController.close();
  }
}
