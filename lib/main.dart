import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/camera/pages/camera_page.dart';
import 'features/camera/services/camera_service.dart';
import 'features/class_mode/pages/class_mode_page.dart';
import 'features/notes/pages/notes_page.dart';
import 'features/notes/services/notes_service.dart';
import 'features/schedule/pages/schedule_page.dart';
import 'features/schedule/services/schedule_service.dart';
import 'features/schedule/models/subject.dart';
import 'features/schedule/models/schedule_entry.dart';
import 'features/search/pages/search_page.dart';
import 'l10n/app_localizations.dart';
import 'shared/services/settings_service.dart';
import 'shared/database/database_service.dart';
import 'shared/providers/class_mode_controller.dart';
import 'shared/providers/notes_provider.dart';
import 'shared/providers/schedule_provider.dart';
import 'shared/providers/settings_provider.dart';
import 'shared/widgets/app_snackbar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AulensApp());
}

class AulensApp extends StatelessWidget {
  const AulensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DatabaseService>(create: (_) => DatabaseService()),
        Provider<ScheduleService>(
          create: (context) => ScheduleService(context.read<DatabaseService>()),
        ),
        Provider<NotesService>(
          create: (context) => NotesService(context.read<DatabaseService>()),
        ),
        Provider<SettingsService>(create: (_) => SettingsService()),
        ChangeNotifierProvider(
          create: (context) =>
              ScheduleProvider(context.read<ScheduleService>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              SettingsProvider(context.read<SettingsService>()),
        ),
        ChangeNotifierProvider(
          create: (context) => NotesProvider(context.read<NotesService>()),
        ),
        ChangeNotifierProvider(create: (_) => ClassModeController()),
      ],
      child: MaterialApp(
        title: 'Aulens',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const _MainScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

// ── Main shell with bottom navigation ────────────────────────────────────────

class _MainScreen extends StatefulWidget {
  const _MainScreen();

  @override
  State<_MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<_MainScreen> with WidgetsBindingObserver {
  int _index = 0;
  Timer? _classModeTimer;
  bool _classModeCheckInProgress = false;

  // Kept in an IndexedStack so each tab preserves its scroll / state.
  static const List<Widget> _pages = [
    SchedulePage(),
    NotesPage(),
    CameraPage(),
    SearchPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CameraService.instance.preload();
      _checkClassMode();
      _classModeTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _checkClassMode(),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _classModeTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!mounted) return;

    // Re-enable Class Mode prompt when returning to the app so active sessions
    // can trigger the overlay again.
    context.read<ClassModeController>().clearDismissed();
    _checkClassMode();
  }

  Future<void> _checkClassMode() async {
    if (!mounted) return;
    if (_classModeCheckInProgress) return;
    _classModeCheckInProgress = true;
    final scheduleProvider = context.read<ScheduleProvider>();
    final classMode = context.read<ClassModeController>();
    final settings = context.read<SettingsProvider>();
    final entry = scheduleProvider.getCurrentClass(
      preGraceMinutes: settings.preGraceMinutes,
      postGraceMinutes: settings.postGraceMinutes,
    );

    if (entry == null) {
      if (classMode.isOpen) {
        await Navigator.of(context, rootNavigator: true).maybePop();
      }
      classMode.clearDismissed();
      _classModeCheckInProgress = false;
      return;
    }

    final subject = scheduleProvider.subjectById(entry.subjectId);
    if (subject == null) {
      _classModeCheckInProgress = false;
      return;
    }

    if (!classMode.isOpen && !classMode.dismissed) {
      await _openClassMode(subject, entry, manual: false);
    }
    _classModeCheckInProgress = false;
  }

  Future<void> _openClassMode(
    Subject subject,
    ScheduleEntry entry, {
    required bool manual,
  }) async {
    final classMode = context.read<ClassModeController>();
    if (classMode.isOpen) return;

    if (manual) {
      classMode.clearDismissed();
    }

    classMode.setOpen(true);
    final subjects = context.read<ScheduleProvider>().subjects.toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: _MainBottomBar(
        selectedIndex: _index,
        onSelect: (i) => setState(() => _index = i),
        onQuickNote: _openQuickTextNote,
      ),
    );
  }

  Future<void> _openQuickTextNote() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _QuickNoteBottomSheet(),
    );
  }
}

class _MainBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onQuickNote;

  const _MainBottomBar({
    required this.selectedIndex,
    required this.onSelect,
    required this.onQuickNote,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        height: 88,
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Row(
          children: [
            Expanded(
              child: _BottomBarItem(
                icon: Icons.calendar_month_outlined,
                selectedIcon: Icons.calendar_month,
                label: 'Schedule',
                selected: selectedIndex == 0,
                onTap: () => onSelect(0),
              ),
            ),
            Expanded(
              child: _BottomBarItem(
                icon: Icons.book_outlined,
                selectedIcon: Icons.book,
                label: 'Notes',
                selected: selectedIndex == 1,
                onTap: () => onSelect(1),
              ),
            ),
            Expanded(
              child: _CenterCameraButton(
                selected: selectedIndex == 2,
                onTap: () => onSelect(2),
              ),
            ),
            Expanded(
              child: _BottomBarItem(
                icon: Icons.search_outlined,
                selectedIcon: Icons.search,
                label: 'Search',
                selected: selectedIndex == 3,
                onTap: () => onSelect(3),
              ),
            ),
            Expanded(
              child: _BottomBarItem(
                icon: Icons.note_add_outlined,
                selectedIcon: Icons.note_add,
                label: 'Quick Note',
                selected: false,
                onTap: onQuickNote,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBarItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomBarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = selected ? cs.primary : cs.onSurfaceVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? selectedIcon : icon, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterCameraButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _CenterCameraButton({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: selected ? 56 : 52,
            height: selected ? 56 : 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary,
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: selected ? 0.45 : 0.3),
                  blurRadius: selected ? 18 : 12,
                  spreadRadius: selected ? 1 : 0,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(Icons.camera_alt, color: cs.onPrimary, size: 28),
          ),
          const SizedBox(height: 2),
          Text(
            'Camera',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickNoteBottomSheet extends StatefulWidget {
  const _QuickNoteBottomSheet();

  @override
  State<_QuickNoteBottomSheet> createState() => _QuickNoteBottomSheetState();
}

class _QuickNoteBottomSheetState extends State<_QuickNoteBottomSheet> {
  final _textController = TextEditingController();

  Subject? _selectedSubject;
  Subject? _detectedSubject;
  ScheduleEntry? _detectedEntry;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initDetectedSubject();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _initDetectedSubject() {
    final scheduleProvider = context.read<ScheduleProvider>();
    final settings = context.read<SettingsProvider>();

    final entry = scheduleProvider.getCurrentClass(
      preGraceMinutes: settings.preGraceMinutes,
      postGraceMinutes: settings.postGraceMinutes,
    );

    final now = DateTime.now();
    final detected = entry != null
        ? scheduleProvider.resolveSubjectForEntryOnDate(entry, now)
        : null;

    final fallback = scheduleProvider.subjects.isNotEmpty
        ? scheduleProvider.subjects.first
        : null;

    setState(() {
      _detectedEntry = entry;
      _detectedSubject = detected;
      _selectedSubject = detected ?? fallback;
    });
  }

  Future<void> _save() async {
    if (_saving) return;

    final notesProvider = context.read<NotesProvider>();
    final scheduleProvider = context.read<ScheduleProvider>();

    final text = _textController.text.trim();
    if (text.isEmpty) {
      AppSnackBar.showInfo(context, 'Write a quick note first.');
      return;
    }

    final subject = _selectedSubject;
    final subjectId = subject?.id;
    if (subjectId == null) {
      AppSnackBar.showError(
        context,
        'Create a subject in Schedule before adding notes.',
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await notesProvider.addTextNote(subjectId: subjectId, textContent: text);

      final detectedEntry = _detectedEntry;
      final detectedSubjectId = _detectedSubject?.id;

      if (detectedEntry != null &&
          detectedSubjectId != null &&
          detectedSubjectId != subjectId) {
        final entryId = detectedEntry.id;
        if (entryId != null) {
          await scheduleProvider.setSessionOverride(
            scheduleEntryId: entryId,
            date: DateTime.now(),
            subjectId: subjectId,
          );
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackBar.showError(context, 'Failed to save note. Please try again.');
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subjects = context.watch<ScheduleProvider>().subjects;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Note', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_detectedSubject != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Detected: ${_detectedSubject!.name}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            DropdownButtonFormField<Subject>(
              initialValue: subjects.contains(_selectedSubject)
                  ? _selectedSubject
                  : (subjects.isNotEmpty ? subjects.first : null),
              decoration: const InputDecoration(labelText: 'Subject'),
              items: subjects
                  .map(
                    (subject) => DropdownMenuItem<Subject>(
                      value: subject,
                      child: Text(subject.name),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _selectedSubject = value),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _textController,
              autofocus: true,
              enabled: !_saving,
              maxLines: 5,
              minLines: 3,
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                labelText: 'Note',
                hintText: 'Type and tap Save',
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
