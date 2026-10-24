import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../data/models.dart';
import '../services/sound.dart';
import 'foundation.dart';

class Deletion {
  static final _pending = <String>{};
  static Future<bool> perform(
    BuildContext context,
    Entry entry,
    GlobalKey boundaryKey,
  ) async {
    if (!_pending.add(entry.id)) return false;
    ui.Image? capture;
    try {
      final app = context.app;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Delete this ${entry.note ? 'note' : 'card'}?'),
          content: const Text(
            'Its reminder will be cancelled. You can Undo to restore the item and its study history.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Keep it'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return false;
      final mode = context.motion;
      final effect = app.prefs.deleteEffect;
      final overlay = Overlay.of(context, rootOverlay: true);
      final boundary =
          boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      Rect? rect;
      if (boundary == null) {
        throw StateError(
          'The paper preview is not available. Please try again.',
        );
      }
      if (boundary.debugNeedsPaint) await WidgetsBinding.instance.endOfFrame;
      if (boundary.attached) {
        rect = boundary.localToGlobal(Offset.zero) & boundary.size;
        capture = await boundary.toImage(
          pixelRatio: mode == MotionMode.full ? 1.2 : .8,
        );
      }
      if (capture == null) {
        throw StateError('The paper preview could not be captured.');
      }
      // This is the sole entry point for destruction effects, after SQL commit.
      final bundle = await app.delete(entry.id);
      if (bundle == null) {
        capture.dispose();
        capture = null;
        return false;
      }
      if (rect != null && context.mounted) {
        final image = capture;
        capture = null;
        late OverlayEntry layer;
        layer = OverlayEntry(
          builder: (_) => IgnorePointer(
            child: PaperDestruction(
              image: image,
              rect: rect!,
              mode: mode,
              effect: effect,
              onFinished: () {
                layer.remove();
                layer.dispose();
                image.dispose();
              },
            ),
          ),
        );
        overlay.insert(layer);
        app.sound(
          effect == DeleteEffect.shred ? DeskSound.shred : DeskSound.crumple,
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            content: const Text('Paper cleared. A little more space.'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                unawaited(
                  guarded(context, () async {
                    await app.undo(bundle);
                    if (context.mounted) {
                      message(
                        context,
                        bundle.reminder != null &&
                                !bundle.reminder!.at.isAfter(DateTime.now())
                            ? 'Restored. The expired reminder is disabled.'
                            : 'Restored, including study history.',
                      );
                    }
                  }),
                );
              },
            ),
          ),
        );
      }
      return true;
    } catch (e) {
      capture?.dispose();
      capture = null;
      if (context.mounted) {
        message(context, 'Deletion failed. The item has been kept. $e');
      }
      return false;
    } finally {
      capture?.dispose();
      _pending.remove(entry.id);
    }
  }
}

class PaperDestruction extends StatefulWidget {
  final ui.Image image;
  final Rect rect;
  final MotionMode mode;
  final DeleteEffect effect;
  final VoidCallback onFinished;
  const PaperDestruction({
    super.key,
    required this.image,
    required this.rect,
    required this.mode,
    required this.effect,
    required this.onFinished,
  });
  @override
  State<PaperDestruction> createState() => _PaperDestructionState();
}

class _PaperDestructionState extends State<PaperDestruction>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation =
      AnimationController(
          vsync: this,
          duration: Duration(
            milliseconds: widget.mode == MotionMode.full
                ? 820
                : widget.mode == MotionMode.reduced
                ? 420
                : 100,
          ),
        )
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) widget.onFinished();
        })
        ..forward();
  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (_, _) => CustomPaint(
      size: MediaQuery.sizeOf(context),
      painter: _DestructionPainter(
        widget.image,
        widget.rect,
        animation.value,
        widget.effect,
        widget.mode,
      ),
    ),
  );
}

class _DestructionPainter extends CustomPainter {
  final ui.Image image;
  final Rect rect;
  final double t;
  final DeleteEffect effect;
  final MotionMode mode;
  _DestructionPainter(this.image, this.rect, this.t, this.effect, this.mode);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..filterQuality = FilterQuality.low
      ..color = Colors.white.withValues(alpha: 1 - t * t);
    if (mode == MotionMode.minimal) {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        rect,
        paint,
      );
      return;
    }
    if (effect == DeleteEffect.shred) {
      final strips = mode == MotionMode.full ? 12 : 5;
      for (var i = 0; i < strips; i++) {
        final lag = i % 3 * .06;
        final v = ((t - lag) / (1 - lag)).clamp(0.0, 1.0);
        final w = rect.width / strips;
        final source = Rect.fromLTWH(
          i * image.width / strips,
          0,
          image.width / strips,
          image.height.toDouble(),
        );
        canvas.save();
        canvas.translate(
          rect.left + i * w + w / 2 + (i - strips / 2) * v * 5,
          rect.top + rect.height / 2 + v * v * (size.height - rect.top + 80),
        );
        canvas.rotate((i.isEven ? 1 : -1) * v * .22);
        canvas.drawImageRect(
          image,
          source,
          Rect.fromLTWH(-w / 2, -rect.height / 2, w, rect.height),
          paint,
        );
        canvas.restore();
      }
    } else {
      final scale = (1 - t * .92).clamp(.04, 1.0);
      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy + t * t * 150);
      canvas.rotate(t * .5);
      canvas.scale(scale, scale * (1 - .25 * math.sin(t * math.pi)));
      final folds = mode == MotionMode.full ? 8 : 4;
      for (var i = 0; i < folds; i++) {
        final w = rect.width / folds;
        final shift = math.sin(i * 2.2 + t * 4) * t * 14;
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(
            i * image.width / folds,
            0,
            image.width / folds,
            image.height.toDouble(),
          ),
          Rect.fromLTWH(
            -rect.width / 2 + i * w,
            -rect.height / 2 + shift,
            w + 1,
            rect.height - shift.abs(),
          ),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(
            -rect.width / 2 + i * w,
            -rect.height / 2 + shift,
            w,
            rect.height - shift.abs(),
          ),
          Paint()
            ..color = (i.isEven ? Colors.black : Colors.white).withValues(
              alpha: t * .18,
            ),
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_DestructionPainter old) => old.t != t;
}
