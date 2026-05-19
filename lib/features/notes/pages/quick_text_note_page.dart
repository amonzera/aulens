import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/providers/notes_provider.dart';
import '../../../shared/providers/schedule_provider.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../schedule/models/schedule_entry.dart';
import '../../schedule/models/subject.dart';

/// Minimal and fast flow for creating a text note from the main bottom bar.
class QuickTextNotePage extends StatefulWidget {
  const QuickTextNotePage({super.key});

  @override
  State<QuickTextNotePage> createState() => _QuickTextNotePageState();
}

class _QuickTextNotePageState extends State<QuickTextNotePage> {
  final _textController = TextEditingController();

  Subject? _selectedSubject;
  Subject? _detectedSubject;
  ScheduleEntry? _detectedEntry;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initDetectedSubject();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _initDetectedSubject() {
    final scheduleProvider = context.read<ScheduleProvider>();
    final settings = context.read<SettingsProvider>();

    final entry = scheduleProvider.getCurrentClass(
      preGraceMinutes: settings.preGraceMinutes,
      postGraceMinutes: settings.postGraceMinutes,
    );

    final now = DateTime.now();
    final detected = entry != null
        ? scheduleProvider.resolveSubjectForEntryOnDate(entry, now)
        : null;

    final fallback = scheduleProvider.subjects.isNotEmpty
        ? scheduleProvider.subjects.first
        : null;

    setState(() {
      _detectedEntry = entry;
      _detectedSubject = detected;
      _selectedSubject = detected ?? fallback;
    });
  }

  Future<void> _save() async {
    if (_saving) return;

    final notesProvider = context.read<NotesProvider>();
    final scheduleProvider = context.read<ScheduleProvider>();

    final text = _textController.text.trim();
    if (text.isEmpty) {
      AppSnackBar.showInfo(context, 'Write a quick note first.');
      return;
    }

    final subject = _selectedSubject;
    final subjectId = subject?.id;
    if (subjectId == null) {
      AppSnackBar.showError(
        context,
        'Create a subject in Schedule before adding notes.',
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await notesProvider.addTextNote(subjectId: subjectId, textContent: text);

      final detectedEntry = _detectedEntry;
      final detectedSubjectId = _detectedSubject?.id;
      final selectedSubjectId = subjectId;

      if (detectedEntry != null &&
          detectedSubjectId != null &&
          detectedSubjectId != selectedSubjectId) {
        final entryId = detectedEntry.id;
        if (entryId != null) {
          await scheduleProvider.setSessionOverride(
            scheduleEntryId: entryId,
            date: DateTime.now(),
            subjectId: selectedSubjectId,
          );
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackBar.showError(context, 'Failed to save note. Please try again.');
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheduleProvider = context.watch<ScheduleProvider>();
    final subjects = scheduleProvider.subjects;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick text note'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_detectedSubject != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Detected: ${_detectedSubject!.name}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            DropdownButtonFormField<Subject>(
              initialValue: subjects.contains(_selectedSubject)
                  ? _selectedSubject
                  : (subjects.isNotEmpty ? subjects.first : null),
              decoration: const InputDecoration(labelText: 'Subject'),
              items: subjects
                  .map(
                    (subject) => DropdownMenuItem<Subject>(
                      value: subject,
                      child: Text(subject.name),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _selectedSubject = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _textController,
                autofocus: true,
                enabled: !_saving,
                maxLines: null,
                expands: true,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  alignLabelWithHint: true,
                  labelText: 'Note',
                  hintText: 'Type and tap Save',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
