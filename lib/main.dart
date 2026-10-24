import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'data/store.dart';
import 'data/models.dart';
import 'services/notifications.dart';
import 'services/sound.dart';
import 'ui/foundation.dart';
import 'ui/home.dart';

Future<AppController> createApp({
  String? databasePath,
  bool seed = true,
}) async {
  final store = await LocalStore.open(path: databasePath);
  final audio = DeskAudio();
  final app = AppController(store, LocalNotifications(), audio: audio);
  await app.initialize(seed: seed);
  unawaited(audio.initialize());
  return app;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSize = 70;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 32 * 1024 * 1024;
  LicenseRegistry.addLicense(() async* {
    for (final font in ['caveat', 'newsreader', 'plusjakartasans']) {
      yield LicenseEntryWithLineBreaks([
        font,
      ], await rootBundle.loadString('assets/fonts/$font-OFL.txt'));
    }
    yield LicenseEntryWithLineBreaks([
      'Atelier stationery sounds',
    ], await rootBundle.loadString('assets/LICENSES.md'));
  });
  try {
    runApp(AtelierApp(app: await createApp()));
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Atelier could not open its local desk.\nYour files have not been erased.\n$e',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AtelierApp extends StatefulWidget {
  final AppController app;
  const AtelierApp({super.key, required this.app});
  @override
  State<AtelierApp> createState() => _AtelierAppState();
}

class _AtelierAppState extends State<AtelierApp> with WidgetsBindingObserver {
  final nav = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.app.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(widget.app.resume());
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(widget.app.audio?.stop() ?? Future.value());
    }
  }

  @override
  void dispose() {
    widget.app.removeListener(_refresh);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    app: widget.app,
    child: MaterialApp(
      navigatorKey: nav,
      title: 'Atelier',
      debugShowCheckedModeBanner: false,
      theme: atelierTheme(Brightness.light),
      darkTheme: atelierTheme(Brightness.dark),
      themeMode: switch (widget.app.prefs.theme) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      },
      themeAnimationDuration:
          widget.app.prefs.motion.name == 'minimal' ||
              WidgetsBinding
                  .instance
                  .platformDispatcher
                  .accessibilityFeatures
                  .disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 250),
      home: widget.app.prefs.onboarded
          ? const DeskShell()
          : const WelcomeDesk(),
    ),
  );
}

class WelcomeDesk extends StatefulWidget {
  const WelcomeDesk({super.key});
  @override
  State<WelcomeDesk> createState() => _WelcomeDeskState();
}

class _WelcomeDeskState extends State<WelcomeDesk> {
  int step = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const DeskLogo(size: 54),
                const SizedBox(height: 20),
                Text(
                  'Atelier',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 38),
                AnimatedSwitcher(
                  duration: context.duration(350),
                  child: Paper(
                    key: ValueKey(step),
                    style: step == 1 ? PaperStyle.sticky : PaperStyle.pinned,
                    tint: step == 1 ? 1 : 0,
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [
                            'A quieter place to learn.',
                            'Thoughts worth keeping.',
                            'Your desk. Your pace.',
                          ][step],
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 20),
                        Handwriting(
                          [
                            'Turn a small moment of attention into something you remember.',
                            'Flashcards for discovery. Personal notes for everything in between.',
                            'Always offline. No account. Gentle reminders, only when you want them.',
                          ][step],
                          size: 28,
                        ),
                        const SizedBox(height: 25),
                        Text(
                          '0${step + 1} / 03',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 2,
                            color: context.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (i) => AnimatedContainer(
                      duration: context.duration(),
                      margin: const EdgeInsets.all(4),
                      width: i == step ? 22 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == step
                            ? Theme.of(context).colorScheme.primary
                            : context.muted.withValues(alpha: .25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (step < 2) {
                        setState(() => step++);
                      } else {
                        guarded(
                          context,
                          () => context.app.setPreferences({'onboarded': true}),
                        );
                      }
                    },
                    child: Text(step == 2 ? 'Open my desk' : 'A little more'),
                  ),
                ),
                TextButton(
                  onPressed: () => guarded(
                    context,
                    () => context.app.setPreferences({'onboarded': true}),
                  ),
                  child: const Text('Skip introduction'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
