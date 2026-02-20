import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';

import 'core.dart';

/* ----------------------------- 1) SplitText ----------------------------- */

/// Direction from which segments enter during a [SplitText] animation.
enum SplitDirection { up, down, left, right }

/// Reveals text by splitting it into segments that slide and fade in.
///
/// Text is segmented according to [animateBy] and each segment enters from
/// [direction] with a staggered delay controlled by [delayFraction].
///
/// ```dart
/// SplitText(
///   text: 'Hello',
///   animateBy: AnimateBy.words,
///   direction: SplitDirection.up,
/// )
/// ```
class SplitText extends StatefulWidget {
  const SplitText({
    super.key,
    required this.text,
    this.style,
    this.animateBy = AnimateBy.words,
    this.trigger = MotionTrigger.onVisible,
    this.duration = const Duration(milliseconds: 900),
    this.delayFraction = 0.35,
    this.direction = SplitDirection.up,
    this.curve = Curves.easeOutCubic,
    this.textAlign,
    this.enabled = true,
  });

  /// The string to animate.
  final String text;

  /// Text style. Falls back to [DefaultTextStyle] when `null`.
  final TextStyle? style;

  /// How to split [text] into animated segments.
  final AnimateBy animateBy;

  /// When to start the animation.
  final MotionTrigger trigger;

  /// Total duration of the animation (including all stagger offsets).
  final Duration duration;

  /// Stagger spread as a fraction of [duration] (0 = simultaneous, 1 = full spread).
  final double delayFraction;

  /// Direction from which each segment enters.
  final SplitDirection direction;

  /// Easing applied to each segment’s local 0 → 1 progress.
  final Curve curve;

  /// Alignment of the reassembled [RichText].
  final TextAlign? textAlign;

  /// Set to `false` to skip animation and immediately show the full text.
  final bool enabled;

  @override
  State<SplitText> createState() => _SplitTextState();
}

class _SplitTextState extends State<SplitText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _start() {
    if (_started) return;
    _started = true;
    _c.forward(from: 0);
  }

  Offset _fromOffset() {
    const d = 18.0;
    return switch (widget.direction) {
      SplitDirection.up => const Offset(0, d),
      SplitDirection.down => const Offset(0, -d),
      SplitDirection.left => const Offset(d, 0),
      SplitDirection.right => const Offset(-d, 0),
    };
  }

  @override
  Widget build(BuildContext context) {
    final reduced = ReducedMotion.of(context) || !widget.enabled;
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    final parts = SegmentedText.split(widget.text, widget.animateBy);
    final from = _fromOffset();

    Widget body = reduced
        ? Text(widget.text, style: style, textAlign: widget.textAlign)
        : AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final p = widget.curve.transform(_c.value);
              final spans = <InlineSpan>[];

              for (int i = 0; i < parts.length; i++) {
                final t = Stagger.interval01(
                  index: i,
                  count: parts.length,
                  delayFraction: widget.delayFraction,
                  progress01: p,
                );
                final dx = from.dy == 0 ? from.dx * (1 - t) : 0.0;
                final dy = from.dx == 0 ? from.dy * (1 - t) : 0.0;

                spans.add(
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(dx, dy),
                        child: Text(parts[i], style: style),
                      ),
                    ),
                  ),
                );
              }

              return RichText(
                textAlign: widget.textAlign ?? TextAlign.start,
                textScaler: MediaQuery.textScalerOf(context),
                text: TextSpan(style: style, children: spans),
              );
            },
          );

    return MotionTriggerWrapper(
      trigger: widget.trigger,
      enabled: !reduced,
      onStart: _start,
      child: body,
    );
  }
}

/* ----------------------------- 2) BlurText ------------------------------ */

/// Direction from which a [BlurText] segment enters.
enum BlurDirection { top, bottom, left, right, none }

/// Reveals text with a per-segment blur-and-slide-in effect.
///
/// Each word (or grapheme / line, depending on [animateBy]) fades in from
/// behind a Gaussian blur, optionally translated from [direction].
///
/// ```dart
/// BlurText(text: 'Hello', maxSigma: 10, direction: BlurDirection.top)
/// ```
class BlurText extends StatefulWidget {
  const BlurText({
    super.key,
    required this.text,
    this.style,
    this.animateBy = AnimateBy.words,
    this.trigger = MotionTrigger.onVisible,
    this.duration = const Duration(milliseconds: 900),
    this.delayFraction = 0.35,
    this.maxSigma = 10,
    this.direction = BlurDirection.top,
    this.curve = Curves.easeOutCubic,
    this.textAlign,
    this.enabled = true,
  });

  /// The string to animate.
  final String text;

  /// Text style. Falls back to [DefaultTextStyle] when `null`.
  final TextStyle? style;

  /// How to split [text] into animated segments.
  final AnimateBy animateBy;

  /// When to start the animation.
  final MotionTrigger trigger;

  /// Total animation duration.
  final Duration duration;

  /// Stagger spread fraction (0 = simultaneous).
  final double delayFraction;

  /// Peak Gaussian blur radius in logical pixels at the start of each segment’s
  /// animation. Animates down to `0`.
  final double maxSigma;

  /// Slide direction for the entering segments (`none` = blur-only, no slide).
  final BlurDirection direction;

  /// Easing curve for each segment.
  final Curve curve;

  /// Text alignment of the assembled [RichText].
  final TextAlign? textAlign;

  /// Set to `false` to skip animation.
  final bool enabled;

  @override
  State<BlurText> createState() => _BlurTextState();
}

class _BlurTextState extends State<BlurText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _start() {
    if (_started) return;
    _started = true;
    _c.forward(from: 0);
  }

  Offset _slideFrom() {
    const d = 10.0;
    return switch (widget.direction) {
      BlurDirection.top => const Offset(0, d),
      BlurDirection.bottom => const Offset(0, -d),
      BlurDirection.left => const Offset(d, 0),
      BlurDirection.right => const Offset(-d, 0),
      BlurDirection.none => Offset.zero,
    };
  }

  @override
  Widget build(BuildContext context) {
    final reduced = ReducedMotion.of(context) || !widget.enabled;
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    final parts = SegmentedText.split(widget.text, widget.animateBy);
    final from = _slideFrom();

    Widget body = reduced
        ? Text(widget.text, style: style, textAlign: widget.textAlign)
        : AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final p = widget.curve.transform(_c.value);
              final spans = <InlineSpan>[];

              for (int i = 0; i < parts.length; i++) {
                final t = Stagger.interval01(
                  index: i,
                  count: parts.length,
                  delayFraction: widget.delayFraction,
                  progress01: p,
                );
                final sigma = widget.maxSigma * (1 - t);
                final offset = Offset(from.dx * (1 - t), from.dy * (1 - t));

                spans.add(
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: offset,
                        child: ImageFiltered(
                          imageFilter:
                              ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                          child: Text(parts[i], style: style),
                        ),
                      ),
                    ),
                  ),
                );
              }

              return RichText(
                textAlign: widget.textAlign ?? TextAlign.start,
                textScaler: MediaQuery.textScalerOf(context),
                text: TextSpan(style: style, children: spans),
              );
            },
          );

    return MotionTriggerWrapper(
      trigger: widget.trigger,
      enabled: !reduced,
      onStart: _start,
      child: body,
    );
  }
}

/* ----------------------------- 3) CircularText -------------------------- */

/// Arranges characters along a continuously rotating circle.
///
/// All characters are evenly spaced on an arc whose radius auto-fits to the
/// widget unless [radius] is provided.
///
/// ```dart
/// CircularText(text: 'FLUTTER • ', clockwise: true)
/// ```
class CircularText extends StatefulWidget {
  const CircularText({
    super.key,
    required this.text,
    this.style,
    this.radius,
    this.trigger = MotionTrigger.onBuild,
    this.rotationPeriod = const Duration(seconds: 8),
    this.clockwise = true,
    this.enabled = true,
  });

  /// The string whose characters are placed around the circle.
  final String text;

  /// Text style; defaults to [DefaultTextStyle].
  final TextStyle? style;

  /// Circle radius in logical pixels. Auto-fits to the widget when `null`.
  final double? radius;

  /// When to start rotating.
  final MotionTrigger trigger;

  /// Time to complete one full revolution.
  final Duration rotationPeriod;

  /// `true` → clockwise rotation; `false` → counter-clockwise.
  final bool clockwise;

  /// Set to `false` to show static text without rotation.
  final bool enabled;

  @override
  State<CircularText> createState() => _CircularTextState();
}

class _CircularTextState extends State<CircularText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.rotationPeriod);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _start() {
    if (_started) return;
    _started = true;
    _c.repeat();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = ReducedMotion.of(context) || !widget.enabled;
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    final chars = SegmentedText.split(widget.text, AnimateBy.graphemes);

    final dir = widget.clockwise ? 1.0 : -1.0;

    Widget body = LayoutBuilder(
      builder: (context, c) {
        final r = widget.radius ?? (math.min(c.maxWidth, c.maxHeight) * 0.35);
        if (reduced) {
          return Center(
              child:
                  Text(widget.text, style: style, textAlign: TextAlign.center));
        }

        return AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final base = dir * _c.value * math.pi * 2;
            return SizedBox.expand(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (int i = 0; i < chars.length; i++)
                    Transform.rotate(
                      angle: base + (i / chars.length) * math.pi * 2,
                      child: Transform.translate(
                        offset: Offset(0, -r),
                        child: Transform.rotate(
                          angle: math.pi / 2,
                          child: Text(chars[i], style: style),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );

    return MotionTriggerWrapper(
      trigger: widget.trigger,
      enabled: !reduced,
      onStart: _start,
      child: body,
    );
  }
}

/* ----------------------------- 4) TextType ------------------------------ */

/// Simulates a typewriter progressively revealing characters with a blinking
/// cursor.
///
/// ```dart
/// TextType(text: 'Hello, World!', showCursor: true, cursor: '▍')
/// ```
class TextType extends StatefulWidget {
  const TextType({
    super.key,
    required this.text,
    this.style,
    this.trigger = MotionTrigger.onVisible,
    this.duration = const Duration(milliseconds: 1400),
    this.curve = Curves.linear,
    this.showCursor = true,
    this.cursor = '▍',
    this.cursorBlink = const Duration(milliseconds: 520),
    this.textAlign,
    this.enabled = true,
  });

  /// The string to type out.
  final String text;

  /// Text style; defaults to [DefaultTextStyle].
  final TextStyle? style;

  /// When to start typing.
  final MotionTrigger trigger;

  /// Time to fully reveal all characters.
  final Duration duration;

  /// Easing of the reveal progress. Use [Curves.linear] for even typing.
  final Curve curve;

  /// Whether to show a blinking cursor after the last typed character.
  final bool showCursor;

  /// Glyph used as the cursor. Defaults to `'▍'` (block cursor).
  final String cursor;

  /// Period of one cursor blink cycle.
  final Duration cursorBlink;

  /// Text alignment of the [RichText] output.
  final TextAlign? textAlign;

  /// Set to `false` to show the complete text immediately.
  final bool enabled;

  @override
  State<TextType> createState() => _TextTypeState();
}

class _TextTypeState extends State<TextType> with TickerProviderStateMixin {
  late final AnimationController _c;
  late final AnimationController _blink;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    _blink = AnimationController(vsync: this, duration: widget.cursorBlink)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    _blink.dispose();
    super.dispose();
  }

  void _start() {
    if (_started) return;
    _started = true;
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = ReducedMotion.of(context) || !widget.enabled;
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    final graphemes = SegmentedText.split(widget.text, AnimateBy.graphemes);

    final body = reduced
        ? Text(widget.text, style: style, textAlign: widget.textAlign)
        : AnimatedBuilder(
            animation: Listenable.merge([_c, _blink]),
            builder: (_, __) {
              final p = widget.curve.transform(_c.value);
              final count =
                  (p * graphemes.length).floor().clamp(0, graphemes.length);
              final shown = graphemes.take(count).join();

              return RichText(
                textAlign: widget.textAlign ?? TextAlign.start,
                textScaler: MediaQuery.textScalerOf(context),
                text: TextSpan(
                  style: style,
                  children: [
                    TextSpan(text: shown),
                    if (widget.showCursor)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: Opacity(
                            opacity: _blink.value,
                            child: Text(widget.cursor, style: style)),
                      ),
                  ],
                ),
              );
            },
          );

    return MotionTriggerWrapper(
      trigger: widget.trigger,
      enabled: !reduced,
      onStart: _start,
      child: body,
    );
  }
}

/* ----------------------------- 5) ShuffleText --------------------------- */

/// Reveals text by locking in characters left-to-right from random noise.
///
/// At each frame, un-revealed characters are replaced with random glyphs from
/// [charset], while already-revealed characters are displayed as-is.
///
/// ```dart
/// ShuffleText(text: 'DECODE ME', charset: 'ABCDEFGHIJK0123456789')
/// ```
class ShuffleText extends StatefulWidget {
  const ShuffleText({
    super.key,
    required this.text,
    this.style,
    this.trigger = MotionTrigger.onVisible,
    this.duration = const Duration(milliseconds: 1100),
    this.charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
    this.textAlign,
    this.enabled = true,
  });

  /// The string to reveal.
  final String text;

  /// Text style; defaults to [DefaultTextStyle].
  final TextStyle? style;

  /// When to start.
  final MotionTrigger trigger;

  /// Time to fully reveal all characters.
  final Duration duration;

  /// Pool of characters used for random substitution before reveal.
  final String charset;

  /// Text alignment.
  final TextAlign? textAlign;

  /// Set to `false` to show the final text immediately.
  final bool enabled;

  @override
  State<ShuffleText> createState() => _ShuffleTextState();
}

class _ShuffleTextState extends State<ShuffleText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final _rnd = math.Random();
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _start() {
    if (_started) return;
    _started = true;
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = ReducedMotion.of(context) || !widget.enabled;
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    final target = SegmentedText.split(widget.text, AnimateBy.graphemes);

    final body = reduced
        ? Text(widget.text, style: style, textAlign: widget.textAlign)
        : AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final lockCount =
                  (_c.value * target.length).floor().clamp(0, target.length);
              final buf = StringBuffer();
              for (int i = 0; i < target.length; i++) {
                if (i < lockCount) {
                  buf.write(target[i]);
                } else {
                  final t = target[i];
                  if (t.trim().isEmpty) {
                    buf.write(t);
                  } else {
                    buf.write(
                        widget.charset[_rnd.nextInt(widget.charset.length)]);
                  }
                }
              }
              return Text(buf.toString(),
                  style: style, textAlign: widget.textAlign);
            },
          );

    return MotionTriggerWrapper(
      trigger: widget.trigger,
      enabled: !reduced,
      onStart: _start,
      child: body,
    );
  }
}

/* ----------------------------- 6) ShinyText ----------------------------- */

/// Animates a sweeping shine highlight across statically-coloured text.
///
/// The text colour is set by [baseColor]; a bright [shineColor] band sweeps
/// left-to-right continuously via a `LinearGradient` shader.
///
/// ```dart
/// ShinyText(text: 'Premium', baseColor: Color(0xFFCBD5E1), shineColor: Colors.white)
/// ```
class ShinyText extends StatefulWidget {
  const ShinyText({
    super.key,
    required this.text,
    this.style,
    this.baseColor = const Color(0xFFCBD5E1),
    this.shineColor = const Color(0xFFFFFFFF),
    this.trigger = MotionTrigger.onBuild,
    this.duration = const Duration(milliseconds: 1800),
    this.enabled = true,
    this.textAlign,
  });

  /// The string to render.
  final String text;

  /// Base text style (colour is overridden by [baseColor] / [shineColor]).
  final TextStyle? style;

  /// Resting colour of the text.
  final Color baseColor;

  /// Colour of the moving shine highlight.
  final Color shineColor;

  /// When to start looping the shine.
  final MotionTrigger trigger;

  /// Duration of one full shine cycle.
  final Duration duration;

  /// Set to `false` to render in [baseColor] without animation.
  final bool enabled;

  /// Text alignment.
  final TextAlign? textAlign;

  @override
  State<ShinyText> createState() => _ShinyTextState();
}

class _ShinyTextState extends State<ShinyText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _start() {
    if (_started) return;
    _started = true;
    _c.repeat();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = ReducedMotion.of(context) || !widget.enabled;
    final base = (widget.style ?? DefaultTextStyle.of(context).style)
        .copyWith(color: widget.baseColor);

    final body = reduced
        ? Text(widget.text, style: base, textAlign: widget.textAlign)
        : AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final t = _c.value;
              final center = -1.2 + 2.4 * t;

              final shader = LinearGradient(
                colors: [
                  widget.baseColor,
                  widget.baseColor,
                  widget.shineColor,
                  widget.baseColor,
                  widget.baseColor
                ],
                stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                begin: Alignment(center - 1.0, 0),
                end: Alignment(center + 1.0, 0),
                transform: GradientRotation(-math.pi / 10),
              ).createShader(const Rect.fromLTWH(0, 0, 900, 220));

              return Text(
                widget.text,
                textAlign: widget.textAlign,
                style: base.copyWith(foreground: Paint()..shader = shader),
              );
            },
          );

    return MotionTriggerWrapper(
      trigger: widget.trigger,
      enabled: !reduced,
      onStart: _start,
      child: body,
    );
  }
}

/* ----------------------------- 7) TextPressure -------------------------- */
/* ----------------------------- 22) VariableProximityText ---------------- */

/// Individually scales and adjusts the opacity of each glyph based on its
/// distance from the pointer.
///
/// Each grapheme cluster is measured and positioned absolutely so it can
/// respond independently to [PointerEvent]s. Scale and opacity interpolate
/// between their `min` and `max` values over the [maxRadius] proximity zone.
///
/// ```dart
/// VariableProximityText(
///   text: 'Hover me',
///   maxRadius: 140,
///   minScale: 0.95,
///   maxScale: 1.20,
/// )
/// ```
class VariableProximityText extends StatefulWidget {
  const VariableProximityText({
    super.key,
    required this.text,
    this.style,
    this.trigger = MotionTrigger.onBuild,
    this.enabled = true,
    this.maxRadius = 140,
    this.minScale = 0.95,
    this.maxScale = 1.20,
    this.minOpacity = 0.55,
    this.maxOpacity = 1.0,
    this.textAlign,
  });

  /// The string to render.
  final String text;

  /// Text style; defaults to [DefaultTextStyle].
  final TextStyle? style;

  /// When proximity detection becomes active.
  final MotionTrigger trigger;

  /// Set to `false` to render as plain static text.
  final bool enabled;

  /// Radius in logical pixels around the pointer within which glyphs react.
  final double maxRadius;

  /// Scale at maximum distance (or when no pointer is present).
  final double minScale;

  /// Scale at the closest proximity (pointer directly over glyph).
  final double maxScale;

  /// Opacity at maximum distance.
  final double minOpacity;

  /// Opacity at closest proximity.
  final double maxOpacity;

  /// Text alignment of the laid-out text.
  final TextAlign? textAlign;

  @override
  State<VariableProximityText> createState() => _VariableProximityTextState();
}

class _VariableProximityTextState extends State<VariableProximityText> {
  Offset? _p;
  bool _started = false;

  void _start() {
    if (_started) return;
    _started = true;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final reduced = ReducedMotion.of(context) || !widget.enabled;
    final style = widget.style ?? DefaultTextStyle.of(context).style;

    Widget body = reduced
        ? Text(widget.text, style: style, textAlign: widget.textAlign)
        : LayoutBuilder(
            builder: (_, c) {
              final maxW = c.maxWidth.isFinite ? c.maxWidth : 10000.0;
              final tp = TextPainter(
                text: TextSpan(text: widget.text, style: style),
                textDirection: ui.TextDirection.ltr,
                textAlign: widget.textAlign ?? TextAlign.start,
              )..layout(maxWidth: maxW);

              final boxes = _glyphBoxes(widget.text, style, tp);
              final size = tp.size;

              return Listener(
                onPointerHover: (e) => setState(() => _p = e.localPosition),
                onPointerMove: (e) => setState(() => _p = e.localPosition),
                onPointerDown: (e) => setState(() => _p = e.localPosition),
                onPointerUp: (_) => setState(() => _p = null),
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: Stack(
                    children: [
                      for (final g in boxes)
                        Positioned(
                          left: g.rect.left,
                          top: g.rect.top,
                          child: _ProxGlyph(
                            glyph: g.glyph,
                            rect: g.rect,
                            pointer: _p,
                            style: style,
                            maxRadius: widget.maxRadius,
                            minScale: widget.minScale,
                            maxScale: widget.maxScale,
                            minOpacity: widget.minOpacity,
                            maxOpacity: widget.maxOpacity,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );

    return MotionTriggerWrapper(
      trigger: widget.trigger,
      enabled: !reduced,
      onStart: _start,
      child: body,
    );
  }

  List<_GlyphBox> _glyphBoxes(String text, TextStyle style, TextPainter tp) {
    final out = <_GlyphBox>[];
    int cu = 0;
    for (final g in text.characters) {
      final start = cu;
      final end = cu + g.length;
      cu = end;

      final sel = TextSelection(baseOffset: start, extentOffset: end);
      final b = tp.getBoxesForSelection(sel);
      if (b.isEmpty) {
        out.add(_GlyphBox(g, const Rect.fromLTWH(0, 0, 0, 0)));
      } else {
        out.add(_GlyphBox(g, b.first.toRect()));
      }
    }
    return out;
  }
}

/// A high-contrast proximity preset for [VariableProximityText].
///
/// Uses a wider scale range (`0.92` – `1.28`) and lower minimum opacity
/// (`0.45`) compared to the base widget, giving a pronounced “pressure” feel.
///
/// ```dart
/// TextPressure(text: 'Push me', maxRadius: 160)
/// ```
class TextPressure extends StatelessWidget {
  const TextPressure({
    super.key,
    required this.text,
    this.style,
    this.enabled = true,
    this.maxRadius = 160,
  });

  /// The string to render.
  final String text;

  /// Text style; defaults to [DefaultTextStyle].
  final TextStyle? style;

  /// Set to `false` to render as plain static text.
  final bool enabled;

  /// Radius of pointer influence in logical pixels.
  final double maxRadius;

  @override
  Widget build(BuildContext context) {
    return VariableProximityText(
      text: text,
      style: style,
      enabled: enabled,
      maxRadius: maxRadius,
      minScale: 0.92,
      maxScale: 1.28,
      minOpacity: 0.45,
      maxOpacity: 1.0,
    );
  }
}

class _GlyphBox {
  _GlyphBox(this.glyph, this.rect);
  final String glyph;
  final Rect rect;
}

class _ProxGlyph extends StatelessWidget {
  const _ProxGlyph({
    required this.glyph,
    required this.rect,
    required this.pointer,
    required this.style,
    required this.maxRadius,
    required this.minScale,
    required this.maxScale,
    required this.minOpacity,
    required this.maxOpacity,
  });

  final String glyph;
  final Rect rect;
  final Offset? pointer;
  final TextStyle style;

  final double maxRadius;
  final double minScale;
  final double maxScale;
  final double minOpacity;
  final double maxOpacity;

  @override
  Widget build(BuildContext context) {
    final isSpace = glyph.trim().isEmpty;
    if (isSpace) return Text(glyph, style: style);

    double t = 0;
    if (pointer != null) {
      final center = rect.center;
      final d = (pointer! - center).distance;
      t = (1.0 - (d / maxRadius)).clamp(0.0, 1.0);
      t = Curves.easeOut.transform(t);
    }

    final scale = ui.lerpDouble(minScale, maxScale, t)!;
    final opacity = ui.lerpDouble(minOpacity, maxOpacity, t)!;

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.center,
        child: Text(glyph, style: style),
      ),
    );
  }
}

/* ----------------------------- 8) CurvedLoop ---------------------------- */

/// Signature for a function that returns the bezier paths for [CurvedLoop].
typedef CurvedLoopPathBuilder = List<Path> Function(Size size);

/// Scrolls text continuously along one or more bezier curves.
///
/// By default two opposing arcs are rendered. Supply a custom [pathBuilder]
/// to define your own curves. The widget is interactive by default: a pan
/// gesture scrubs the scroll offset.
///
/// ```dart
/// CurvedLoop(
///   text: 'MARQUEE',
///   speed: 60,
///   backgroundColor: Colors.black,
///   style: TextStyle(color: Colors.white),
/// )
/// ```
class CurvedLoop extends StatefulWidget {
  const CurvedLoop({
    super.key,
    required this.text,
    this.style,
    this.speed = 60,
    this.reverse = false,
    this.interactive = true,
    this.gap = '   •   ',
    this.pathBuilder,
    this.strokeDebug,
    this.enabled = true,
    this.backgroundColor,
    this.stripPadding = 6.0,
  });

  /// The string to scroll.
  final String text;

  /// Text style; defaults to [DefaultTextStyle].
  final TextStyle? style;

  /// Scroll speed in logical pixels per second.
  final double speed;

  /// Reverse the default scroll direction.
  final bool reverse;

  /// Allow dragging to scrub the scroll offset.
  final bool interactive;

  /// String inserted between repetitions of [text] to create visual spacing.
  final String gap;

  /// Override the default two-arc layout with custom bezier paths.
  final CurvedLoopPathBuilder? pathBuilder;

  /// If non-null, draws this [Paint] over each path for debugging.
  final Paint? strokeDebug;

  /// Set to `false` to freeze the animation.
  final bool enabled;

  /// If non-null, a filled band of this colour is stroked along each path
  /// behind the text to create a marquee-strip effect.
  final Color? backgroundColor;

  /// Extra padding in logical pixels above and below the text inside the
  /// [backgroundColor] strip.
  final double stripPadding;

  @override
  State<CurvedLoop> createState() => _CurvedLoopState();
}

class _CurvedLoopState extends State<CurvedLoop>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _offsetPx = 0.0;
  double _dragVelocity = 0.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt =
        (_last == Duration.zero) ? 0.0 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;

    final dir = widget.reverse ? -1.0 : 1.0;
    _offsetPx += dir * widget.speed * dt;
    _offsetPx += _dragVelocity * dt;
    _dragVelocity *= math.pow(0.08, dt).toDouble();

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  List<Path> _defaultPaths(Size s) {
    final w = s.width;
    final h = s.height;

    // Top arc: runs left→right, bowing upward.
    // Starts and ends at 30% height, peaks at 10% height.
    final top = Path()
      ..moveTo(0, h * 0.30)
      ..quadraticBezierTo(w * 0.5, h * 0.05, w, h * 0.30);

    // Bottom arc: runs left→right, bowing downward.
    // Starts and ends at 70% height, dips to 90% height.
    // Scrolls in the opposite direction for a wave effect.
    final bottom = Path()
      ..moveTo(0, h * 0.70)
      ..quadraticBezierTo(w * 0.5, h * 0.95, w, h * 0.70);

    return [top, bottom];
  }

  @override
  Widget build(BuildContext context) {
    final reduced = ReducedMotion.of(context) || !widget.enabled;
    final style = widget.style ?? DefaultTextStyle.of(context).style;

    Widget painted = CustomPaint(
      painter: _CurvedLoopPainter(
        text: widget.text,
        gap: widget.gap,
        style: style,
        offsetPx: _offsetPx,
        pathsBuilder: widget.pathBuilder ?? _defaultPaths,
        strokeDebug: widget.strokeDebug,
        backgroundColor: widget.backgroundColor,
        stripPadding: widget.stripPadding,
      ),
      size: Size.infinite,
    );

    if (reduced || !widget.interactive) return painted;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (d) => setState(() {
        _offsetPx += d.delta.dx;
        _dragVelocity = d.delta.dx * 60.0;
      }),
      child: painted,
    );
  }
}

class _CurvedLoopPainter extends CustomPainter {
  _CurvedLoopPainter({
    required this.text,
    required this.gap,
    required this.style,
    required this.offsetPx,
    required this.pathsBuilder,
    this.strokeDebug,
    this.backgroundColor,
    this.stripPadding = 6.0,
  });

  final String text;
  final String gap;
  final TextStyle style;
  final double offsetPx;
  final CurvedLoopPathBuilder pathsBuilder;
  final Paint? strokeDebug;
  final Color? backgroundColor;
  final double stripPadding;

  @override
  void paint(Canvas canvas, Size size) {
    final paths = pathsBuilder(size);
    final content = text + gap;
    if (content.isEmpty) return;

    // Pre-measure every character once so space characters get a
    // sensible minimum advance width (canvas text measurement can
    // return 0 for spaces on some platforms).
    final em = style.fontSize ?? 14.0;
    final charPainters = <TextPainter>[];
    final charWidths = <double>[];
    double repeatWidth = 0.0;
    for (int k = 0; k < content.length; k++) {
      final tp = TextPainter(
        text: TextSpan(text: content[k], style: style),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      // Give whitespace a minimum width proportional to em size so
      // stretches of spaces / bullet separators remain visible.
      final w = math.max(tp.width, em * 0.25);
      charPainters.add(tp);
      charWidths.add(w);
      repeatWidth += w;
    }
    if (repeatWidth <= 0) return;

    // Stroke width that creates a filled band tall enough to contain the text.
    final bandWidth = em * 1.4 + stripPadding * 2;

    for (int i = 0; i < paths.length; i++) {
      final path = paths[i];

      // Draw background strip first so text paints on top.
      if (backgroundColor != null) {
        final stripPaint = Paint()
          ..color = backgroundColor!
          ..style = PaintingStyle.stroke
          ..strokeWidth = bandWidth
          ..strokeCap = StrokeCap.butt // flat 90° ends
          ..strokeJoin = StrokeJoin.miter;
        canvas.drawPath(path, stripPaint);
      }

      if (strokeDebug != null) canvas.drawPath(path, strokeDebug!);

      final metrics = path.computeMetrics().toList();
      if (metrics.isEmpty) continue;
      final metric = metrics.first;
      final pathLen = metric.length;
      if (pathLen <= 0) continue;

      // Alternate scroll direction per path for a nice wave effect.
      final localDir = (i.isOdd) ? -1.0 : 1.0;
      final rawBase = (localDir * offsetPx) % repeatWidth;
      // Negative-safe modulo so the origin is always in [0, repeatWidth).
      final charStart = rawBase < 0 ? rawBase + repeatWidth : rawBase;

      // Find which character and intra-character offset corresponds to
      // charStart so the text "scrolls" seamlessly (no snap on loop).
      double charOffset = 0.0;
      int charIdx = 0;
      {
        double acc = 0.0;
        for (int k = 0; k < content.length; k++) {
          final next = acc + charWidths[k];
          if (next > charStart) {
            charIdx = k;
            charOffset = charStart - acc;
            break;
          }
          acc = next;
        }
      }

      // Walk along the path filling it with repeating text.
      // Start cursor at -charOffset so the first character scrolls in
      // from the left edge rather than snapping.
      double cursor = -charOffset;

      while (cursor < pathLen) {
        final idx = charIdx % content.length;
        final tp = charPainters[idx];
        final w = charWidths[idx];

        // Only sample the path for visible characters.
        if (cursor + w > 0) {
          // Clamp to valid path range.
          final pos = (cursor + w / 2).clamp(0.0, pathLen - 0.001);
          final tan = metric.getTangentForOffset(pos);
          if (tan != null) {
            canvas.save();
            canvas.translate(tan.position.dx, tan.position.dy);

            // Normalise angle so text always reads left-to-right.
            // Paths that run right→left have angle ≈ ±π, which would
            // flip every glyph upside-down without this correction.
            double angle = tan.angle;
            double dy = -tp.height / 2;
            if (angle > math.pi / 2 || angle < -math.pi / 2) {
              angle += math.pi;
              dy = tp.height / 2;
            }
            canvas.rotate(angle);
            tp.paint(canvas, Offset(-w / 2, dy));
            canvas.restore();
          }
        }

        cursor += w;
        charIdx++;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CurvedLoopPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.gap != gap ||
        oldDelegate.style != style ||
        oldDelegate.offsetPx != offsetPx ||
        oldDelegate.strokeDebug != strokeDebug ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.stripPadding != stripPadding;
  }
}

/* ----------------------------- 9) FuzzyText ----------------------------- */

/// Applies a small looping oscillation and Gaussian blur to create a
/// continuously “fuzzy” or vibrating text effect.
///
/// ```dart
/// FuzzyText(text: 'Fuzzy', jitter: 1.4, blurSigma: 0.8)
/// ```
class FuzzyText extends StatefulWidget {
  const FuzzyText({
    super.key,
    required this.text,
    this.style,
    this.trigger = MotionTrigger.onBuild,
    this.period = const Duration(milliseconds: 1400),
    this.jitter = 1.4,
    this.blurSigma = 0.8,
    this.enabled = true,
    this.textAlign,
  });

  /// The string to render.
  final String text;

  /// Text style; defaults to [DefaultTextStyle].
  final TextStyle? style;

  /// When to start the looping oscillation.
  final MotionTrigger trigger;

  /// Period of one oscillation cycle.
  final Duration period;

  /// Maximum translation offset in logical pixels.
  final double jitter;

  /// Gaussian blur sigma applied to the text on every frame.
  final double blurSigma;

  /// Set to `false` to render plain static text.
  final bool enabled;

  /// Text alignment.
  final TextAlign? textAlign;

  @override
  State<FuzzyText> createState() => _FuzzyTextState();
}

class _FuzzyTextState extends State<FuzzyText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.period);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _start() {
    if (_started) return;
    _started = true;
    _c.repeat();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = ReducedMotion.of(context) || !widget.enabled;
    final style = widget.style ?? DefaultTextStyle.of(context).style;

    final body = reduced
        ? Text(widget.text, style: style, textAlign: widget.textAlign)
        : AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final t = _c.value * math.pi * 2;
              final dx = math.sin(t) * widget.jitter;
              final dy = math.cos(t * 1.3) * widget.jitter;

              return ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                    sigmaX: widget.blurSigma, sigmaY: widget.blurSigma),
                child: Transform.translate(
                  offset: Offset(dx, dy),
                  child: Text(widget.text,
                      style: style, textAlign: widget.textAlign),
                ),
              );
            },
          );

    return MotionTriggerWrapper(
      trigger: widget.trigger,
      enabled: !reduced,
      onStart: _start,
      child: body,
    );
  }
}

/* ---------------------------- 10) GradientText -------------------------- */

/// Renders text with a `LinearGradient` shader that slowly rotates,
/// producing an ever-changing colourful fill.
///
/// ```dart
/// GradientText(text: 'Colorful', colors: [Colors.purple, Colors.cyan])
/// ```
class GradientText extends StatefulWidget {
  const GradientText({
    super.key,
    required this.text,
    this.style,
    this.colors = const [
      Color(0xFF7C3AED),
      Color(0xFF06B6D4),
      Color(0xFFF59E0B)
    ],
    this.trigger = MotionTrigger.onBuild,
    this.duration = const Duration(milliseconds: 2400),
    this.enabled = true,
    this.textAlign,
  });

  /// The string to render.
  final String text;

  /// Text style (colour is overridden by the gradient shader).
  final TextStyle? style;

  /// Gradient colour stops. Must contain at least two colours.
  final List<Color> colors;

  /// When to start rotating the gradient.
  final MotionTrigger trigger;

  /// Duration of one full gradient rotation.
  final Duration duration;

  /// Set to `false` to render with a static gradient (no animation).
  final bool enabled;

  /// Text alignment.
  final TextAlign? textAlign;

  @override
  State<GradientText> createState() => _GradientTextState();
}

class _GradientTextState extends State<GradientText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _start() {
    if (_started) return;
    _started = true;
    _c.repeat();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = ReducedMotion.of(context) || !widget.enabled;
    final style = widget.style ?? DefaultTextStyle.of(context).style;

    final body = reduced
        ? Text(widget.text, style: style, textAlign: widget.textAlign)
        : AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final t = _c.value;
              final dx = math.cos(t * math.pi * 2) * 0.35;
              final dy = math.sin(t * math.pi * 2) * 0.35;

              final shader = LinearGradient(
                colors: widget.colors,
                begin: Alignment(-1 - dx, -1 - dy),
                end: Alignment(1 - dx, 1 - dy),
              ).createShader(const Rect.fromLTWH(0, 0, 600, 200));

              return Text(
                widget.text,
                textAlign: widget.textAlign,
                style: style.copyWith(foreground: Paint()..shader = shader),
              );
            },
          );

    return MotionTriggerWrapper(
      trigger: widget.trigger,
      enabled: !reduced,
      onStart: _start,
      child: body,
    );
  }
}

/* ---------------------------- 11) FallingText --------------------------- */

/// A particle system where characters from [text] rain down with simulated
/// gravity. Characters wrap back to the top of the widget when they fall
/// off the bottom edge.
///
/// ```dart
/// FallingText(text: 'RAIN', gravity: 900, particleCount: 80)
/// ```
class FallingText extends StatefulWidget {
  const FallingText({
    super.key,
    required this.text,
    this.style,
    this.enabled = true,
    this.particleCount = 80,
    this.gravity = 900,
    this.trigger = MotionTrigger.onBuild,
  });

  /// The pool of characters to use as particles (cycled by index).
  final String text;

  /// Text style for every particle.
  final TextStyle? style;

  /// Set to `false` to show static text.
  final bool enabled;

  /// Total number of falling character particles.
  final int particleCount;

  /// Downward gravitational acceleration in logical pixels per second squared.
  final double gravity;

  /// When to start the simulation.
  final MotionTrigger trigger;

  @override
  State<FallingText> createState() => _FallingTextState();
}

class _FallingTextState extends State<FallingText>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _started = false;

  final _rnd = math.Random(1);
  late List<_FallParticle> _ps;

  void _reset(Size s) {
    final chars = SegmentedText.split(widget.text, AnimateBy.graphemes)
        .where((g) => g.isNotEmpty)
        .toList();
    _ps = List.generate(widget.particleCount, (i) {
      final g = chars[i % chars.length];
      return _FallParticle(
        glyph: g,
        x: _rnd.nextDouble() * s.width,
        y: -_rnd.nextDouble() * s.height,
        vx: (_rnd.nextDouble() - 0.5) * 60,
        vy: _rnd.nextDouble() * 40,
        rot: _rnd.nextDouble() * math.pi * 2,
        vr: (_rnd.nextDouble() - 0.5) * 2.0,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _ps = [];
    _ticker = createTicker(_onTick);
  }

  void _start() {
    if (_started) return;
    _started = true;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final dt =
        (_last == Duration.zero) ? 0.0 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (!mounted) return;
    setState(() {
      for (final p in _ps) {
        p.vy += widget.gravity * dt;
        p.x += p.vx * dt;
        p.y += p.vy * dt;
        p.rot += p.vr * dt;
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = ReducedMotion.of(context) || !widget.enabled;
    final style = widget.style ?? DefaultTextStyle.of(context).style;

    Widget body = reduced
        ? Text(widget.text, style: style)
        : LayoutBuilder(
            builder: (_, c) {
              final s = Size(c.maxWidth.isFinite ? c.maxWidth : 300,
                  c.maxHeight.isFinite ? c.maxHeight : 200);
              if (_ps.isEmpty) _reset(s);

              return CustomPaint(
                painter: _FallingPainter(_ps, style, s),
                size: Size.infinite,
              );
            },
          );

    return MotionTriggerWrapper(
      trigger: widget.trigger,
      enabled: !reduced,
      onStart: _start,
      child: body,
    );
  }
}

class _FallParticle {
  _FallParticle({
    required this.glyph,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rot,
    required this.vr,
  });

  final String glyph;
  double x, y, vx, vy, rot, vr;
}

class _FallingPainter extends CustomPainter {
  _FallingPainter(this.ps, this.style, this.size0);

  final List<_FallParticle> ps;
  final TextStyle style;
  final Size size0;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in ps) {
      if (p.y > size0.height + 60) {
        p.y = -60;
        p.vy = 0;
      }
      final tp = TextPainter(
        text: TextSpan(text: p.glyph, style: style),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rot);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _FallingPainter old) => true;
}

/* ---------------------------- 12) TextCursorTrail ----------------------- */

/// Renders characters of [text] at past pointer positions, fading each
/// character out over [fade] duration to create a trailing effect.
///
/// ```dart
/// TextCursorTrail(text: 'trail', maxPoints: 22)
/// ```
class TextCursorTrail extends StatefulWidget {
  const TextCursorTrail({
    super.key,
    required this.text,
    this.style,
    this.enabled = true,
    this.maxPoints = 22,
    this.fade = const Duration(milliseconds: 700),
  });

  /// Characters cycled across trail positions.
  final String text;

  /// Text style for each trail character.
  final TextStyle? style;

  /// Set to `false` to hide the trail.
  final bool enabled;

  /// Maximum number of cursor positions retained in the trail.
  final int maxPoints;

  /// How long each character takes to fully fade out.
  final Duration fade;

  @override
  State<TextCursorTrail> createState() => _TextCursorTrailState();
}

class _TextCursorTrailState extends State<TextCursorTrail> {
  final _pts = <_TrailPoint>[];
  int _i = 0;

  void _add(Offset p) {
    final now = DateTime.now();
    _pts.add(_TrailPoint(p, now, _i++));
    while (_pts.length > widget.maxPoints) {
      _pts.removeAt(0);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final reduced = ReducedMotion.of(context) || !widget.enabled;
    final style = widget.style ?? DefaultTextStyle.of(context).style;

    if (reduced) return Text(widget.text, style: style);

    return Listener(
      onPointerHover: (e) => _add(e.localPosition),
      onPointerMove: (e) => _add(e.localPosition),
      child: CustomPaint(
        painter: _TrailPainter(_pts, widget.text, style, widget.fade),
        size: Size.infinite,
      ),
    );
  }
}

class _TrailPoint {
  _TrailPoint(this.p, this.t, this.i);
  final Offset p;
  final DateTime t;
  final int i;
}

class _TrailPainter extends CustomPainter {
  _TrailPainter(this.pts, this.text, this.style, this.fade);

  final List<_TrailPoint> pts;
  final String text;
  final TextStyle style;
  final Duration fade;

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now();
    for (final pt in pts) {
      final age = now.difference(pt.t).inMilliseconds / fade.inMilliseconds;
      final o = (1.0 - age).clamp(0.0, 1.0);
      if (o <= 0) continue;

      final ch = text.isEmpty ? '*' : text[pt.i % text.length];
      final tp = TextPainter(
        text: TextSpan(text: ch, style: style),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(pt.p.dx, pt.p.dy);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _TrailPainter old) => true;
}

/* ---------------------------- 13) DecryptedText ------------------------- */

/// Reveals text by replacing each character with random symbols that
/// successively “decrypt” into the final character, from left to right.
///
/// ```dart
/// DecryptedText(text: 'CLASSIFIED')
/// ```
class DecryptedText extends StatefulWidget {
  const DecryptedText({
    super.key,
    required this.text,
    this.style,
    this.trigger = MotionTrigger.onVisible,
    this.duration = const Duration(milliseconds: 1400),
    this.charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%^&*()-_=+[]{}',
    this.textAlign,
    this.enabled = true,
  });

  /// The target string to decrypt into.
  final String text;

  /// Text style; defaults to [DefaultTextStyle].
  final TextStyle? style;

  /// When to start the decryption animation.
  final MotionTrigger trigger;

  /// Time to fully decrypt all characters.
  final Duration duration;

  /// Pool of characters used as random substitutes before each position locks.
  final String charset;

  /// Text alignment.
  final TextAlign? textAlign;

  /// Set to `false` to show the final text immediately.
  final bool enabled;

  @override
  State<DecryptedText> createState() => _DecryptedTextState();
}

class _DecryptedTextState extends State<DecryptedText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final _rnd = math.Random();
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _start() {
    if (_started) return;
    _started = true;
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = ReducedMotion.of(context) || !widget.enabled;
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    final target = SegmentedText.split(widget.text, AnimateBy.graphemes);

    final body = reduced
        ? Text(widget.text, style: style, textAlign: widget.textAlign)
        : AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final p = Curves.easeOutCubic.transform(_c.value);
              final lockCount =
                  (p * target.length).floor().clamp(0, target.length);
              final buf = StringBuffer();
              for (int i = 0; i < target.length; i++) {
                if (i < lockCount) {
                  buf.write(target[i]);
                } else {
                  final t = target[i];
                  if (t.trim().isEmpty) {
                    buf.write(t);
                  } else {
                    buf.write(
                        widget.charset[_rnd.nextInt(widget.charset.length)]);
                  }
                }
              }
              return Text(buf.toString(),
                  style: style, textAlign: widget.textAlign);
            },
          );

    return MotionTriggerWrapper(
      trigger: widget.trigger,
      enabled: !reduced,
      onStart: _start,
      child: body,
    );
  }
}

/* ---------------------------- 14) TrueFocus ----------------------------- */

/// Sweeps a sharp “focus window” across blurred text, creating a
/// depth-of-field pan effect.
///
/// The blurred layer and the sharp clipped layer are stacked; the clip rect
/// oscillates horizontally using [Curves.easeInOut].
///
/// ```dart
/// TrueFocus(text: 'Focus', blurSigma: 8, focusWidthFraction: 0.35)
/// ```
class TrueFocus extends StatefulWidget {
  const TrueFocus({
    super.key,
    required this.text,
    this.style,
    this.enabled = true,
    this.trigger = MotionTrigger.onBuild,
    this.duration = const Duration(milliseconds: 1800),
    this.blurSigma = 8,
    this.focusWidthFraction = 0.35,
    this.textAlign,
  });

  /// The string to render.
  final String text;

  /// Text style; defaults to [DefaultTextStyle].
  final TextStyle? style;

  /// Set to `false` to render plain unblurred text.
  final bool enabled;

  /// When to start the focus sweep.
  final MotionTrigger trigger;

  /// Duration of one full sweep cycle.
  final Duration duration;

  /// Gaussian blur sigma applied to the out-of-focus layer.
  final double blurSigma;

  /// Width of the sharp focus window as a fraction of the widget width (0 – 1).
  final double focusWidthFraction;

  /// Text alignment.
  final TextAlign? textAlign;

  @override
  State<TrueFocus> createState() => _TrueFocusState();
}

class _TrueFocusState extends State<TrueFocus>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _start() {
    if (_started) return;
    _started = true;
    _c.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = ReducedMotion.of(context) || !widget.enabled;
    final style = widget.style ?? DefaultTextStyle.of(context).style;

    final body = reduced
        ? Text(widget.text, style: style, textAlign: widget.textAlign)
        : LayoutBuilder(
            builder: (_, c) {
              final w = c.maxWidth.isFinite ? c.maxWidth : 400.0;
              final focusW = w * widget.focusWidthFraction;

              return AnimatedBuilder(
                animation: _c,
                builder: (_, __) {
                  final x = (w - focusW) * Curves.easeInOut.transform(_c.value);
                  return Stack(
                    children: [
                      ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(
                            sigmaX: widget.blurSigma, sigmaY: widget.blurSigma),
                        child: Text(widget.text,
                            style: style, textAlign: widget.textAlign),
                      ),
                      ClipRect(
                        clipper:
                            _RectClipper(Rect.fromLTWH(x, 0, focusW, 10000)),
                        child: Text(widget.text,
                            style: style, textAlign: widget.textAlign),
                      ),
                    ],
                  );
                },
              );
            },
          );

    return MotionTriggerWrapper(
      trigger: widget.trigger,
      enabled: !reduced,
      onStart: _start,
      child: body,
    );
  }
}

class _RectClipper extends CustomClipper<Rect> {
  _RectClipper(this.r);
  final Rect r;
  @override
  Rect getClip(Size size) => Rect.fromLTWH(r.left, 0, r.width, size.height);
  @override
  bool shouldReclip(covariant _RectClipper oldClipper) => oldClipper.r != r;
}

/* ---------------------------- 15) ScrollFloatText ----------------------- */

/// Translates and fades text proportionally to the enclosing scroll
/// view’s velocity, creating a floating parallax effect.
///
/// Must be placed inside a [ScrollView] to receive [ScrollNotification]s.
///
/// ```dart
/// ScrollFloatText(text: 'Float', maxOffset: 24)
/// ```
class ScrollFloatText extends StatefulWidget {
  const ScrollFloatText({
    super.key,
    required this.text,
    this.style,
    this.enabled = true,
    this.maxOffset = 24,
    this.maxFade = 0.35,
  });

  /// The string to render.
  final String text;

  /// Text style; defaults to [DefaultTextStyle].
  final TextStyle? style;

  /// Set to `false` to render plain static text.
  final bool enabled;

  /// Maximum vertical translation in logical pixels at peak scroll speed.
  final double maxOffset;

  /// Maximum opacity reduction (0 – 1) at peak scroll speed.
  final double maxFade;

  @override
  State<ScrollFloatText> createState() => _ScrollFloatTextState();
}

class _ScrollFloatTextState extends State<ScrollFloatText> {
  double _v = 0.0;
  int _lastT = 0;
  double _lastPixels = 0;

  @override
  Widget build(BuildContext context) {
    final reduced = ReducedMotion.of(context) || !widget.enabled;
    final style = widget.style ?? DefaultTextStyle.of(context).style;

    if (reduced) return Text(widget.text, style: style);

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final dt = (now - _lastT).clamp(1, 1000);
        final dp = (n.metrics.pixels - _lastPixels);
        _lastT = now;
        _lastPixels = n.metrics.pixels;
        final vel = (dp / dt) * 1000.0;

        setState(() => _v = _v * 0.85 + vel * 0.15);
        return false;
      },
      child: Builder(
        builder: (_) {
          final t = (_v.abs() / 2200).clamp(0.0, 1.0);
          final y = widget.maxOffset * t * (_v.isNegative ? -1 : 1);
          final o = (1.0 - widget.maxFade * t).clamp(0.0, 1.0);
          return Opacity(
              opacity: o,
              child: Transform.translate(
                  offset: Offset(0, y),
                  child: Text(widget.text, style: style)));
        },
      ),
    );
  }
}

/* ---------------------------- 16) ScrollRevealText ---------------------- */

/// A convenience alias for [SplitText] configured for scroll-reveal.
///
/// Words slide up and fade in when the widget becomes visible. Identical to:
/// ```dart
/// SplitText(
///   text: text,
///   animateBy: AnimateBy.words,
///   direction: SplitDirection.up,
///   trigger: MotionTrigger.onVisible,
/// )
/// ```
class ScrollRevealText extends StatelessWidget {
  const ScrollRevealText({
    super.key,
    required this.text,
    this.style,
    this.enabled = true,
    this.trigger = MotionTrigger.onVisible,
    this.duration = const Duration(milliseconds: 900),
  });

  /// The string to reveal.
  final String text;

  /// Text style; defaults to [DefaultTextStyle].
  final TextStyle? style;

  /// Set to `false` to show the full text immediately.
  final bool enabled;

  /// Override the trigger strategy.
  final MotionTrigger trigger;

  /// Animation duration.
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return SplitText(
      text: text,
      style: style,
      enabled: enabled,
      trigger: trigger,
      duration: duration,
      animateBy: AnimateBy.words,
      direction: SplitDirection.up,
    );
  }
}

/* ---------------------------- 17) AsciiScrambleText --------------------- */

/// A [ShuffleText] preset that uses an ASCII density ramp as the charset,
/// giving a retro ASCII-art decoding feel. Uses a monospace font.
///
/// ```dart
/// AsciiScrambleText(text: 'DECODE')
/// ```
class AsciiScrambleText extends StatelessWidget {
  const AsciiScrambleText({
    super.key,
    required this.text,
    this.style,
    this.enabled = true,
  });

  /// The string to reveal.
  final String text;

  /// Text style (overrides `fontFamily` to `monospace`).
  final TextStyle? style;

  /// Set to `false` to show the final text immediately.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ShuffleText(
      text: text,
      style: (style ?? DefaultTextStyle.of(context).style)
          .copyWith(fontFamily: 'monospace'),
      enabled: enabled,
      charset: r' .,:;i1tfLCG08@',
    );
  }
}

/* ---------------------------- 18) ScrambledText ------------------------- */

/// Reveals each character in a randomised order; un-revealed characters are
/// replaced with random glyphs from [charset] until their turn.
///
/// ```dart
/// ScrambledText(text: 'SCRAMBLE')
/// ```
class ScrambledText extends StatefulWidget {
  const ScrambledText({
    super.key,
    required this.text,
    this.style,
    this.enabled = true,
    this.trigger = MotionTrigger.onVisible,
    this.duration = const Duration(milliseconds: 1200),
    this.charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
  });

  /// The target string.
  final String text;

  /// Text style; defaults to [DefaultTextStyle].
  final TextStyle? style;

  /// Set to `false` to show the final text immediately.
  final bool enabled;

  /// When to start revealing.
  final MotionTrigger trigger;

  /// Time to fully reveal all characters.
  final Duration duration;

  /// Pool of substitution characters used before each position is revealed.
  final String charset;

  @override
  State<ScrambledText> createState() => _ScrambledTextState();
}

class _ScrambledTextState extends State<ScrambledText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final _rnd = math.Random();
  late final List<int> _order;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    _order = [];
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _start() {
    if (_started) return;
    _started = true;

    final n = widget.text.characters.length;
    _order
      ..clear()
      ..addAll(List.generate(n, (i) => i));
    _order.shuffle(_rnd);

    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = ReducedMotion.of(context) || !widget.enabled;
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    final target = SegmentedText.split(widget.text, AnimateBy.graphemes);

    final body = reduced
        ? Text(widget.text, style: style)
        : AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final reveal =
                  (_c.value * target.length).floor().clamp(0, target.length);
              final revealed = <int>{..._order.take(reveal)};
              final buf = StringBuffer();

              for (int i = 0; i < target.length; i++) {
                final t = target[i];
                if (t.trim().isEmpty) {
                  buf.write(t);
                } else if (revealed.contains(i)) {
                  buf.write(t);
                } else {
                  buf.write(
                      widget.charset[_rnd.nextInt(widget.charset.length)]);
                }
              }
              return Text(buf.toString(), style: style);
            },
          );

    return MotionTriggerWrapper(
      trigger: widget.trigger,
      enabled: !reduced,
      onStart: _start,
      child: body,
    );
  }
}

/* ---------------------------- 19) RotatingText -------------------------- */

/// Cycles through a list of [items], each transitioning via a slide-up
/// and fade animation.
///
/// ```dart
/// RotatingText(items: ['Fast', 'Simple', 'Beautiful'])
/// ```
class RotatingText extends StatefulWidget {
  const RotatingText({
    super.key,
    required this.items,
    this.style,
    this.trigger = MotionTrigger.onBuild,
    this.period = const Duration(milliseconds: 1800),
    this.transition = const Duration(milliseconds: 450),
    this.curve = Curves.easeOutCubic,
    this.textAlign,
    this.enabled = true,
  });

  /// The strings to cycle through.
  final List<String> items;

  /// Text style; defaults to [DefaultTextStyle].
  final TextStyle? style;

  /// When to start cycling.
  final MotionTrigger trigger;

  /// How long each item is displayed before the next one transitions in.
  final Duration period;

  /// Duration of the slide/fade transition between items.
  final Duration transition;

  /// Easing curve for the transition.
  final Curve curve;

  /// Text alignment.
  final TextAlign? textAlign;

  /// Set to `false` to display only the first item.
  final bool enabled;

  @override
  State<RotatingText> createState() => _RotatingTextState();
}

class _RotatingTextState extends State<RotatingText> {
  int _i = 0;
  bool _started = false;

  void _start() {
    if (_started) return;
    _started = true;
    _tick();
  }

  Future<void> _tick() async {
    while (mounted) {
      await Future.delayed(widget.period);
      if (!mounted) return;
      setState(() => _i = (_i + 1) % widget.items.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = ReducedMotion.of(context) || !widget.enabled;
    final style = widget.style ?? DefaultTextStyle.of(context).style;

    final body = reduced
        ? Text(widget.items.isEmpty ? '' : widget.items.first,
            style: style, textAlign: widget.textAlign)
        : AnimatedSwitcher(
            duration: widget.transition,
            switchInCurve: widget.curve,
            switchOutCurve: widget.curve,
            transitionBuilder: (child, anim) {
              final slide =
                  Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero)
                      .animate(anim);
              return ClipRect(
                  child: SlideTransition(
                      position: slide,
                      child: FadeTransition(opacity: anim, child: child)));
            },
            child: Text(
              widget.items.isEmpty ? '' : widget.items[_i],
              key: ValueKey(_i),
              style: style,
              textAlign: widget.textAlign,
            ),
          );

    return MotionTriggerWrapper(
      trigger: widget.trigger,
      enabled: !reduced && widget.items.length > 1,
      onStart: _start,
      child: body,
    );
  }
}

/* ---------------------------- 20) GlitchText ---------------------------- */

/// Applies a periodic RGB-split chromatic aberration effect with a random
/// horizontal slice glitch to the text.
///
/// ```dart
/// GlitchText(text: 'GLITCH', period: Duration(milliseconds: 1200))
/// ```
class GlitchText extends StatefulWidget {
  const GlitchText({
    super.key,
    required this.text,
    this.style,
    this.enabled = true,
    this.trigger = MotionTrigger.onBuild,
    this.period = const Duration(milliseconds: 1200),
  });

  /// The string to render.
  final String text;

  /// Text style; defaults to [DefaultTextStyle].
  final TextStyle? style;

  /// Set to `false` to render plain static text.
  final bool enabled;

  /// When to start the glitch loop.
  final MotionTrigger trigger;

  /// Duration of one glitch cycle (burst occurs in the last 14 % of the cycle).
  final Duration period;

  @override
  State<GlitchText> createState() => _GlitchTextState();
}

class _GlitchTextState extends State<GlitchText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final _rnd = math.Random();
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.period);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _start() {
    if (_started) return;
    _started = true;
    _c.repeat();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = ReducedMotion.of(context) || !widget.enabled;
    final base = widget.style ?? DefaultTextStyle.of(context).style;

    final body = reduced
        ? Text(widget.text, style: base)
        : AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final burst = (_c.value > 0.86) ? 1.0 : 0.0;
              final dx = burst * ((_rnd.nextDouble() - 0.5) * 10);
              final dy = burst * ((_rnd.nextDouble() - 0.5) * 6);

              return Stack(
                children: [
                  Text(widget.text, style: base),
                  Transform.translate(
                    offset: Offset(dx + 2, dy),
                    child: Opacity(
                        opacity: 0.6 * burst,
                        child: Text(widget.text,
                            style: base.copyWith(color: Colors.cyan))),
                  ),
                  Transform.translate(
                    offset: Offset(dx - 2, dy),
                    child: Opacity(
                        opacity: 0.6 * burst,
                        child: Text(widget.text,
                            style: base.copyWith(color: Colors.pink))),
                  ),
                  ClipRect(
                    clipper: _GlitchSliceClipper(burst, _rnd),
                    child: Transform.translate(
                      offset: Offset(dx, dy),
                      child: Text(widget.text, style: base),
                    ),
                  ),
                ],
              );
            },
          );

    return MotionTriggerWrapper(
      trigger: widget.trigger,
      enabled: !reduced,
      onStart: _start,
      child: body,
    );
  }
}

class _GlitchSliceClipper extends CustomClipper<Rect> {
  _GlitchSliceClipper(this.burst, this.rnd);
  final double burst;
  final math.Random rnd;

  @override
  Rect getClip(Size size) {
    if (burst <= 0) return Rect.fromLTWH(0, 0, size.width, size.height);
    final h = size.height;
    final y = rnd.nextDouble() * (h * 0.75);
    final sliceH = (h * (0.12 + rnd.nextDouble() * 0.18)).clamp(2.0, h);
    return Rect.fromLTWH(0, y, size.width, sliceH);
  }

  @override
  bool shouldReclip(covariant _GlitchSliceClipper oldClipper) => true;
}

/* ---------------------------- 21) ScrollVelocityText -------------------- */

/// Applies a horizontal shear (skew) and motion blur to text proportional to
/// the enclosing scroll view’s velocity.
///
/// Must be placed inside a [ScrollView] to receive [ScrollNotification]s.
///
/// ```dart
/// ScrollVelocityText(text: 'Skew', maxSkew: 0.25, maxBlur: 6)
/// ```
class ScrollVelocityText extends StatefulWidget {
  const ScrollVelocityText({
    super.key,
    required this.text,
    this.style,
    this.enabled = true,
    this.maxSkew = 0.25,
    this.maxBlur = 6,
  });

  /// The string to render.
  final String text;

  /// Text style; defaults to [DefaultTextStyle].
  final TextStyle? style;

  /// Set to `false` to render plain static text.
  final bool enabled;

  /// Maximum horizontal shear (Matrix4 entry `[0,1]`) at peak scroll speed.
  final double maxSkew;

  /// Maximum Gaussian blur sigma at peak scroll speed.
  final double maxBlur;

  @override
  State<ScrollVelocityText> createState() => _ScrollVelocityTextState();
}

class _ScrollVelocityTextState extends State<ScrollVelocityText> {
  double _v = 0.0;
  int _lastT = 0;
  double _lastPixels = 0;

  @override
  Widget build(BuildContext context) {
    final reduced = ReducedMotion.of(context) || !widget.enabled;
    final style = widget.style ?? DefaultTextStyle.of(context).style;

    if (reduced) return Text(widget.text, style: style);

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final dt = (now - _lastT).clamp(1, 1000);
        final dp = (n.metrics.pixels - _lastPixels);
        _lastT = now;
        _lastPixels = n.metrics.pixels;

        final vel = (dp / dt) * 1000.0;
        setState(() => _v = _v * 0.85 + vel * 0.15);
        return false;
      },
      child: Builder(
        builder: (_) {
          final t = (_v.abs() / 2600).clamp(0.0, 1.0);
          final skew = widget.maxSkew * t * (_v.isNegative ? -1 : 1);
          final blur = widget.maxBlur * t;

          return ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur * 0.5),
            child: Transform(
              transform: Matrix4.identity()..setEntry(0, 1, skew),
              alignment: Alignment.centerLeft,
              child: Text(widget.text, style: style),
            ),
          );
        },
      ),
    );
  }
}

/* ---------------------------- 23) CountUp ------------------------------- */

/// Animates a numeric value from [from] to [to] with a configurable easing
/// curve, optionally formatted with an [intl] [NumberFormat].
///
/// ```dart
/// CountUp(from: 0, to: 1000000, formatter: NumberFormat.compact())
/// ```
class CountUp extends StatefulWidget {
  const CountUp({
    super.key,
    required this.to,
    this.from = 0,
    this.decimals = 0,
    this.formatter,
    this.style,
    this.trigger = MotionTrigger.onVisible,
    this.duration = const Duration(milliseconds: 1100),
    this.curve = Curves.easeOutCubic,
    this.textAlign,
    this.enabled = true,
  });

  /// Starting value of the count animation.
  final num from;

  /// Target value the number counts up to.
  final num to;

  /// Number of decimal places used when [formatter] is `null`.
  final int decimals;

  /// Optional [NumberFormat] for custom formatting (e.g. compact, currency).
  final NumberFormat? formatter;

  /// Text style; defaults to [DefaultTextStyle].
  final TextStyle? style;

  /// When to start counting.
  final MotionTrigger trigger;

  /// Duration of the count animation.
  final Duration duration;

  /// Easing curve applied to the numeric interpolation.
  final Curve curve;

  /// Text alignment.
  final TextAlign? textAlign;

  /// Set to `false` to display [to] immediately without animation.
  final bool enabled;

  @override
  State<CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<CountUp> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _start() {
    if (_started) return;
    _started = true;
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = ReducedMotion.of(context) || !widget.enabled;
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    final fmt = widget.formatter;

    String format(num v) {
      if (fmt != null) return fmt.format(v);
      if (widget.decimals <= 0) return v.round().toString();
      return v.toStringAsFixed(widget.decimals);
    }

    final body = reduced
        ? Text(format(widget.to), style: style, textAlign: widget.textAlign)
        : AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final p = widget.curve.transform(_c.value);
              final v = widget.from + (widget.to - widget.from) * p;
              return Text(format(v), style: style, textAlign: widget.textAlign);
            },
          );

    return MotionTriggerWrapper(
      trigger: widget.trigger,
      enabled: !reduced,
      onStart: _start,
      child: body,
    );
  }
}
