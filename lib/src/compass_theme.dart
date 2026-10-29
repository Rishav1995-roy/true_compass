import 'package:flutter/material.dart';

/// Colors, sizes and text styles of a `CompassView`.
///
/// Every field is optional; `CompassTheme.fromColorScheme` derives a
/// complete theme from the ambient Material theme.
@immutable
class CompassTheme {
  /// Creates a theme. Defaults give a neutral light dial.
  const CompassTheme({
    this.dialColor = const Color(0xFFF7F7F9),
    this.dialGradientEdge,
    this.borderColor = const Color(0xFF2B2F3A),
    this.borderWidth = 3,
    this.tickColor = const Color(0xFF6B7280),
    this.majorTickColor = const Color(0xFF111827),
    this.northColor = const Color(0xFFE5484D),
    this.cardinalStyle,
    this.northStyle,
    this.degreeLabelStyle,
    this.needleColor = const Color(0xFFE5484D),
    this.needleTailColor = const Color(0xFF9CA3AF),
    this.hubColor = const Color(0xFF111827),
    this.targetColor = const Color(0xFF2563EB),
    this.tickCount = 72,
    this.majorTickEvery = 6,
    this.showDegreeLabels = false,
    this.degreeLabelEvery = 30,
    this.showCardinals = true,
    this.showIntercardinals = true,
    this.showNeedle = true,
    this.showShadow = true,
  });

  /// Dark variant.
  const CompassTheme.dark()
      : this(
          dialColor: const Color(0xFF1B1E27),
          dialGradientEdge: const Color(0xFF11131A),
          borderColor: const Color(0xFF8B93A7),
          tickColor: const Color(0xFF7C8499),
          majorTickColor: const Color(0xFFE5E7EB),
          northColor: const Color(0xFFFF6369),
          needleColor: const Color(0xFFFF6369),
          needleTailColor: const Color(0xFF9CA3AF),
          hubColor: const Color(0xFFE5E7EB),
          targetColor: const Color(0xFF60A5FA),
        );

  /// Derives a theme from [scheme].
  factory CompassTheme.fromColorScheme(ColorScheme scheme) => CompassTheme(
        dialColor: scheme.surface,
        dialGradientEdge: scheme.surfaceContainerHighest,
        borderColor: scheme.outline,
        tickColor: scheme.outlineVariant,
        majorTickColor: scheme.onSurface,
        northColor: scheme.error,
        needleColor: scheme.error,
        needleTailColor: scheme.outline,
        hubColor: scheme.onSurface,
        targetColor: scheme.primary,
      );

  /// Fill of the dial face (center of the gradient).
  final Color dialColor;

  /// Outer color of the radial gradient; `null` gives a flat dial.
  final Color? dialGradientEdge;

  /// Color of the outer ring.
  final Color borderColor;

  /// Width of the outer ring.
  final double borderWidth;

  /// Minor tick color.
  final Color tickColor;

  /// Major tick color.
  final Color majorTickColor;

  /// Color of the `N` label and north marker.
  final Color northColor;

  /// Style of cardinal labels (`E`, `S`, `W`); defaults to bold, sized to fit.
  final TextStyle? cardinalStyle;

  /// Style of the `N` label.
  final TextStyle? northStyle;

  /// Style of degree labels.
  final TextStyle? degreeLabelStyle;

  /// North half of the default needle.
  final Color needleColor;

  /// South half of the default needle.
  final Color needleTailColor;

  /// Center hub color.
  final Color hubColor;

  /// Color of the optional target (for example Qibla) marker.
  final Color targetColor;

  /// Number of ticks around the dial.
  final int tickCount;

  /// Every n-th tick is drawn longer.
  final int majorTickEvery;

  /// Whether degree numbers (30, 60, ...) are drawn.
  final bool showDegreeLabels;

  /// Degree label spacing in degrees.
  final int degreeLabelEvery;

  /// Whether N, E, S, W are drawn.
  final bool showCardinals;

  /// Whether NE, SE, SW, NW are drawn.
  final bool showIntercardinals;

  /// Whether the default needle is drawn. Turn off with `needleBuilder`.
  final bool showNeedle;

  /// Whether the dial casts a soft shadow.
  final bool showShadow;

  /// Copy with changes.
  CompassTheme copyWith({
    Color? dialColor,
    Color? dialGradientEdge,
    Color? borderColor,
    double? borderWidth,
    Color? tickColor,
    Color? majorTickColor,
    Color? northColor,
    TextStyle? cardinalStyle,
    TextStyle? northStyle,
    TextStyle? degreeLabelStyle,
    Color? needleColor,
    Color? needleTailColor,
    Color? hubColor,
    Color? targetColor,
    int? tickCount,
    int? majorTickEvery,
    bool? showDegreeLabels,
    int? degreeLabelEvery,
    bool? showCardinals,
    bool? showIntercardinals,
    bool? showNeedle,
    bool? showShadow,
  }) =>
      CompassTheme(
        dialColor: dialColor ?? this.dialColor,
        dialGradientEdge: dialGradientEdge ?? this.dialGradientEdge,
        borderColor: borderColor ?? this.borderColor,
        borderWidth: borderWidth ?? this.borderWidth,
        tickColor: tickColor ?? this.tickColor,
        majorTickColor: majorTickColor ?? this.majorTickColor,
        northColor: northColor ?? this.northColor,
        cardinalStyle: cardinalStyle ?? this.cardinalStyle,
        northStyle: northStyle ?? this.northStyle,
        degreeLabelStyle: degreeLabelStyle ?? this.degreeLabelStyle,
        needleColor: needleColor ?? this.needleColor,
        needleTailColor: needleTailColor ?? this.needleTailColor,
        hubColor: hubColor ?? this.hubColor,
        targetColor: targetColor ?? this.targetColor,
        tickCount: tickCount ?? this.tickCount,
        majorTickEvery: majorTickEvery ?? this.majorTickEvery,
        showDegreeLabels: showDegreeLabels ?? this.showDegreeLabels,
        degreeLabelEvery: degreeLabelEvery ?? this.degreeLabelEvery,
        showCardinals: showCardinals ?? this.showCardinals,
        showIntercardinals: showIntercardinals ?? this.showIntercardinals,
        showNeedle: showNeedle ?? this.showNeedle,
        showShadow: showShadow ?? this.showShadow,
      );
}
