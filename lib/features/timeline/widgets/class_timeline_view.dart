import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../notes/models/note.dart';
import '../models/class_session.dart';

/// Session-first notes layout:
/// Class session -> time-based note groups (photos and text).
class ClassTimelineView extends StatelessWidget {
  final List<ClassSession> sessions;
  final ValueChanged<Note>? onNoteTap;
  final bool autoExpandMostRecent;

  const ClassTimelineView({
    super.key,
    required this.sessions,
    this.onNoteTap,
    this.autoExpandMostRecent = true,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const _EmptyClassNotes();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sessions.length,
      itemBuilder: (context, i) => _SessionCard(
        session: sessions[i],
        onNoteTap: onNoteTap,
        initiallyExpanded: autoExpandMostRecent && i == 0,
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final ClassSession session;
  final ValueChanged<Note>? onNoteTap;
  final bool initiallyExpanded;

  const _SessionCard({
    required this.session,
    required this.onNoteTap,
    required this.initiallyExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dateLabel = DateFormat('EEE, MMM d, yyyy').format(session.date);
    final timeLabel = session.isUnscheduled
        ? 'Unscheduled'
        : '${session.startTime} – ${session.endTime}';

    final sortedNotes = [...session.notes]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final groupedNotes = _collectGroupedNotes(sortedNotes);
    final photoNotesCount = sortedNotes.where((n) => n.hasImage).length;
    final textNotesCount = sortedNotes.where((n) => n.isTextNote).length;
    final totalNotesCount = sortedNotes.length;
    final summaryLabel =
        '$totalNotesCount note${totalNotesCount == 1 ? '' : 's'}';
    final failedProcessing = session.processingNotes
        .where((p) => p.failed)
        .toList(growable: false);

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>(
            'session-${session.date.toIso8601String()}-${session.startTime ?? 'unscheduled'}-${session.endTime ?? ''}',
          ),
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Icon(Icons.event_note, size: 16, color: cs.primary),
          title: Text(
            dateLabel,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            '$timeLabel  •  $summaryLabel',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          children: [
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _CountChip(
                  icon: Icons.photo_library_outlined,
                  label:
                      '$photoNotesCount photo${photoNotesCount == 1 ? '' : 's'}',
                ),
                _CountChip(
                  icon: Icons.notes_outlined,
                  label:
                      '$textNotesCount text note${textNotesCount == 1 ? '' : 's'}',
                ),
                _CountChip(
                  icon: Icons.view_timeline_outlined,
                  label:
                      '${groupedNotes.length} group${groupedNotes.length == 1 ? '' : 's'}',
                ),
              ],
            ),
            if (groupedNotes.isNotEmpty) ...[
              const SizedBox(height: 14),
              _SectionTitle(title: 'Grouped Notes'),
              const SizedBox(height: 8),
              ...groupedNotes.map(
                (group) =>
                    _GroupedNotesCard(group: group, onNoteTap: onNoteTap),
              ),
            ],
            if (groupedNotes.isEmpty && failedProcessing.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'No notes in this session.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            if (failedProcessing.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Some OCR jobs failed. You can retake these photos from Camera.',
                style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

List<_NoteGroup> _collectGroupedNotes(List<Note> notes) {
  const groupWindow = Duration(minutes: 2);
  final groups = <_NoteGroup>[];
  if (notes.isEmpty) return groups;

  int i = 0;

  while (i < notes.length) {
    final current = notes[i];
    final grouped = <Note>[current];
    var last = current;
    var j = i + 1;

    while (j < notes.length) {
      final candidate = notes[j];
      if (candidate.createdAt.difference(last.createdAt) <= groupWindow) {
        grouped.add(candidate);
        last = candidate;
        j += 1;
      } else {
        break;
      }
    }

    groups.add(_NoteGroup(timestamp: grouped.first.createdAt, notes: grouped));

    i = j;
  }

  return groups;
}

class _NoteGroup {
  final DateTime timestamp;
  final List<Note> notes;

  const _NoteGroup({required this.timestamp, required this.notes});

  int get photoCount => notes.where((n) => n.hasImage).length;
  int get textCount => notes.where((n) => n.isTextNote).length;

  String? get coverImagePath {
    for (final note in notes) {
      final path = note.imagePath;
      if (path != null && path.trim().isNotEmpty) return path;
    }
    return null;
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _CountChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CountChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _GroupedNotesCard extends StatelessWidget {
  final _NoteGroup group;
  final ValueChanged<Note>? onNoteTap;

  const _GroupedNotesCard({required this.group, required this.onNoteTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = DateFormat('HH:mm').format(group.timestamp);
    final count = group.notes.length;
    final photoCount = group.photoCount;
    final textCount = group.textCount;
    final cover = group.coverImagePath;

    final countParts = <String>[];
    if (photoCount > 0) {
      countParts.add('$photoCount photo${photoCount == 1 ? '' : 's'}');
    }
    if (textCount > 0) {
      countParts.add('$textCount text${textCount == 1 ? '' : 's'}');
    }
    final summary = countParts.isEmpty
        ? '$count item${count == 1 ? '' : 's'}'
        : countParts.join(' • ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showGroupSheet(context),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              if (cover != null && cover.trim().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(cover),
                    width: 64,
                    height: 64,
                    cacheWidth: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _FallbackThumb(icon: Icons.broken_image_outlined),
                  ),
                )
              else
                const _FallbackThumb(icon: Icons.photo_library_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$label  •  $summary',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Icon(Icons.chevron_right, color: cs.outline),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showGroupSheet(BuildContext context) async {
    final ordered = [...group.notes]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: ordered.length,
          itemBuilder: (context, index) {
            final note = ordered[index];
            final time = DateFormat('HH:mm').format(note.createdAt);
            return ListTile(
              leading: Icon(
                note.hasImage ? Icons.photo_outlined : Icons.note_alt_outlined,
              ),
              title: Text(note.hasImage ? 'Photo $time' : 'Text note $time'),
              subtitle: note.isTextNote
                  ? Text(
                      _snippetText(note.textContent) ?? 'No text available.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              onTap: () {
                Navigator.pop(context);
                if (onNoteTap != null) onNoteTap!(note);
              },
            );
          },
        ),
      ),
    );
  }
}

class _FallbackThumb extends StatelessWidget {
  final IconData icon;

  const _FallbackThumb({required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: cs.outlineVariant),
    );
  }
}

String? _snippetText(String? text) {
  if (text == null) return null;
  final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.isEmpty) return null;
  if (compact.length <= 120) return compact;
  return '${compact.substring(0, 120)}...';
}

class _EmptyClassNotes extends StatelessWidget {
  const _EmptyClassNotes();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(Icons.menu_book_outlined, color: cs.outline, size: 22),
            const SizedBox(height: 10),
            Text(
              'No sessions yet. Tap the camera or add a text note to start.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
