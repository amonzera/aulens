import 'package:flutter/material.dart';
import '../../notes/pages/add_text_note_page.dart';
import '../../schedule/models/schedule_entry.dart';
import '../../schedule/models/subject.dart';
import '../../camera/pages/camera_page.dart';

/// Full-screen class mode for quick capture during an active session.
class ClassModePage extends StatefulWidget {
  final Subject detectedSubject;
  final ScheduleEntry scheduleEntry;
  final List<Subject> subjects;

  const ClassModePage({
    super.key,
    required this.detectedSubject,
    required this.scheduleEntry,
    required this.subjects,
  });
  @override
  State<ClassModePage> createState() => _ClassModePageState();
}

class _ClassModePageState extends State<ClassModePage> {
  late Subject _selectedSubject;

  @override
  void initState() {
    super.initState();
    _selectedSubject = widget.detectedSubject;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final entry = widget.scheduleEntry;

    return Scaffold(
      appBar: AppBar(title: const Text('Class Mode'), centerTitle: true),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _selectedSubject.name,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_selectedSubject.professor != null &&
                      _selectedSubject.professor!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Prof. ${_selectedSubject.professor}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (_selectedSubject.classroom != null &&
                      _selectedSubject.classroom!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Room ${_selectedSubject.classroom}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${entry.startTime} – ${entry.endTime}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Capture your class notes quickly.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Subject override',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Subject>(
                    key: ValueKey(_selectedSubject.id),
                    initialValue: _selectedSubject,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.school_outlined),
                      labelText: 'Subject',
                    ),
                    items: widget.subjects
                        .map(
                          (s) =>
                              DropdownMenuItem(value: s, child: Text(s.name)),
                        )
                        .toList(),
                    onChanged: (s) {
                      if (s == null) return;
                      setState(() => _selectedSubject = s);
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.camera_alt_outlined, size: 28),
                      label: const Text('Take Photo'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 22),
                        textStyle: theme.textTheme.titleLarge,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CameraPage(
                              autoCapture: true,
                              fixedSubject: _selectedSubject,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.note_add_outlined, size: 28),
                      label: const Text('Quick Note'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        textStyle: theme.textTheme.titleLarge,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AddTextNotePage(subject: _selectedSubject),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Captured notes are saved to this subject and class session.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
