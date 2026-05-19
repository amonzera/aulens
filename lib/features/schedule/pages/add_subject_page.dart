import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/providers/schedule_provider.dart';
import '../models/schedule_entry.dart';
import '../models/subject.dart';
import 'add_schedule_page.dart';

/// Simple form for creating a new [Subject].
class AddSubjectPage extends StatefulWidget {
  final Subject? subject;
  const AddSubjectPage({super.key, this.subject});

  @override
  State<AddSubjectPage> createState() => _AddSubjectPageState();
}

class _AddSubjectPageState extends State<AddSubjectPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _professorCtrl;
  late final TextEditingController _classroomCtrl;
  bool _saving = false;

  bool get _isEdit => widget.subject != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.subject?.name ?? '');
    _professorCtrl = TextEditingController(
      text: widget.subject?.professor ?? '',
    );
    _classroomCtrl = TextEditingController(
      text: widget.subject?.classroom ?? '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _professorCtrl.dispose();
    _classroomCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final provider = context.read<ScheduleProvider>();
    if (_isEdit) {
      await provider.updateSubject(
        id: widget.subject!.id!,
        name: _nameCtrl.text,
        professor: _professorCtrl.text,
        classroom: _classroomCtrl.text,
      );
    } else {
      await provider.addSubjectWithOptionalSchedule(
        name: _nameCtrl.text,
        professor: _professorCtrl.text,
        classroom: _classroomCtrl.text,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _saveAndOpenSchedule() async {
    if (_isEdit || _saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final provider = context.read<ScheduleProvider>();
    final existingIds = provider.subjects
        .map((subject) => subject.id)
        .whereType<int>()
        .toSet();

    await provider.addSubjectWithOptionalSchedule(
      name: _nameCtrl.text,
      professor: _professorCtrl.text,
      classroom: _classroomCtrl.text,
    );

    Subject? createdSubject;
    for (final subject in provider.subjects.reversed) {
      final id = subject.id;
      if (id != null && !existingIds.contains(id)) {
        createdSubject = subject;
        break;
      }
    }

    setState(() => _saving = false);
    if (!mounted || createdSubject == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddSchedulePage(subject: createdSubject!),
      ),
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AddSubjectPage(subject: createdSubject),
      ),
    );
  }

  Future<void> _openAddSchedule(Subject subject) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddSchedulePage(subject: subject)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final editingSubject = widget.subject;
    final List<ScheduleEntry> subjectEntries =
        editingSubject == null
              ? <ScheduleEntry>[]
              : provider.entriesForSubject(editingSubject.id!).toList()
          ..sort((a, b) {
            final byDay = a.weekday.compareTo(b.weekday);
            if (byDay != 0) return byDay;
            return a.startTime.compareTo(b.startTime);
          });

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Subject' : 'New Subject')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Subject name',
                  hintText: 'e.g., Mathematics',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Name cannot be empty'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _professorCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Professor (optional)',
                  hintText: 'e.g., Dr. Almeida',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _classroomCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Classroom (optional)',
                  hintText: 'e.g., IC-402',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _saveAndOpenSchedule,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Schedule'),
                  ),
                ),
              ],
              if (_isEdit && editingSubject != null) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Schedule',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _openAddSchedule(editingSubject),
                      icon: const Icon(Icons.add),
                      label: const Text('Add schedule'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (subjectEntries.isEmpty)
                  Text(
                    'No schedule added.',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  ...subjectEntries.map(
                    (entry) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.schedule_outlined),
                        title: Text(
                          '${AppConstants.weekdayNames[entry.weekday - 1]} · ${entry.startTime} – ${entry.endTime}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Delete schedule',
                          onPressed: _saving
                              ? null
                              : () => provider.deleteScheduleEntry(entry.id!),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEdit ? 'Save Changes' : 'Save Subject'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
