import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/providers/settings_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Class detection',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _GraceSlider(
            title: 'Minutes before class',
            value: settings.preGraceMinutes,
            onChanged: settings.updatePreGraceMinutes,
            min: 0,
            max: 15,
          ),
          const SizedBox(height: 16),
          _GraceSlider(
            title: 'Minutes after class',
            value: settings.postGraceMinutes,
            onChanged: settings.updatePostGraceMinutes,
            min: 0,
            max: 20,
          ),
          const SizedBox(height: 12),
          Text(
            'These windows expand the schedule time used for class detection.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Text('Photo storage', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Save photos to device gallery'),
            subtitle: Text(
              settings.savePhotosToGallery
                  ? 'ON: Captured photos are kept in app storage and also copied to the gallery.'
                  : 'OFF: Captured photos stay only inside app storage.',
            ),
            value: settings.savePhotosToGallery,
            onChanged: settings.updateSavePhotosToGallery,
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              'Made with care by Amon',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GraceSlider extends StatelessWidget {
  final String title;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _GraceSlider({
    required this.title,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title: $value min'),
        Slider(
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          value: value.toDouble(),
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}
