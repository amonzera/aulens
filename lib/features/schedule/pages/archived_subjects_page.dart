import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../shared/providers/notes_provider.dart';
import '../../../shared/providers/schedule_provider.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../notes/pages/subject_timeline_page.dart';
import '../models/subject.dart';

class ArchivedSubjectsPage extends StatelessWidget {
  const ArchivedSubjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archived Subjects')),
      body: Consumer2<ScheduleProvider, NotesProvider>(
        builder: (context, schedule, notes, _) {
          final archived = schedule.archivedSubjects.toList()
            ..sort((a, b) => a.name.compareTo(b.name));

          if (archived.isEmpty) {
            return const _ArchivedEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount: archived.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final subject = archived[index];
              final lastActivity = _lastActivityForSubject(notes, subject);
              return _ArchivedSubjectCard(
                subject: subject,
                lastActivity: lastActivity,
                onViewContent: () => _openTimeline(context, subject),
                onRestore: () => _restoreSubject(context, subject),
                onDelete: () => _confirmPermanentDelete(context, subject),
              );
            },
          );
        },
      ),
    );
  }

  DateTime? _lastActivityForSubject(NotesProvider notes, Subject subject) {
    final subjectId = subject.id;
    if (subjectId == null) return null;
    final list = notes.notesForSubject(subjectId);
    if (list.isEmpty) return null;
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.first.createdAt;
  }

  void _openTimeline(BuildContext context, Subject subject) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SubjectTimelinePage(subject: subject)),
    );
  }

  Future<void> _restoreSubject(BuildContext context, Subject subject) async {
    final id = subject.id;
    if (id == null) return;
    await context.read<ScheduleProvider>().restoreSubject(id);
    if (!context.mounted) return;
    AppSnackBar.showInfo(context, 'Subject restored.');
  }

  void _confirmPermanentDelete(BuildContext context, Subject subject) {
    final id = subject.id;
    if (id == null) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permanently Delete Subject'),
        content: Text(
          'Delete "${subject.name}" and all related schedule entries, notes and photos?\n'
          'This action cannot be undone.',
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
              await context.read<ScheduleProvider>().deleteSubject(id);
              if (!context.mounted) return;
              context.read<NotesProvider>().removeNotesBySubject(id);
              AppSnackBar.showInfo(context, 'Subject deleted permanently.');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ArchivedSubjectCard extends StatelessWidget {
  final Subject subject;
  final DateTime? lastActivity;
  final VoidCallback onViewContent;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _ArchivedSubjectCard({
    required this.subject,
    required this.lastActivity,
    required this.onViewContent,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final professor = subject.professor?.trim();
    final hasProfessor = professor != null && professor.isNotEmpty;
    final subtitle = lastActivity == null
        ? 'No activity yet'
        : 'Last activity: ${DateFormat('MMM d, yyyy • HH:mm').format(lastActivity!)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    subject.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(Icons.archive, size: 18, color: cs.onSurfaceVariant),
              ],
            ),
            if (hasProfessor)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  professor,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onViewContent,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('View Content'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onRestore,
                  icon: const Icon(Icons.unarchive_outlined, size: 18),
                  label: const Text('Restore'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline, color: cs.error, size: 18),
                  label: Text('Delete', style: TextStyle(color: cs.error)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchivedEmptyState extends StatelessWidget {
  const _ArchivedEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.archive_outlined, size: 64, color: cs.outlineVariant),
            const SizedBox(height: 14),
            Text('No archived subjects', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Archived subjects will appear here for restore or permanent deletion.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
