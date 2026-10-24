import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_controller.dart';
import '../data/models.dart';

const paperTints = [
  Color(0xffe8e1d1),
  Color(0xffeed1c4),
  Color(0xffcadbc0),
  Color(0xffd6cce4),
  Color(0xfff5f2eb),
];
const ink = Color(0xff2c2825);
const terracotta = Color(0xffbd684d);
String readableDate(DateTime d) => DateFormat('EEE, d MMM · h:mm a').format(d);

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController app, required super.child})
    : super(notifier: app);
  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

extension AtelierContext on BuildContext {
  AppController get app => AppScope.of(this);
  bool get dark => Theme.of(this).brightness == Brightness.dark;
  Color get muted => Theme.of(this).colorScheme.onSurfaceVariant;
  MotionMode get motion =>
      MediaQuery.disableAnimationsOf(this) ||
          MediaQuery.accessibleNavigationOf(this)
      ? MotionMode.minimal
      : app.prefs.motion;
  Duration duration([int ms = 280]) => Duration(
    milliseconds: switch (motion) {
      MotionMode.full => ms,
      MotionMode.reduced => (ms * .55).round(),
      MotionMode.minimal => 0,
    },
  );
}

ThemeData atelierTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colors = ColorScheme.fromSeed(seedColor: ink, brightness: brightness)
      .copyWith(
        primary: dark ? const Color(0xffe6d9bf) : ink,
        onPrimary: dark ? ink : Colors.white,
        surface: dark ? const Color(0xff1f211f) : const Color(0xfffbf9f5),
        onSurface: dark ? const Color(0xfff4eee2) : ink,
        onSurfaceVariant: dark
            ? const Color(0xffd0c8b8)
            : const Color(0xff625d55),
        surfaceContainer: dark
            ? const Color(0xff2b2d29)
            : const Color(0xffefeeea),
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    brightness: brightness,
    fontFamily: 'Jakarta',
    scaffoldBackgroundColor: colors.surface,
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineLarge: TextStyle(
        fontFamily: 'Newsreader',
        fontSize: 34,
        color: colors.onSurface,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Newsreader',
        fontSize: 28,
        color: colors.onSurface,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Newsreader',
        fontSize: 24,
        color: colors.onSurface,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Jakarta',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: colors.onSurface,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Newsreader',
        fontSize: 26,
        color: colors.onSurface,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        textStyle: const TextStyle(
          fontFamily: 'Jakarta',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colors.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: DividerThemeData(
      color: colors.onSurface.withValues(alpha: .1),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surface,
      indicatorColor: colors.surfaceContainer,
      height: 78,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Jakarta',
          fontSize: 10,
          color: colors.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      side: BorderSide.none,
      shape: const StadiumBorder(),
    ),
  );
}

class DeskLogo extends StatelessWidget {
  final double size;
  const DeskLogo({super.key, this.size = 34});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: ink,
      borderRadius: BorderRadius.circular(size * .25),
    ),
    child: Icon(
      Icons.sticky_note_2_outlined,
      color: const Color(0xfff4e9cf),
      size: size * .7,
    ),
  );
}

PreferredSizeWidget deskAppBar(
  BuildContext context,
  String title, {
  List<Widget>? actions,
  bool home = false,
}) => AppBar(
  title: home
      ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [const DeskLogo(), const SizedBox(width: 9), Text(title)],
        )
      : Text(title),
  centerTitle: !home,
  actions:
      actions ??
      [
        Padding(
          padding: const EdgeInsets.only(right: 18),
          child: Icon(Icons.auto_stories_outlined, color: context.muted),
        ),
      ],
);

class SectionLabel extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionLabel(this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?trailing,
      ],
    ),
  );
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  @override
  Widget build(BuildContext context) => Material(
    color: context.dark ? const Color(0xff2b2d29) : const Color(0xfff1f0ec),
    borderRadius: BorderRadius.circular(28),
    child: Padding(padding: padding, child: child),
  );
}

class Paper extends StatelessWidget {
  final Widget child;
  final int tint;
  final PaperStyle style;
  final bool dots;
  final EdgeInsetsGeometry padding;
  const Paper({
    super.key,
    required this.child,
    this.tint = 0,
    this.style = PaperStyle.pinned,
    this.dots = false,
    this.padding = const EdgeInsets.all(24),
  });
  @override
  Widget build(BuildContext context) {
    final color = context.dark
        ? Color.lerp(
            paperTints[tint % paperTints.length],
            const Color(0xff242821),
            .77,
          )!
        : paperTints[tint % paperTints.length];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: context.dark ? Colors.white12 : ink.withValues(alpha: .08),
            ),
            boxShadow: context.motion == MotionMode.minimal
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: context.motion == MotionMode.reduced
                            ? .06
                            : context.dark
                            ? .15
                            : .16,
                      ),
                      blurRadius: context.motion == MotionMode.full ? 22 : 4,
                      offset: const Offset(0, 10),
                    ),
                  ],
          ),
          child: CustomPaint(
            painter: dots && context.motion != MotionMode.minimal
                ? PaperDots(
                    context.dark ? Colors.white12 : ink.withValues(alpha: .22),
                    spacing: context.motion == MotionMode.reduced ? 24 : 15,
                  )
                : null,
            child: Padding(padding: padding, child: child),
          ),
        ),
        Positioned(
          top: -9,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedSwitcher(
              duration: context.duration(220),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(scale: a, child: child),
              ),
              child: style == PaperStyle.pinned
                  ? Container(
                      key: const ValueKey('pin'),
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xfff1d69d),
                            Color(0xffbd903b),
                            Color(0xff684c23),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black38,
                            offset: Offset(1, 5),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Align(
                        alignment: const Alignment(-.4, -.4),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xfffceccb),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    )
                  : Transform.rotate(
                      angle: -.035,
                      child: Container(
                        key: const ValueKey('tape'),
                        width: 62,
                        height: 19,
                        decoration: BoxDecoration(
                          color: context.dark
                              ? const Color(0xffb6afa0)
                              : const Color(0xfffaf9f3),
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              offset: Offset(1, 3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class PaperDots extends CustomPainter {
  final Color color;
  final double spacing;
  PaperDots(this.color, {this.spacing = 15});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(28)),
    );
    final paint = Paint()..color = color;
    for (double x = 10; x < size.width; x += spacing) {
      for (double y = 10; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), .75, paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PaperDots oldDelegate) =>
      oldDelegate.color != color || oldDelegate.spacing != spacing;
}

class Handwriting extends StatelessWidget {
  final String text;
  final double size;
  final bool clean;
  final int? maxLines;
  const Handwriting(
    this.text, {
    super.key,
    this.size = 28,
    this.clean = false,
    this.maxLines,
  });
  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: maxLines,
    overflow: maxLines == null ? null : TextOverflow.ellipsis,
    style: TextStyle(
      fontFamily: clean || context.app.prefs.cleanPrint ? 'Jakarta' : 'Caveat',
      fontSize:
          (clean || context.app.prefs.cleanPrint ? size * .77 : size) *
          context.app.prefs.textScale,
      fontWeight: clean ? FontWeight.w400 : FontWeight.w600,
      height: 1.24,
    ),
  );
}

class EmptyDesk extends StatelessWidget {
  final String title, body;
  final Widget? action;
  const EmptyDesk(this.title, this.body, {super.key, this.action});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Column(
      children: [
        Icon(Icons.auto_stories_outlined, size: 42, color: context.muted),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.muted),
        ),
        if (action != null) ...[const SizedBox(height: 18), action!],
      ],
    ),
  );
}

class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const Pressable({super.key, required this.child, required this.onTap});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      onTapDown: (_) => setState(() => pressed = true),
      onTapCancel: () => setState(() => pressed = false),
      onTapUp: (_) => setState(() => pressed = false),
      child: AnimatedScale(
        scale: pressed && context.motion != MotionMode.minimal ? .98 : 1,
        duration: context.duration(100),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: widget.onTap,
          child: widget.child,
        ),
      ),
    ),
  );
}

class EntryContent extends StatelessWidget {
  final Entry entry;
  final bool answer, compact;
  const EntryContent(
    this.entry, {
    super.key,
    this.answer = false,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              entry.note
                  ? 'PERSONAL NOTE'
                  : entry.tags.firstOrNull?.toUpperCase() ?? 'FLASHCARD',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1,
                color: context.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (entry.pinned) const Icon(Icons.push_pin, size: 16),
          if (entry.bookmarked)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.bookmark, size: 16),
            ),
        ],
      ),
      const SizedBox(height: 15),
      Handwriting(
        answer ? entry.back : entry.front,
        size: entry.textSize,
        clean: entry.cleanPrint,
        maxLines: compact ? 4 : null,
      ),
      if (entry.imagePath != null && !compact) ...[
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            File(entry.imagePath!),
            height: 160,
            width: double.infinity,
            fit: BoxFit.contain,
            cacheWidth: 800,
            errorBuilder: (_, _, _) => const Text('Attachment unavailable'),
          ),
        ),
      ],
      if (entry.hint.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(
          entry.hint,
          maxLines: compact ? 2 : null,
          overflow: compact ? TextOverflow.ellipsis : null,
          style: TextStyle(
            fontFamily: 'Newsreader',
            fontStyle: FontStyle.italic,
            fontSize: 18,
            color: context.muted,
          ),
        ),
      ],
      if (!entry.note && compact && entry.back.isNotEmpty) ...[
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (context.dark ? Colors.black : Colors.white).withValues(
              alpha: .42,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            '→  ${entry.back}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
      if (entry.tags.isNotEmpty && !compact) ...[
        const SizedBox(height: 16),
        Wrap(
          spacing: 6,
          children: entry.tags
              .map(
                (s) => Chip(
                  label: Text('#$s', style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                ),
              )
              .toList(),
        ),
      ],
    ],
  );
}

Route<T> deskRoute<T>(BuildContext context, Widget page) => PageRouteBuilder<T>(
  transitionDuration: context.duration(320),
  reverseTransitionDuration: context.duration(220),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, a, _, child) => FadeTransition(
    opacity: a,
    child: SlideTransition(
      position: Tween(
        begin: const Offset(0, .035),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
      child: child,
    ),
  ),
);

AnimationStyle sheetMotion(BuildContext context) => AnimationStyle(
  duration: context.duration(280),
  reverseDuration: context.duration(200),
);

void message(BuildContext context, String text, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text), action: action));
}

Future<T?> guarded<T>(BuildContext context, Future<T> Function() fn) async {
  try {
    return await fn();
  } catch (e) {
    if (context.mounted) {
      message(context, 'Could not save. Your changes are still here. $e');
    }
    return null;
  }
}

class CompletionMark extends StatelessWidget {
  const CompletionMark({super.key});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    duration: context.duration(650),
    tween: Tween(begin: .7, end: 1),
    curve: Curves.elasticOut,
    builder: (_, v, child) => Transform.rotate(
      angle: (1 - v) * math.pi * .2,
      child: Transform.scale(scale: v, child: child),
    ),
    child: Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: context.dark ? const Color(0xff3b523a) : const Color(0xffdae7d3),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.done_rounded, size: 42),
    ),
  );
}
