import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/core/widgets/arca_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Image> pumpLogo(WidgetTester tester, ThemeData theme, {Color? markColor}) async {
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    home: Scaffold(body: ArcaLogo(size: 40, showWordmark: true, markColor: markColor)),
  ));
  return tester.widget<Image>(find.byType(Image));
}

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  testWidgets('shows the church logo next to the Arca name', (tester) async {
    final image = await pumpLogo(tester, ArcaTheme.light());

    expect((image.image as AssetImage).assetName, 'assets/images/logo.png');
    expect(find.text('Arca'), findsOneWidget);
  });

  testWidgets('in light mode the logo is terracota', (tester) async {
    final image = await pumpLogo(tester, ArcaTheme.light());

    expect(image.color, const Color(0xFF974315));
    expect(image.colorBlendMode, BlendMode.srcIn);
  });

  testWidgets('in dark mode the logo is cream', (tester) async {
    final image = await pumpLogo(tester, ArcaTheme.dark());

    expect(image.color, const Color(0xFFF0EDE4));
  });

  testWidgets('a given colour wins, for coloured panels', (tester) async {
    final image = await pumpLogo(tester, ArcaTheme.light(), markColor: Colors.white);

    expect(image.color, Colors.white);
  });

  testWidgets('the Arca name sits just above the base of the drawing', (tester) async {
    await pumpLogo(tester, ArcaTheme.light());

    final imageBottom = tester.getBottomLeft(find.byType(Image)).dy;
    final text = find.text('Arca');
    final paragraph = tester.renderObject<RenderParagraph>(text);
    final painter = TextPainter(text: paragraph.text, textDirection: TextDirection.ltr)..layout();
    addTearDown(painter.dispose);
    final baseline = tester.getTopLeft(text).dy +
        painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    expect(baseline, moreOrLessEquals(imageBottom - 40 * 0.06, epsilon: 0.5));
  });
}
