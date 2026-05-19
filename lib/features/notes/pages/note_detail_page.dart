import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/providers/notes_provider.dart';
import '../../../shared/providers/schedule_provider.dart';
import '../../schedule/models/subject.dart';
import 'full_screen_photo_viewer_page.dart';
import '../models/note.dart';

/// Full-detail view for a single note: photo, metadata and selectable OCR text.
class NoteDetailPage extends StatefulWidget {
  final Note note;
  const NoteDetailPage({super.key, required this.note});

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> {
  late Note _note;
  bool _updatingDetails = false;
  bool _loadingText = false;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadFullNote();
    });
  }

  Future<void> _loadFullNote() async {
    if (_note.id == null) return;
    setState(() => _loadingText = true);
    final fullNote = await context.read<NotesProvider>().getNoteById(_note.id!);
    if (fullNote != null && mounted) {
      setState(() {
        _note = fullNote;
        _loadingText = false;
      });
    } else if (mounted) {
      setState(() => _loadingText = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesProvider = context.watch<NotesProvider>();
    final schedule = context.watch<ScheduleProvider>();
    final noteSubjectId = _note.subjectId;
    final subject = noteSubjectId != null
        ? schedule.subjectById(noteSubjectId)
        : null;
    final subjectPhotos =
        (noteSubjectId != null
                ? notesProvider.notesForSubject(noteSubjectId)
                : notesProvider.unclassifiedNotes())
            .where((n) => n.hasImage)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final initialPhotoIndex = subjectPhotos.indexWhere((n) => n.id == _note.id);
    final galleryInitialIndex = initialPhotoIndex >= 0 ? initialPhotoIndex : 0;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(subject?.name ?? 'Unclassified'),
        actions: [
          if (_note.hasImage)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit photo details',
              onPressed: _updatingDetails ? null : _editPhotoDetails,
            ),
          if (_note.hasImage)
            IconButton(
              icon: const Icon(Icons.drive_file_move_outline),
              tooltip: 'Move photo to another subject',
              onPressed: _moveToAnotherSubject,
            ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: cs.error),
            tooltip: 'Delete note',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_note.hasImage) ...[
              // ── Photo ──────────────────────────────────────────────────
              AspectRatio(
                aspectRatio: 4 / 3,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FullScreenPhotoViewerPage(
                        photos: subjectPhotos,
                        initialIndex: galleryInitialIndex,
                      ),
                    ),
                  ),
                  child: Hero(
                    tag: _photoHeroTag(_note),
                    child: Image.file(
                      File(_note.imagePath!),
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => Container(
                        color: cs.surfaceContainerHighest,
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 56,
                          color: cs.outlineVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Metadata row ──────────────────────────────────────────
                  _MetaRow(
                    icon: Icons.schedule,
                    text: DateFormat(
                      'EEEE, MMMM d, yyyy · HH:mm',
                    ).format(_note.createdAt),
                  ),
                  if (subject != null) ...[
                    const SizedBox(height: 4),
                    _MetaRow(icon: Icons.school_outlined, text: subject.name),
                  ],
                  const SizedBox(height: 20),

                  if (_note.isTextNote) ...[
                    Text('Note', style: theme.textTheme.titleSmall),
                    const Divider(height: 12),
                    if (_loadingText)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      SelectableText(
                        _note.textContent ?? '',
                        style: theme.textTheme.bodyMedium,
                      ),
                  ] else ...[
                    // ── OCR text ─────────────────────────────────────────
                    Text('Extracted Text', style: theme.textTheme.titleSmall),
                    const Divider(height: 12),
                    if (_loadingText)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_note.ocrText != null)
                      SelectableText(
                        _note.ocrText!,
                        style: theme.textTheme.bodyMedium,
                      )
                    else
                      Text(
                        'No text was extracted from this image.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 20),
                    Text('Additional Notes', style: theme.textTheme.titleSmall),
                    const Divider(height: 12),
                    if ((_note.textContent ?? '').trim().isEmpty)
                      Text(
                        'No additional notes.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: cs.onSurfaceVariant,
                        ),
                      )
                    else
                      SelectableText(
                        _note.textContent!,
                        style: theme.textTheme.bodyMedium,
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text(
          _note.hasImage
              ? 'This note and its image file will be permanently deleted.'
              : 'This note will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<NotesProvider>().deleteNote(_note.id!);
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _moveToAnotherSubject() async {
    final scheduleProvider = context.read<ScheduleProvider>();
    final notesProvider = context.read<NotesProvider>();

    final subjects = scheduleProvider.subjects
        .where((s) => s.id != _note.subjectId)
        .toList();

    if (subjects.isEmpty) {
      AppSnackBar.showInfo(
        context,
        'No other subjects available to move this photo.',
      );
      return;
    }

    final target = await showModalBottomSheet<Subject>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView.builder(
          itemCount: subjects.length,
          itemBuilder: (context, index) {
            final subject = subjects[index];
            return ListTile(
              leading: const Icon(Icons.school_outlined),
              title: Text(subject.name),
              onTap: () => Navigator.pop(context, subject),
            );
          },
        ),
      ),
    );

    if (target == null || target.id == null || _note.id == null) return;

    await notesProvider.moveNoteToSubject(
      noteId: _note.id!,
      targetSubjectId: target.id!,
    );

    if (!mounted) return;
    setState(() => _note = _note.copyWith(subjectId: target.id));
    AppSnackBar.showInfo(context, 'Photo moved to ${target.name}.');
  }

  Future<void> _editPhotoDetails() async {
    final notesProvider = context.read<NotesProvider>();
    final scheduleProvider = context.read<ScheduleProvider>();
    final noteId = _note.id;
    if (noteId == null) return;

    final subjects = scheduleProvider.subjects;
    if (subjects.isEmpty) {
      AppSnackBar.showInfo(context, 'No subjects available.');
      return;
    }

    final ocrController = TextEditingController(text: _note.ocrText ?? '');
    final extraNotesController = TextEditingController(
      text: _note.textContent ?? '',
    );
    Subject? selectedSubject =
        (_note.subjectId != null
            ? scheduleProvider.subjectById(_note.subjectId!)
            : null) ??
        subjects.first;
    DateTime selectedDateTime = _note.createdAt;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Edit Photo Details',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Subject>(
                      initialValue: selectedSubject,
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      items: subjects
                          .map(
                            (subject) => DropdownMenuItem<Subject>(
                              value: subject,
                              child: Text(subject.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() => selectedSubject = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule_outlined),
                      title: const Text('Date and time'),
                      subtitle: Text(
                        DateFormat(
                          'EEEE, MMMM d, yyyy · HH:mm',
                        ).format(selectedDateTime),
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDateTime,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (date == null || !ctx.mounted) return;
                          final time = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay.fromDateTime(
                              selectedDateTime,
                            ),
                            builder: (context, child) => MediaQuery(
                              data: MediaQuery.of(
                                context,
                              ).copyWith(alwaysUse24HourFormat: true),
                              child: child!,
                            ),
                          );
                          if (time == null) return;
                          setModalState(() {
                            selectedDateTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        },
                        child: const Text('Change'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ocrController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Extracted OCR text',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: extraNotesController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Additional notes',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Save changes'),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true || selectedSubject?.id == null) {
      ocrController.dispose();
      extraNotesController.dispose();
      return;
    }

    if (!mounted) {
      ocrController.dispose();
      extraNotesController.dispose();
      return;
    }

    final normalizedOcr = ocrController.text.trim().isEmpty
        ? null
        : ocrController.text.trim();
    final normalizedText = extraNotesController.text.trim().isEmpty
        ? null
        : extraNotesController.text.trim();

    setState(() => _updatingDetails = true);
    try {
      await notesProvider.updateNoteDetails(
        noteId: noteId,
        subjectId: selectedSubject!.id!,
        createdAt: selectedDateTime,
        ocrText: normalizedOcr,
        textContent: normalizedText,
      );
      if (!mounted) return;
      setState(() {
        _note = _note.copyWith(
          subjectId: selectedSubject!.id,
          createdAt: selectedDateTime,
          ocrText: normalizedOcr,
          textContent: normalizedText,
        );
      });
      AppSnackBar.showInfo(context, 'Photo details updated.');
    } finally {
      if (mounted) {
        setState(() => _updatingDetails = false);
      }
      ocrController.dispose();
      extraNotesController.dispose();
    }
  }
}

String _photoHeroTag(Note note) {
  return 'note-photo-${note.id ?? note.imagePath}-${note.createdAt.millisecondsSinceEpoch}';
}

// ── Metadata row widget ───────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
