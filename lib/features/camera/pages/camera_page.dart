import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/providers/notes_provider.dart';
import '../../../shared/providers/schedule_provider.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/permission_alerts.dart';
import '../../schedule/models/schedule_entry.dart';
import '../../schedule/models/subject.dart';
import '../services/camera_service.dart';
import '../services/ocr_service.dart';
import '../services/permission_service.dart';

// ── State machine ─────────────────────────────────────────────────────────────
enum _CaptureState { idle, processing }

/// Camera tab – guides the student through capturing a whiteboard photo,
/// auto-detecting the current class, running OCR and saving the note.
class CameraPage extends StatefulWidget {
  final bool autoCapture;
  final Subject? fixedSubject;

  const CameraPage({super.key, this.autoCapture = false, this.fixedSubject});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  _CaptureState _state = _CaptureState.idle;
  bool _saving = false;
  bool _autoCaptureDone = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoCapture) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _autoCaptureDone) return;
        _autoCaptureDone = true;
        _capture();
      });
    }
  }

  // ── Capture flow ───────────────────────────────────────────────────────────

  Future<void> _capture() async {
    if (_state == _CaptureState.processing || _saving) {
      return;
    }

    // Capture the provider reference before any async gap.
    final scheduleProvider = context.read<ScheduleProvider>();
    final settings = context.read<SettingsProvider>();

    final permissionResult = await PermissionService.instance
        .ensureCameraFlowPermissions();
    if (!mounted) return;

    if (permissionResult == PermissionFlowResult.denied) {
      await PermissionAlerts.showDenied(context);
      return;
    }

    if (permissionResult == PermissionFlowResult.permanentlyDenied) {
      await PermissionAlerts.showPermanentlyDenied(context);
      return;
    }

    setState(() => _state = _CaptureState.processing);

    String? path;
    try {
      // 1. Take photo and persist to documents directory.
      path = await CameraService.instance.capturePhoto(
        saveToGallery: settings.savePhotosToGallery,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _CaptureState.idle);
      AppSnackBar.showError(context, 'Unable to open camera right now.');
      return;
    }

    if (path == null) {
      // User cancelled – go back to idle.
      if (!mounted) return;
      setState(() => _state = _CaptureState.idle);
      return;
    }

    // 2. Auto-detect current class from schedule.
    final now = DateTime.now();
    final entry = scheduleProvider.getCurrentClass(
      preGraceMinutes: settings.preGraceMinutes,
      postGraceMinutes: settings.postGraceMinutes,
    );
    final detected = entry != null
        ? scheduleProvider.resolveSubjectForEntryOnDate(entry, now)
        : null;
    final subject = widget.fixedSubject ?? detected;

    await _saveCaptured(
      imagePath: path,
      selectedSubject: subject,
      detectedSubject: detected,
      entry: entry,
      capturedAt: now,
    );
  }

  // ── Save / discard ─────────────────────────────────────────────────────────

  Future<void> _saveCaptured({
    required String imagePath,
    required Subject? selectedSubject,
    required Subject? detectedSubject,
    required ScheduleEntry? entry,
    required DateTime capturedAt,
  }) async {
    if (_saving) return;
    final subjectId = selectedSubject?.id;
    final notesProvider = context.read<NotesProvider>();
    final scheduleProvider = context.read<ScheduleProvider>();

    setState(() => _saving = true);
    try {
      final savedNote = await notesProvider.addPhotoNote(
        subjectId: subjectId,
        imagePath: imagePath,
        ocrText: null,
      );

      if (entry != null &&
          subjectId != null &&
          detectedSubject != null &&
          detectedSubject.id != subjectId) {
        final entryId = entry.id;
        if (entryId != null) {
          await scheduleProvider.setSessionOverride(
            scheduleEntryId: entryId,
            date: capturedAt,
            subjectId: subjectId,
          );
        }
      }

      CameraService.instance.enqueueBackgroundOcr(
        subjectId: subjectId ?? -1,
        imagePath: imagePath,
        createdAt: DateTime.now(),
        runOcr: OcrService.instance.extractText,
        saveNote: (ocrText) async {
          if (savedNote.id != null) {
            await notesProvider.updateOcrText(savedNote.id!, ocrText);
          }
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackBar.showError(context, 'Failed to save note. Please try again.');
      return;
    }

    if (!mounted) return;
    _resetToIdle();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _capture();
    });
  }

  void _resetToIdle() => setState(() {
    _state = _CaptureState.idle;
    _saving = false;
  });

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera')),
      body: switch (_state) {
        _CaptureState.idle => _IdleView(onCapture: _capture),
        _CaptureState.processing => const _ProcessingView(),
      },
    );
  }
}

// ── Idle view ─────────────────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  final VoidCallback onCapture;
  const _IdleView({required this.onCapture});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.camera_alt_outlined, size: 80, color: cs.outlineVariant),
          const SizedBox(height: 16),
          Text(
            'Capture a whiteboard',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'The app will detect your current class\n'
            'and extract the text automatically.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 40),
          FloatingActionButton.large(
            heroTag: 'capture_fab',
            onPressed: onCapture,
            child: const Icon(Icons.camera_alt, size: 36),
          ),
        ],
      ),
    );
  }
}

// ── Processing view ───────────────────────────────────────────────────────────

class _ProcessingView extends StatelessWidget {
  const _ProcessingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Saving photo and starting OCR…'),
        ],
      ),
    );
  }
}
