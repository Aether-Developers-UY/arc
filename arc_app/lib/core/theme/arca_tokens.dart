import 'package:flutter/material.dart';

/// Design tokens that don't fit Material's ColorScheme.
@immutable
class ArcaTokens extends ThemeExtension<ArcaTokens> {
  const ArcaTokens({
    required this.chord,
    required this.textSecondary,
    required this.surfaceElevated,
    required this.border,
  });

  final Color chord;
  final Color textSecondary;
  final Color surfaceElevated;
  final Color border;

  @override
  ArcaTokens copyWith({
    Color? chord,
    Color? textSecondary,
    Color? surfaceElevated,
    Color? border,
  }) =>
      ArcaTokens(
        chord: chord ?? this.chord,
        textSecondary: textSecondary ?? this.textSecondary,
        surfaceElevated: surfaceElevated ?? this.surfaceElevated,
        border: border ?? this.border,
      );

  @override
  ArcaTokens lerp(ThemeExtension<ArcaTokens>? other, double t) {
    if (other is! ArcaTokens) return this;
    return ArcaTokens(
      chord: Color.lerp(chord, other.chord, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

extension ArcaContext on BuildContext {
  ArcaTokens get arca => Theme.of(this).extension<ArcaTokens>()!;
}
