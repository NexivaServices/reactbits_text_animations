import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Controls how a text string is segmented before animation.
enum AnimateBy {
  /// Split into individual Unicode grapheme clusters (visual characters).
  graphemes,

  /// Split into whitespace-separated words, preserving spaces as their own
  /// segments so layout is stable during animation.
  words,

  /// Split on newline characters (`\n`).
  lines,
}

/// Controls when an animation begins.
enum MotionTrigger {
  /// Start on the first frame after the widget is built.
  onBuild,

  /// Start when the widget becomes at least [MotionTriggerWrapper.visibleThreshold]
  /// visible in the viewport (uses `visibility_detector`).
  onVisible,

  /// Defer starting; call `start()` from a
  /// [GlobalKey<MotionTriggerWrapperState>] manually.
  manual,
}

/// Utility that splits a [String] into segments according to [AnimateBy].
class SegmentedText {
  /// Returns a list of text segments.
  ///
  /// - [AnimateBy.graphemes]: one entry per visible character.
  /// - [AnimateBy.words]: alternating word/whitespace runs.
  /// - [AnimateBy.lines]: one entry per `\n`-delimited line.
  static List<String> split(String text, AnimateBy by) {
    switch (by) {
      case AnimateBy.graphemes:
        return text.characters.toList();
      case AnimateBy.words:
        return _splitWordsPreserveSpaces(text);
      case AnimateBy.lines:
        return text.split('\n');
    }
  }

  static List<String> _splitWordsPreserveSpaces(String s) {
    final out = <String>[];
    final buf = StringBuffer();
    bool? lastWasSpace;

    for (final g in s.characters) {
      final isSpace = g.trim().isEmpty;
      if (lastWasSpace == null) {
        lastWasSpace = isSpace;
        buf.write(g);
        continue;
      }
      if (isSpace == lastWasSpace) {
        buf.write(g);
      } else {
        out.add(buf.toString());
        buf.clear();
        buf.write(g);
        lastWasSpace = isSpace;
      }
    }
    if (buf.isNotEmpty) out.add(buf.toString());
    return out;
  }
}

/// Checks whether the user has requested reduced motion.
///
/// Returns `true` when **either** [MediaQueryData.disableAnimations] is `true`
/// or the platform's [AccessibilityFeatures.disableAnimations] is `true`.
class ReducedMotion {
  /// Returns `true` if animations should be suppressed in [context].
  static bool of(BuildContext context) {
    final mq = MediaQuery.maybeOf(context);
    final mqDisable = mq?.disableAnimations ?? false;
    final a11yDisable = SchedulerBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    return mqDisable || a11yDisable;
  }
}

/// Maps an overall animation progress value to a per-segment staggered value.
///
/// Given `count` segments and a [delayFraction] spread, each segment
/// receives a 0 → 1 value that starts after a proportional delay so that
/// later segments begin visually after earlier ones.
class Stagger {
  /// Returns the local 0 → 1 progress for the segment at [index].
  ///
  /// - [count]: total number of segments.
  /// - [delayFraction]: how much of the total timeline is used for stagger
  ///   spread (0 = all segments animate simultaneously, 1 = maximum stagger).
  /// - [progress01]: the global animation progress in `[0, 1]`.
  static double interval01({
    required int index,
    required int count,
    required double delayFraction,
    required double progress01,
  }) {
    if (count <= 1) return progress01.clamp(0, 1);
    final start = (index * delayFraction).clamp(0.0, 1.0);
    final end = (start + (1.0 - delayFraction)).clamp(0.0, 1.0);
    if (progress01 <= start) return 0;
    if (progress01 >= end) return 1;
    final v = (progress01 - start) / (end - start);
    return v.clamp(0, 1);
  }
}

/// A widget that fires [onStart] according to the [MotionTrigger] strategy.
///
/// Wrap animation widgets with this to decouple trigger logic from rendering.
class MotionTriggerWrapper extends StatefulWidget {
  const MotionTriggerWrapper({
    super.key,
    required this.trigger,
    required this.child,
    required this.onStart,
    this.visibleThreshold = 0.15,
    this.enabled = true,
  });

  /// The trigger strategy that determines when [onStart] is called.
  final MotionTrigger trigger;

  /// The widget subtree to animate. Wrapped in a [VisibilityDetector] when
  /// [trigger] is [MotionTrigger.onVisible].
  final Widget child;

  /// Called once when the trigger condition is met.
  final VoidCallback onStart;

  /// Minimum visible fraction (0 – 1) required to fire [onStart] when using
  /// [MotionTrigger.onVisible]. Defaults to `0.15`.
  final double visibleThreshold;

  /// When `false` the trigger is permanently disabled and [onStart] is never
  /// called. Useful for passing [ReducedMotion.of] directly.
  final bool enabled;

  @override
  State<MotionTriggerWrapper> createState() => _MotionTriggerWrapperState();
}

class _MotionTriggerWrapperState extends State<MotionTriggerWrapper> {
  bool _started = false;

  void _startOnce() {
    if (_started || !widget.enabled) return;
    _started = true;
    widget.onStart();
  }

  @override
  void initState() {
    super.initState();
    if (widget.trigger == MotionTrigger.onBuild) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startOnce());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trigger != MotionTrigger.onVisible) return widget.child;

    return VisibilityDetector(
      key: widget.key ?? ValueKey(widget.child.hashCode),
      onVisibilityChanged: (info) {
        if (info.visibleFraction >= widget.visibleThreshold) _startOnce();
      },
      child: widget.child,
    );
  }
}
