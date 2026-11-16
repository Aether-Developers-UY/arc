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

    final style = DefaultTextStyle.of(context).style.merge(
          theme.textTheme.headlineSmall?.copyWith(
            fontSize: size * 0.5,
            color: wordmarkColor ?? theme.colorScheme.onSurface,
          ),
        );

    // "Arca" sits on the base of the drawing: bottom-align it, then drop it
    // by its descent so the letters' baseline meets the drawing's bottom.
    final painter = TextPainter(
      text: TextSpan(text: 'Arca', style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final descent = painter.height - painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    painter.dispose();

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        mark,
        SizedBox(width: size * 0.2),
        Transform.translate(
          offset: Offset(0, descent),
          child: Text('Arca', style: style),
        ),
      ],
    );
  }
}
