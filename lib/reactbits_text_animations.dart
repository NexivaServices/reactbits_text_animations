/// A Flutter package of 23 plug-and-play text animation widgets.
///
/// **Entry / reveal animations**
/// [SplitText], [BlurText], [ScrollRevealText], [DecryptedText],
/// [ShuffleText], [ScrambledText], [AsciiScrambleText]
///
/// **Typewriter & cursor**
/// [TextType]
///
/// **Continuous loops**
/// [CircularText], [CurvedLoop], [ShinyText], [FuzzyText],
/// [GradientText], [GlitchText], [RotatingText]
///
/// **Pointer / proximity**
/// [VariableProximityText], [TextPressure], [TextCursorTrail]
///
/// **Particle**
/// [FallingText]
///
/// **Scroll-reactive**
/// [ScrollFloatText], [ScrollVelocityText]
///
/// **Counter**
/// [CountUp]
///
/// All widgets respect [MediaQuery.disableAnimations] and the platform
/// [AccessibilityFeatures.disableAnimations] flag — when either is `true`
/// the widget renders its final static state with no animation.
library;

export 'src/core.dart';
export 'src/text_animations.dart';
