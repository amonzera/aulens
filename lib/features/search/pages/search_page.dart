import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../shared/providers/notes_provider.dart';
import '../../../shared/providers/schedule_provider.dart';
import '../../notes/models/note.dart';
import '../../notes/pages/note_detail_page.dart';

/// Search tab – live full-text search over OCR-extracted note content
/// with highlighted match snippets.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          // ── Search bar ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SearchBar(
              controller: _ctrl,
              hintText: 'Search in your notes…',
              leading: const Icon(Icons.search),
              trailing: _query.isNotEmpty
                  ? [
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _ctrl.clear();
                          setState(() {
                            _query = '';
                          });
                          context.read<NotesProvider>().searchNotesAsync('');
                        },
                      ),
                    ]
                  : null,
              onChanged: (v) {
                final q = v.trim();
                setState(() => _query = q);
                context.read<NotesProvider>().searchNotesAsync(q);
              },
            ),
          ),
          const SizedBox(height: 8),

          // ── Results ──────────────────────────────────────────────────────
          if (_query.isEmpty)
            const Expanded(child: _SearchHint())
          else
            Expanded(
              child: Consumer<NotesProvider>(
                builder: (context, notesProvider, child) {
                  final results = notesProvider.searchResults;
                  if (results == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (results.isEmpty) {
                    return _NoResults(query: _query);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    itemCount: results.length,
                    itemBuilder: (context, i) =>
                        _ResultCard(note: results[i], query: _query),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Hint / empty states ───────────────────────────────────────────────────────

class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.manage_search_outlined,
            size: 64,
            color: cs.outlineVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'Type to search your notes',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 56, color: cs.outlineVariant),
          const SizedBox(height: 12),
          Text(
            'No results for "$query"',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ── Result card ───────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final Note note;
  final String query;
  const _ResultCard({required this.note, required this.query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final subject = note.subjectId != null
        ? context.watch<ScheduleProvider>().subjectById(note.subjectId!)
        : null;
    final dateStr = DateFormat('MMM d, yyyy').format(note.createdAt);
    final textSource = _bestSearchText(note, query);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NoteDetailPage(note: note)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              if (note.hasImage) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(note.imagePath!),
                    width: 64,
                    height: 64,
                    cacheWidth: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 64,
                      height: 64,
                      color: cs.surfaceContainerHighest,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: cs.outlineVariant,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.note_alt_outlined,
                    color: cs.outlineVariant,
                  ),
                ),
              ],
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (subject != null) ...[
                          Icon(
                            Icons.school_outlined,
                            size: 13,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              subject.name,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: cs.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else
                          const Spacer(),
                        Text(
                          dateStr,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (textSource != null && textSource.isNotEmpty)
                      _HighlightedText(text: textSource, query: query)
                    else
                      Text(
                        'No text available.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _bestSearchText(Note note, String query) {
  final queryLower = query.toLowerCase();
  final candidates = [
    note.textContent,
    note.ocrText,
  ].whereType<String>().where((text) => text.trim().isNotEmpty).toList();

  for (final text in candidates) {
    if (text.toLowerCase().contains(queryLower)) {
      return text;
    }
  }

  return candidates.isEmpty ? null : candidates.first;
}

// ── Highlighted text widget ───────────────────────────────────────────────────

/// Renders [text] with every occurrence of [query] highlighted using the
/// primary-container colour so matches stand out in the results list.
class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  const _HighlightedText({required this.text, required this.query});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lower = text.toLowerCase();
    final queryLower = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final idx = lower.indexOf(queryLower, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(
        TextSpan(
          text: text.substring(idx, idx + query.length),
          style: TextStyle(
            backgroundColor: cs.primaryContainer,
            color: cs.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      start = idx + query.length;
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
