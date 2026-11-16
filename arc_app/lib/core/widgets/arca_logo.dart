import 'package:flutter/material.dart';

/// The church's logo (temple, sea and bridge, shared with the cr-iglesia
/// site) with the "Arca" name beside it. The drawing is a transparent PNG
/// tinted at runtime: terracota in light mode, cream in dark mode.
class ArcaLogo extends StatelessWidget {
  const ArcaLogo({
    super.key,
    this.size = 40,
    this.showWordmark = false,
    this.wordmarkColor,
    this.markColor,
  });

  final double size;
  final bool showWordmark;

  /// Colour of the "Arca" word; defaults to the theme's text colour.
  final Color? wordmarkColor;

  /// Colour of the drawing; defaults to terracota (light) or cream (dark).
  /// Set it on coloured panels.
  final Color? markColor;

  static const _cream = Color(0xFFF0EDE4);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mark = Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      color: markColor ?? (theme.brightness == Brightness.dark ? _cream : theme.colorScheme.primary),
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Logo de la iglesia',
    );
    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.2),
        Text(
          'Arca',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: size * 0.5,
            color: wordmarkColor ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
