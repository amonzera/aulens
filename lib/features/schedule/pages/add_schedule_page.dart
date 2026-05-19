import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/providers/schedule_provider.dart';
import '../models/schedule_entry.dart';
import '../models/subject.dart';

/// Form for adding a recurring weekly time slot to a [Subject].
class AddSchedulePage extends StatefulWidget {
  final Subject subject;
  const AddSchedulePage({super.key, required this.subject});

  @override
  State<AddSchedulePage> createState() => _AddSchedulePageState();
}

class _AddSchedulePageState extends State<AddSchedulePage> {
  final Set<int> _weekdays = {1}; // 1 = Monday
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);
  bool _saving = false;

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  int _mins(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _start = picked;
        // Auto-advance end time if it would become invalid.
        if (_mins(picked) >= _mins(_end)) {
          _end = TimeOfDay(
            hour: (picked.hour + 2).clamp(0, 23),
            minute: picked.minute,
          );
        }
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    if (_weekdays.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select at least one day.')));
      return;
    }

    if (_mins(_start) >= _mins(_end)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }
    setState(() => _saving = true);
    final entries = _weekdays
        .map(
          (day) => ScheduleEntry(
            subjectId: widget.subject.id!,
            weekday: day,
            startTime: _fmt(_start),
            endTime: _fmt(_end),
          ),
        )
        .toList();

    await context.read<ScheduleProvider>().addScheduleEntries(entries);
    if (mounted) Navigator.pop(context);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Schedule – ${widget.subject.name}')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ── Day picker ────────────────────────────────────────────────────
          Text('Days of the week', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(7, (i) {
              final day = i + 1;
              final selected = _weekdays.contains(day);
              return FilterChip(
                label: Text(AppConstants.weekdayNames[i]),
                selected: selected,
                onSelected: (isSelected) {
                  setState(() {
                    if (isSelected) {
                      _weekdays.add(day);
                    } else {
                      _weekdays.remove(day);
                    }
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 24),

          // ── Time slot ─────────────────────────────────────────────────────
          Text('Time slot', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _TimeCard(
                  label: 'Start',
                  time: _start,
                  onTap: () => _pickTime(isStart: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeCard(
                  label: 'End',
                  time: _end,
                  onTap: () => _pickTime(isStart: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

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
                  : const Text('Save Schedule'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Time card widget ──────────────────────────────────────────────────────────

class _TimeCard extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimeCard({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline),
          borderRadius: BorderRadius.circular(12),
          color: cs.surfaceContainerLow,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              '$h:$m',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
