import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../../timeline/widgets/class_timeline_view.dart';
import '../../timeline/models/class_session.dart';
import '../../schedule/models/subject.dart';
import '../../../shared/providers/notes_provider.dart';
import '../../../shared/providers/schedule_provider.dart';
import '../../../shared/providers/settings_provider.dart';
import 'add_text_note_page.dart';
import 'note_detail_page.dart';

/// Notes tab – shows all subjects with sleek timeline feed sections.
class NotesPage extends StatelessWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: Consumer3<ScheduleProvider, NotesProvider, SettingsProvider>(
        builder: (context, schedule, notes, settings, _) {
          if (notes.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (schedule.subjects.isEmpty) {
            if (notes.unclassifiedNotes().isEmpty) {
              return const _EmptyState();
            }
          }

          final unclassified = notes.unclassifiedNotes();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount:
                schedule.subjects.length + (unclassified.isNotEmpty ? 1 : 0),
            itemBuilder: (context, i) {
              if (unclassified.isNotEmpty && i == 0) {
                return _UnclassifiedExpansion(notes: unclassified);
              }

              final subjectIndex = unclassified.isNotEmpty ? i - 1 : i;
              if (subjectIndex < 0 ||
                  subjectIndex >= schedule.subjects.length) {
                return const SizedBox.shrink();
              }

              final subject = schedule.subjects[subjectIndex];
              final entries = schedule.entriesForSubject(subject.id!);
              final sessions = notes.sessionsForSubject(
                subject: subject,
                scheduleEntries: entries,
                preGraceMinutes: settings.preGraceMinutes,
                postGraceMinutes: settings.postGraceMinutes,
              );
              return _SubjectExpansion(subject: subject, sessions: sessions);
            },
          );
        },
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 72,
              color: cs.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No notes yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Capture whiteboard photos from the Camera tab\n'
              'to start building your collection.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Subject expansion tile ────────────────────────────────────────────────────

class _SubjectExpansion extends StatelessWidget {
  final Subject subject;
  final List<ClassSession> sessions;

  const _SubjectExpansion({required this.subject, required this.sessions});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Text(
            subject.name[0].toUpperCase(),
            style: TextStyle(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          subject.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: _SessionCountSubtitle(sessions: sessions),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Align(
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
          ),
          ClassTimelineView(
            sessions: sessions,
            onNoteTap: (note) => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NoteDetailPage(note: note)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCountSubtitle extends StatelessWidget {
  final List<ClassSession> sessions;
  const _SessionCountSubtitle({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final total = sessions.fold<int>(
      0,
      (sum, s) => sum + s.notes.length + s.processingNotes.length,
    );
    return Text('$total item${total == 1 ? '' : 's'}');
  }
}

class _UnclassifiedExpansion extends StatelessWidget {
  final List<Note> notes;

  const _UnclassifiedExpansion({required this.notes});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sessions = _buildUnclassifiedSessions(notes);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: cs.surfaceContainerHighest,
          child: Icon(Icons.folder_open_outlined, color: cs.onSurfaceVariant),
        ),
        title: const Text(
          'Unclassified',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${notes.length} item${notes.length == 1 ? '' : 's'}'),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        children: [
          ClassTimelineView(
            sessions: sessions,
            onNoteTap: (note) => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NoteDetailPage(note: note)),
            ),
          ),
        ],
      ),
    );
  }

  List<ClassSession> _buildUnclassifiedSessions(List<Note> source) {
    if (source.isEmpty) return const <ClassSession>[];

    final ordered = [...source]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final byDate = <DateTime, List<Note>>{};

    for (final note in ordered) {
      final day = DateTime(
        note.createdAt.year,
        note.createdAt.month,
        note.createdAt.day,
      );
      byDate.putIfAbsent(day, () => <Note>[]).add(note);
    }

    final days = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
    const placeholderSubject = Subject(id: -1, name: 'Unclassified');

    return days
        .map(
          (day) => ClassSession(
            subject: placeholderSubject,
            date: day,
            scheduleEntry: null,
            notes: byDate[day]!,
            processingNotes: const [],
            isUnscheduled: true,
          ),
        )
        .toList();
  }
}
