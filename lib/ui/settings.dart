import 'package:flutter/material.dart';

import '../data/models.dart';
import '../services/sound.dart';
import 'foundation.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final prefs = app.prefs;
    return ListView(
      key: const PageStorageKey('settings'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          'Make yourself at home.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'A desk that works the way you do.',
          style: TextStyle(color: context.muted),
        ),
        const SizedBox(height: 24),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Paper & ink'),
              DropdownButtonFormField<String>(
                key: ValueKey(prefs.theme),
                initialValue: prefs.theme,
                decoration: const InputDecoration(labelText: 'Theme'),
                items: const [
                  DropdownMenuItem(
                    value: 'system',
                    child: Text('Follow device'),
                  ),
                  DropdownMenuItem(
                    value: 'light',
                    child: Text('Warm daylight'),
                  ),
                  DropdownMenuItem(value: 'dark', child: Text('Evening desk')),
                ],
                onChanged: (v) =>
                    guarded(context, () => app.setPreferences({'theme': v})),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Clean print by default'),
                subtitle: const Text('Use a clear font on all cards'),
                value: prefs.cleanPrint,
                onChanged: (v) => guarded(
                  context,
                  () => app.setPreferences({'cleanPrint': v}),
                ),
              ),
              const Text('Card text size'),
              PreferenceSlider(
                key: ValueKey('size-${prefs.textScale}'),
                value: prefs.textScale,
                min: .8,
                max: 1.5,
                label: (v) => '${(v * 100).round()}%',
                onCommit: (v) => guarded(
                  context,
                  () => app.setPreferences({'textScale': v}),
                ),
              ),
              Text(
                'System text scaling is also respected.',
                style: TextStyle(fontSize: 11, color: context.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Quiet motion'),
              DropdownButtonFormField<MotionMode>(
                key: ValueKey(prefs.motion),
                initialValue: prefs.motion,
                decoration: const InputDecoration(
                  labelText: 'Performance mode',
                ),
                items: const [
                  DropdownMenuItem(
                    value: MotionMode.full,
                    child: Text('Full motion'),
                  ),
                  DropdownMenuItem(
                    value: MotionMode.reduced,
                    child: Text('Reduced effects'),
                  ),
                  DropdownMenuItem(
                    value: MotionMode.minimal,
                    child: Text('Minimal motion'),
                  ),
                ],
                onChanged: (v) => guarded(
                  context,
                  () => app.setPreferences({'motion': v!.name}),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.motion == MotionMode.minimal &&
                        prefs.motion != MotionMode.minimal
                    ? 'Your device’s reduced-motion preference is active.'
                    : 'Lighter modes use fewer paper pieces and simpler transitions. Nothing moves while idle.',
                style: TextStyle(fontSize: 12, color: context.muted),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<DeleteEffect>(
                key: ValueKey(prefs.deleteEffect),
                initialValue: prefs.deleteEffect,
                decoration: const InputDecoration(labelText: 'Deletion effect'),
                items: const [
                  DropdownMenuItem(
                    value: DeleteEffect.shred,
                    child: Text('Paper Shred'),
                  ),
                  DropdownMenuItem(
                    value: DeleteEffect.crumple,
                    child: Text('Paper Crumple'),
                  ),
                ],
                onChanged: (v) => guarded(
                  context,
                  () => app.setPreferences({'deleteEffect': v!.name}),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Played only after an explicit deletion is saved.',
                style: TextStyle(fontSize: 11, color: context.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Sounds of stationery'),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Stationery sounds'),
                subtitle: const Text('Quiet, locally bundled paper recordings'),
                value: prefs.sound,
                onChanged: (v) =>
                    guarded(context, () => app.setPreferences({'sound': v})),
              ),
              const Text('Effects volume'),
              PreferenceSlider(
                key: ValueKey('volume-${prefs.volume}'),
                value: prefs.volume,
                min: 0,
                max: 1,
                label: (v) => '${(v * 100).round()}%',
                onCommit: (v) =>
                    guarded(context, () => app.setPreferences({'volume': v})),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Writing sounds'),
                subtitle: const Text('Short, gentle pen strokes while typing'),
                value: prefs.writingSound,
                onChanged: prefs.sound
                    ? (v) => guarded(
                        context,
                        () => app.setPreferences({'writingSound': v}),
                      )
                    : null,
              ),
              TextButton.icon(
                onPressed: prefs.sound ? () => app.sound(DeskSound.flip) : null,
                icon: const Icon(Icons.volume_up_outlined),
                label: const Text('Preview paper flip'),
              ),
              if (app.audio?.error != null)
                Text(
                  app.audio!.error!,
                  style: const TextStyle(color: terracotta, fontSize: 11),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Your daily rhythm'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Daily review goal'),
                trailing: DropdownButton<int>(
                  value: prefs.dailyGoal,
                  items: [10, 20, 30, 50, 100]
                      .map(
                        (v) =>
                            DropdownMenuItem(value: v, child: Text('$v cards')),
                      )
                      .toList(),
                  onChanged: (v) => guarded(
                    context,
                    () => app.setPreferences({'dailyGoal': v}),
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Default reminder time'),
                subtitle: Text(
                  prefs.defaultReminderMinutes == null
                      ? 'Ask when a date has no time'
                      : TimeOfDay(
                          hour: prefs.defaultReminderMinutes! ~/ 60,
                          minute: prefs.defaultReminderMinutes! % 60,
                        ).format(context),
                ),
                trailing: const Icon(Icons.schedule),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: (prefs.defaultReminderMinutes ?? 540) ~/ 60,
                      minute: (prefs.defaultReminderMinutes ?? 540) % 60,
                    ),
                  );
                  if (time != null && context.mounted) {
                    await guarded(
                      context,
                      () => app.setPreferences({
                        'defaultReminderMinutes': time.hour * 60 + time.minute,
                      }),
                    );
                  }
                },
              ),
              if (prefs.defaultReminderMinutes != null)
                TextButton(
                  onPressed: () => guarded(
                    context,
                    () => app.setPreferences({'defaultReminderMinutes': null}),
                  ),
                  child: const Text('Always ask for a time'),
                ),
              Text(
                'Task reminders are separate from study scheduling. Atelier does not create automatic study alerts.',
                style: TextStyle(fontSize: 11, color: context.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'ATELIER · A SMALL SPACE FOR BIG IDEAS',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 9, letterSpacing: 1, color: context.muted),
        ),
        TextButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: 'Atelier',
            applicationVersion: '1.0.0',
            applicationLegalese: 'Offline notes & thoughtful study.\nSound and font credits are included below and in assets/LICENSES.md.',
          ),
          child: const Text('Licenses & acknowledgments'),
        ),
      ],
    );
  }
}

class PreferenceSlider extends StatefulWidget {
  final double value, min, max;
  final String Function(double) label;
  final ValueChanged<double> onCommit;
  const PreferenceSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onCommit,
  });
  @override
  State<PreferenceSlider> createState() => _PreferenceSliderState();
}

class _PreferenceSliderState extends State<PreferenceSlider> {
  late double value = widget.value;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Slider(
          value: value.clamp(widget.min, widget.max),
          min: widget.min,
          max: widget.max,
          divisions: 20,
          label: widget.label(value),
          onChanged: (v) => setState(() => value = v),
          onChangeEnd: widget.onCommit,
        ),
      ),
      SizedBox(
        width: 44,
        child: Text(widget.label(value), style: const TextStyle(fontSize: 11)),
      ),
    ],
  );
}
