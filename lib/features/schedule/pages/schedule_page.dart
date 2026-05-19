import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../notes/pages/subject_timeline_page.dart';
import '../../../shared/providers/class_mode_controller.dart';
import '../../../shared/providers/notes_provider.dart';
import '../../../shared/providers/schedule_provider.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../settings/pages/settings_page.dart';
import '../models/schedule_entry.dart';
import '../models/subject.dart';
import '../../class_mode/pages/class_mode_page.dart';
import 'archived_subjects_page.dart';
import 'add_subject_page.dart';

/// Main schedule screen – displays subjects and their weekly time slots.
class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.record_voice_over_outlined),
            tooltip: 'Class mode',
            onPressed: () => _openClassModeManual(context),
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Archived subjects',
            onPressed: () => _openArchivedSubjects(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _pushAddSubject(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Subject'),
      ),
      body: Consumer<ScheduleProvider>(
        builder: (context, provider, _) {
          if (provider.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.subjects.isEmpty) {
            return _EmptyState(onAdd: () => _pushAddSubject(context));
          }
          final unscheduledSubjects =
              provider.subjects
                  .where((s) => provider.entriesForSubject(s.id!).isEmpty)
                  .toList()
                ..sort((a, b) => a.name.compareTo(b.name));

          final weekdayItems = {
            for (var day = 1; day <= 7; day++) day: <_ScheduleBlockItem>[],
          };

          final sortedEntries = provider.entries.toList()
            ..sort((a, b) {
              final byDay = a.weekday.compareTo(b.weekday);
              if (byDay != 0) return byDay;
              final byStart = a.startTime.compareTo(b.startTime);
              if (byStart != 0) return byStart;
              final aName = provider.subjectById(a.subjectId)?.name ?? '';
              final bName = provider.subjectById(b.subjectId)?.name ?? '';
              return aName.compareTo(bName);
            });

          for (final entry in sortedEntries) {
            final subject = provider.subjectById(entry.subjectId);
            if (subject == null) continue;
            weekdayItems[entry.weekday]!.add(
              _ScheduleBlockItem(subject: subject, entry: entry),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            children: [
              if (unscheduledSubjects.isNotEmpty) ...[
                const _SectionHeader(title: 'Unscheduled'),
                const SizedBox(height: 8),
                _ScheduleGridSection(
                  items: unscheduledSubjects
                      .map((s) => _ScheduleBlockItem(subject: s))
                      .toList(),
                  onOpenSubject: (subject) =>
                      _openSubjectTimeline(context, subject),
                  onEditSubject: (subject) =>
                      _pushEditSubject(context, subject),
                  onArchiveSubject: (subject) =>
                      _confirmArchiveSubject(context, provider, subject),
                  onDeleteSubject: (subject) =>
                      _confirmDeleteSubject(context, provider, subject),
                ),
                const SizedBox(height: 14),
              ],
              ...List.generate(7, (index) {
                final day = index + 1;
                final items = weekdayItems[day]!;
                if (items.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(title: AppConstants.weekdayNames[index]),
                    const SizedBox(height: 8),
                    _ScheduleGridSection(
                      items: items,
                      onOpenSubject: (subject) =>
                          _openSubjectTimeline(context, subject),
                      onEditSubject: (subject) =>
                          _pushEditSubject(context, subject),
                      onArchiveSubject: (subject) =>
                          _confirmArchiveSubject(context, provider, subject),
                      onDeleteSubject: (subject) =>
                          _confirmDeleteSubject(context, provider, subject),
                    ),
                    const SizedBox(height: 14),
                  ],
                );
              }),
            ],
          );
        },
      ),
    );
  }

  void _pushAddSubject(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AddSubjectPage()),
  );

  void _openSettings(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const SettingsPage()),
  );

  void _openArchivedSubjects(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const ArchivedSubjectsPage()),
  );

  Future<void> _openClassModeManual(BuildContext context) async {
    final scheduleProvider = context.read<ScheduleProvider>();
    final settings = context.read<SettingsProvider>();
    final entry = scheduleProvider.getCurrentClass(
      preGraceMinutes: settings.preGraceMinutes,
      postGraceMinutes: settings.postGraceMinutes,
    );
    if (entry == null) {
      AppSnackBar.showInfo(context, 'No active class right now.');
      return;
    }

    final subject = scheduleProvider.subjectById(entry.subjectId);
    if (subject == null) return;

    final classMode = context.read<ClassModeController>();
    classMode.clearDismissed();
    classMode.setOpen(true);
    final subjects = scheduleProvider.subjects.toList();

    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ClassModePage(
          detectedSubject: subject,
          scheduleEntry: entry,
          subjects: subjects,
        ),
      ),
    );

    classMode.setOpen(false);
    classMode.markDismissed();
  }

  void _pushEditSubject(BuildContext context, Subject subject) =>
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AddSubjectPage(subject: subject)),
      );

  void _openSubjectTimeline(BuildContext context, Subject subject) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SubjectTimelinePage(subject: subject),
        ),
      );

  void _confirmDeleteSubject(
    BuildContext context,
    ScheduleProvider provider,
    Subject subject,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Subject'),
        content: Text(
          'Delete "${subject.name}" and all its schedule entries?\n'
          'Associated notes will also be removed.',
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
              await provider.deleteSubject(subject.id!);
              if (!context.mounted) return;
              context.read<NotesProvider>().removeNotesBySubject(subject.id!);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmArchiveSubject(
    BuildContext context,
    ScheduleProvider provider,
    Subject subject,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Subject'),
        content: Text(
          'Archive "${subject.name}"?\n'
          'Notes, photos and schedule will be preserved and can be restored later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.archiveSubject(subject.id!);
              if (!context.mounted) return;
              AppSnackBar.showInfo(context, 'Subject archived.');
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined, size: 72, color: cs.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'No subjects yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first subject and set up its weekly schedule.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add Subject'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleBlockItem {
  final Subject subject;
  final ScheduleEntry? entry;

  const _ScheduleBlockItem({required this.subject, this.entry});

  bool get isUnscheduled => entry == null;
}

enum _SubjectMenuAction { edit, archive, delete }

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _ScheduleGridSection extends StatelessWidget {
  final List<_ScheduleBlockItem> items;
  final ValueChanged<Subject> onOpenSubject;
  final ValueChanged<Subject> onEditSubject;
  final ValueChanged<Subject> onArchiveSubject;
  final ValueChanged<Subject> onDeleteSubject;

  const _ScheduleGridSection({
    required this.items,
    required this.onOpenSubject,
    required this.onEditSubject,
    required this.onArchiveSubject,
    required this.onDeleteSubject,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.03,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _ScheduleBlockCard(
          item: item,
          onTap: () => onOpenSubject(item.subject),
          onEditSubject: () => onEditSubject(item.subject),
          onArchiveSubject: () => onArchiveSubject(item.subject),
          onDeleteSubject: () => onDeleteSubject(item.subject),
        );
      },
    );
  }
}

class _ScheduleBlockCard extends StatelessWidget {
  final _ScheduleBlockItem item;
  final VoidCallback onTap;
  final VoidCallback onEditSubject;
  final VoidCallback onArchiveSubject;
  final VoidCallback onDeleteSubject;

  const _ScheduleBlockCard({
    required this.item,
    required this.onTap,
    required this.onEditSubject,
    required this.onArchiveSubject,
    required this.onDeleteSubject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final professor = item.subject.professor?.trim();
    final classroom = item.subject.classroom?.trim();
    final hasProfessor = professor != null && professor.isNotEmpty;
    final hasClassroom = classroom != null && classroom.isNotEmpty;
    final entry = item.entry;

    return Material(
      color: item.isUnscheduled
          ? cs.surfaceContainerLow
          : cs.primaryContainer.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.subject.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  PopupMenuButton<_SubjectMenuAction>(
                    tooltip: 'Subject options',
                    onSelected: (action) {
                      switch (action) {
                        case _SubjectMenuAction.edit:
                          onEditSubject();
                          return;
                        case _SubjectMenuAction.archive:
                          onArchiveSubject();
                          return;
                        case _SubjectMenuAction.delete:
                          onDeleteSubject();
                          return;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: _SubjectMenuAction.edit,
                        child: Text('Edit subject'),
                      ),
                      const PopupMenuItem(
                        value: _SubjectMenuAction.archive,
                        child: Text('Archive subject'),
                      ),
                      PopupMenuItem(
                        value: _SubjectMenuAction.delete,
                        child: Text(
                          'Delete subject',
                          style: TextStyle(color: cs.error),
                        ),
                      ),
                    ],
                    icon: const Icon(Icons.more_horiz, size: 18),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (hasProfessor)
                Text(
                  professor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              if (hasClassroom)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    classroom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: cs.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      entry == null
                          ? 'No scheduled time'
                          : '${entry.startTime} – ${entry.endTime}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
