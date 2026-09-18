import 'package:flutter/material.dart';

class ArcaLogo extends StatelessWidget {
  const ArcaLogo({super.key, this.size = 40, this.showWordmark = false, this.wordmarkColor});

  final double size;
  final bool showWordmark;

  /// Colour of the "Arca" word; defaults to the theme's text colour.
  final Color? wordmarkColor;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ArcaMarkPainter()),
    );
    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.3),
        Text(
          'Arca',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: size * 0.6,
                color: wordmarkColor ?? Theme.of(context).colorScheme.onSurface,
              ),
        ),
      ],
    );
  }
}

class _ArcaMarkPainter extends CustomPainter {
  static const _blue = Color(0xFF1F5FA8);
  static const _gold = Color(0xFFF2B441);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 64;

    // Rounded square background.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(14 * s)),
      Paint()..color = _blue,
    );

    // Arc + note heads (the slur / rainbow).
    final arcPaint = Paint()
      ..color = _gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6 * s
      ..strokeCap = StrokeCap.round;
    final arcRect = Rect.fromCircle(center: Offset(32 * s, 36 * s), radius: 19 * s);
    canvas.drawArc(arcRect, 3.14159265, 3.14159265, false, arcPaint);
    final dot = Paint()..color = _gold;
    canvas.drawCircle(Offset(13 * s, 36 * s), 3.8 * s, dot);
    canvas.drawCircle(Offset(51 * s, 36 * s), 3.8 * s, dot);

    // Ark hull.
    final hull = Path()
      ..moveTo(15 * s, 41 * s)
      ..lineTo(49 * s, 41 * s)
      ..quadraticBezierTo(46 * s, 53 * s, 39 * s, 53 * s)
      ..lineTo(25 * s, 53 * s)
      ..quadraticBezierTo(18 * s, 53 * s, 15 * s, 41 * s)
      ..close();
    canvas.drawPath(hull, Paint()..color = Colors.white);

    // Cabin on the deck.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(26 * s, 35 * s, 12 * s, 6 * s),
        Radius.circular(1.5 * s),
      ),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
