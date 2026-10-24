import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../data/models.dart';
import '../services/sound.dart';
import 'foundation.dart';

/// Uses RenderEditable's actual caret rectangle. It never writes a selection or
/// composing range. Only short, committed insertion deltas decorate the field.
class WritingField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool clean;
  final double size;
  final ValueChanged<String>? onChanged;
  const WritingField({
    super.key,
    required this.controller,
    required this.label,
    this.clean = false,
    this.size = 26,
    this.onChanged,
  });
  @override
  State<WritingField> createState() => _WritingFieldState();
}

class _WritingFieldState extends State<WritingField> {
  final focus = FocusNode();
  final fieldKey = GlobalKey();
  Timer? timer;
  Offset? nib;
  bool large = false;
  late TextEditingValue previous;
  @override
  void initState() {
    super.initState();
    previous = widget.controller.value;
    widget.controller.addListener(_change);
    focus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (!focus.hasFocus && mounted) setState(() => nib = null);
  }

  RenderEditable? _find(RenderObject object) {
    if (object is RenderEditable) return object;
    RenderEditable? result;
    object.visitChildren((child) {
      result ??= _find(child);
    });
    return result;
  }

  void _change() {
    final current = widget.controller.value;
    final old = previous;
    previous = current;
    if (!mounted) return;
    if (current.text == old.text) {
      if (!current.selection.isCollapsed || !current.composing.isCollapsed) {
        timer?.cancel();
        if (nib != null) setState(() => nib = null);
      }
      return;
    }
    if (!focus.hasFocus) return;
    widget.onChanged?.call(current.text);
    timer?.cancel();
    if (context.motion == MotionMode.minimal ||
        widget.clean ||
        context.app.prefs.cleanPrint ||
        !current.selection.isCollapsed ||
        !current.composing.isCollapsed) {
      setState(() => nib = null);
      return;
    }
    final delta = current.text.length - old.text.length;
    if (delta <= 0) {
      setState(() => nib = null);
      return;
    }
    large = delta > 4 || current.text.contains('\n') && delta > 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !focus.hasFocus) return;
      final object = fieldKey.currentContext?.findRenderObject();
      if (object == null) return;
      final editable = _find(object);
      final box = context.findRenderObject() as RenderBox?;
      if (editable == null || box == null || !current.selection.isValid) return;
      final caret = editable.getLocalRectForCaret(current.selection.extent);
      final offset = box.globalToLocal(editable.localToGlobal(caret.topRight));
      // Reserve a small gap after the caret, hide near edges or selection UI.
      if (offset.dx + 25 >= box.size.width ||
          offset.dy < 28 ||
          offset.dy > box.size.height - 28) {
        return;
      }
      setState(() => nib = offset + const Offset(8, 2));
      if (!large) context.app.sound(DeskSound.writing);
    });
    timer = Timer(Duration(milliseconds: large ? 140 : 260), () {
      if (mounted) setState(() => nib = null);
    });
  }

  @override
  void didUpdateWidget(WritingField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_change);
      previous = widget.controller.value;
      widget.controller.addListener(_change);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    widget.controller.removeListener(_change);
    focus.removeListener(_focusChanged);
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      TextField(
        key: fieldKey,
        controller: widget.controller,
        focusNode: focus,
        minLines: 4,
        maxLines: null,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(
          fontFamily: widget.clean || context.app.prefs.cleanPrint
              ? 'Jakarta'
              : 'Caveat',
          fontSize:
              (widget.clean ? widget.size * .78 : widget.size) *
              context.app.prefs.textScale,
          height: 1.4,
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          alignLabelWithHint: true,
          labelStyle: TextStyle(
            fontFamily: 'Jakarta',
            fontSize: 13,
            color: context.muted,
          ),
          fillColor: Colors.transparent,
          border: InputBorder.none,
        ),
      ),
      if (nib != null)
        Positioned(
          left: nib!.dx,
          top: nib!.dy,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: TweenAnimationBuilder<double>(
                key: ValueKey(widget.controller.text.length),
                duration: const Duration(milliseconds: 140),
                tween: Tween(begin: -.2, end: .1),
                builder: (_, angle, _) => Transform.rotate(
                  angle: large ? 0 : angle,
                  child: Icon(
                    large ? Icons.check_rounded : Icons.edit_outlined,
                    size: large ? 14 : 18,
                    color: context.muted.withValues(alpha: .65),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
