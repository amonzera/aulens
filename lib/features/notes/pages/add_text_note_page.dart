import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/providers/notes_provider.dart';
import '../../schedule/models/subject.dart';

/// Form for adding a manual text note to a subject.
class AddTextNotePage extends StatefulWidget {
  final Subject subject;
  const AddTextNotePage({super.key, required this.subject});

  @override
  State<AddTextNotePage> createState() => _AddTextNotePageState();
}

class _AddTextNotePageState extends State<AddTextNotePage> {
  final _formKey = GlobalKey<FormState>();
  final _textCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await context.read<NotesProvider>().addTextNote(
      subjectId: widget.subject.id!,
      textContent: _textCtrl.text,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('New Note - ${widget.subject.name}')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _textCtrl,
                maxLines: 8,
                minLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Note text',
                  hintText: 'Write your notes here...',
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Note text cannot be empty'
                    : null,
              ),
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
                      : const Text('Save Note'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
