import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reactbits_text_animations/reactbits_text_animations.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
      ),
      home: const DemoPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ---------------------------------------------------------------------------
// Main page
// ---------------------------------------------------------------------------

class DemoPage extends StatelessWidget {
  const DemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'reactbits_text_animations',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        surfaceTintColor: Colors.white,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          _SectionHeader('Entry Animations'),
          _AnimRow(
            name: 'SplitText',
            description: 'Words slide + fade in with stagger',
            child: SplitText(
              text: 'Split Text',
              trigger: MotionTrigger.onBuild,
            ),
          ),
          _AnimRow(
            name: 'BlurText',
            description: 'Words blur-fade in with stagger',
            child: BlurText(
              text: 'Blur Text',
              trigger: MotionTrigger.onBuild,
            ),
          ),
          _AnimRow(
            name: 'ScrollRevealText',
            description: 'Words reveal upward on visibility',
            child: ScrollRevealText(
              text: 'Scroll Reveal',
              trigger: MotionTrigger.onBuild,
            ),
          ),
          _SectionHeader('Typewriter & Scramble'),
          _AnimRow(
            name: 'TextType',
            description: 'Characters typed one-by-one with cursor',
            child: TextType(
              text: 'Text Type...',
              trigger: MotionTrigger.onBuild,
            ),
          ),
          _AnimRow(
            name: 'ShuffleText',
            description: 'Characters shuffle-lock into place',
            child: ShuffleText(
              text: 'SHUFFLE',
              trigger: MotionTrigger.onBuild,
            ),
          ),
          _AnimRow(
            name: 'DecryptedText',
            description: 'Decrypts from random chars left-to-right',
            child: DecryptedText(
              text: 'DECRYPTED',
              trigger: MotionTrigger.onBuild,
            ),
          ),
          _AnimRow(
            name: 'ScrambledText',
            description: 'Reveals chars in random order',
            child: ScrambledText(
              text: 'SCRAMBLED',
              trigger: MotionTrigger.onBuild,
            ),
          ),
          _AnimRow(
            name: 'AsciiScrambleText',
            description: 'ASCII art charset shuffle reveal',
            child: AsciiScrambleText(text: 'ASCII SCRAMBLE'),
          ),
          _SectionHeader('Continuous / Looping'),
          _AnimRow(
            name: 'ShinyText',
            description: 'Shimmer light sweeps across text',
            child: ShinyText(
              text: 'Shiny Text',
              baseColor: Color(0xFF374151),
              shineColor: Color(0xFF6366F1),
            ),
          ),
          _AnimRow(
            name: 'GradientText',
            description: 'Animated rotating gradient fill',
            child: GradientText(text: 'Gradient Text'),
          ),
          _AnimRow(
            name: 'FuzzyText',
            description: 'Blurry jitter oscillation',
            child: FuzzyText(text: 'Fuzzy Text'),
          ),
          _AnimRow(
            name: 'GlitchText',
            description: 'Periodic RGB-split glitch burst',
            child: GlitchText(text: 'GLITCH'),
          ),
          _AnimRow(
            name: 'RotatingText',
            description: 'Cross-fades through a list of strings',
            child: RotatingText(
              items: ['Rotating', 'Text', 'Widget'],
            ),
          ),
          _SectionHeader('Pointer / Proximity'),
          _AnimRow(
            name: 'VariableProximityText',
            description: 'Glyphs scale toward your cursor',
            child: VariableProximityText(text: 'Hover Over Me'),
          ),
          _AnimRow(
            name: 'TextPressure',
            description: 'Stronger scale when cursor is closer',
            child: TextPressure(text: 'Text Pressure'),
          ),
          _SectionHeader('Path & Particle'),
          _AnimRow(
            name: 'CircularText',
            description: 'Text orbits a circle continuously',
            fixedHeight: 200,
            child: CircularText(text: 'CIRCULAR TEXT • '),
          ),
          _AnimRow(
            name: 'CurvedLoop',
            description: 'Text flows along two bezier paths',
            fixedHeight: 180,
            child: CurvedLoop(
              text: 'CURVED LOOP',
              backgroundColor: Colors.black,
              stripPadding: 8,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ),
          _AnimRow(
            name: 'FallingText',
            description: 'Characters fall with gravity',
            fixedHeight: 200,
            child: FallingText(
              text: 'FALLING',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87),
            ),
          ),
          _AnimRow(
            name: 'TextCursorTrail',
            description: 'Move your cursor inside the box',
            fixedHeight: 180,
            child: TextCursorTrail(
              text: 'TRAIL',
              style: TextStyle(fontSize: 20, color: Colors.black87),
            ),
          ),
          _SectionHeader('Focus & Reveal'),
          _AnimRow(
            name: 'TrueFocus',
            description: 'A focus window sweeps across blurred text',
            child: TrueFocus(text: 'True Focus'),
          ),
          _SectionHeader('Scroll-Reactive'),
          _AnimRow(
            name: 'ScrollFloatText',
            description: 'Floats + fades proportional to scroll speed',
            child: ScrollFloatText(text: 'Scroll Float'),
          ),
          _AnimRow(
            name: 'ScrollVelocityText',
            description: 'Skews + blurs with scroll velocity',
            child: ScrollVelocityText(text: 'Scroll Velocity'),
          ),
          _SectionHeader('Counter'),
          _AnimRow(
            name: 'CountUp',
            description: 'Animates from 0 to target value',
            child: CountUp(
              from: 0,
              to: 12500,
              formatter: NumberFormat.compact(),
              trigger: MotionTrigger.onBuild,
            ),
          ),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimRow extends StatefulWidget {
  const _AnimRow({
    required this.name,
    required this.description,
    required this.child,
    this.fixedHeight,
  });

  final String name;
  final String description;
  final Widget child;
  final double? fixedHeight;

  @override
  State<_AnimRow> createState() => _AnimRowState();
}

class _AnimRowState extends State<_AnimRow> {
  bool _played = false;
  int _runKey = 0;

  void _play() => setState(() {
        _played = true;
        _runKey++;
      });

  void _replay() => setState(() => _runKey++);

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Color(0xFF111827),
    );
    const descStyle = TextStyle(
      fontSize: 11,
      color: Color(0xFF9CA3AF),
    );
    const animStyle = TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: Colors.black87,
    );

    final previewH = widget.fixedHeight ?? 80.0;

    // ── preview area ──────────────────────────────────────────────────────
    Widget previewArea;

    if (!_played) {
      // idle state – dashed border + centred play button
      previewArea = GestureDetector(
        onTap: _play,
        child: Container(
          height: previewH,
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.30),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap to preview',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // playing state – live widget + replay button overlay
      Widget animWidget = KeyedSubtree(
        key: ValueKey(_runKey),
        child: DefaultTextStyle(
          style: animStyle,
          child: widget.child,
        ),
      );

      if (widget.fixedHeight != null) {
        animWidget = SizedBox(height: widget.fixedHeight, child: animWidget);
      }

      previewArea = Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: BoxConstraints(minHeight: previewH),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Center(child: animWidget),
            ),
          ),
          // Replay button
          Positioned(
            top: 8,
            right: 8,
            child: Tooltip(
              message: 'Replay',
              child: GestureDetector(
                onTap: _replay,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFFE5E7EB), width: 1),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 1)),
                    ],
                  ),
                  child: const Icon(Icons.replay_rounded,
                      size: 15, color: Color(0xFF6B7280)),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // ── card shell ────────────────────────────────────────────────────────
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.name, style: labelStyle),
                        const SizedBox(height: 2),
                        Text(widget.description, style: descStyle),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Widget',
                      style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
              const SizedBox(height: 14),
              previewArea,
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}
