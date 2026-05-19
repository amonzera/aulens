import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/providers/notes_provider.dart';
import '../../../shared/providers/schedule_provider.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../schedule/models/subject.dart';
import '../../timeline/widgets/class_timeline_view.dart';
import 'add_text_note_page.dart';
import 'note_detail_page.dart';

/// Subject-focused notes timeline used from home schedule cards.
class SubjectTimelinePage extends StatelessWidget {
  final Subject subject;

  const SubjectTimelinePage({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(subject.name)),
      body: Consumer3<ScheduleProvider, NotesProvider, SettingsProvider>(
        builder: (context, schedule, notes, settings, _) {
          if (notes.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = schedule.entriesForSubject(
            subject.id!,
            includeArchivedSubject: subject.isArchived,
          );
          final sessions = notes.sessionsForSubject(
            subject: subject,
            scheduleEntries: entries,
            preGraceMinutes: settings.preGraceMinutes,
            postGraceMinutes: settings.postGraceMinutes,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddTextNotePage(subject: subject),
                    ),
                  ),
                  icon: const Icon(Icons.note_add_outlined, size: 18),
                  label: const Text('Add Text Note'),
                ),
              ),
              ClassTimelineView(
                sessions: sessions,
                onNoteTap: (note) => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => NoteDetailPage(note: note)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
