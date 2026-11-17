import 'package:arc_app/core/external_link.dart';
import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/auth/auth_provider.dart';
import 'package:arc_app/features/setlists/setlist.dart';
import 'package:arc_app/features/setlists/setlist_detail_screen.dart';
import 'package:arc_app/features/setlists/setlist_list_provider.dart';
import 'package:arc_app/features/setlists/setlist_share.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_test_helpers.dart';

late List<Uri> opened;
late bool openSucceeds;
late List<String> copied;

Setlist _inAnnex(Setlist s) =>
    Setlist(id: s.id, serviceDate: s.serviceDate, name: s.name, songs: s.songs, annexId: testAnnex.id);

Future<void> showSetlist(WidgetTester tester, Setlist setlist) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  opened = [];
  openSucceeds = true;
  copied = [];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(StaticAuth.new),
        setlistRepositoryProvider.overrideWithValue(FakeSetlistRepository([setlist])),
        openExternalProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return openSucceeds;
        }),
      ],
      child: MaterialApp(theme: ArcaTheme.light(), home: SetlistDetailScreen(setlistId: setlist.id)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String option) async {
  await tester.tap(find.byTooltip('Compartir'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  testWidgets('WhatsApp opens with the setlist ready to send', (tester) async {
    final setlist = _inAnnex(sampleSetlist());
    await showSetlist(tester, setlist);

    await choose(tester, 'Enviar por WhatsApp');

    expect(opened, [whatsAppUri(setlistShareText(setlist, annexName: 'Anexo principal'))]);
    expect(opened.single.queryParameters['text'], contains('1. Sublime Gracia — *G*'));
  });

  testWidgets('the text can be copied to paste anywhere', (tester) async {
    final setlist = _inAnnex(sampleSetlist());
    await showSetlist(tester, setlist);

    await choose(tester, 'Copiar texto');

    expect(copied, [setlistShareText(setlist, annexName: 'Anexo principal')]);
    expect(find.text('Setlist copiado'), findsOneWidget);
    expect(opened, isEmpty);
  });

  testWidgets('if WhatsApp cannot open, it says so and offers to copy', (tester) async {
    await showSetlist(tester, _inAnnex(sampleSetlist()));
    openSucceeds = false;

    await choose(tester, 'Enviar por WhatsApp');

    expect(find.textContaining('No se pudo abrir WhatsApp'), findsOneWidget);
    await tester.tap(find.text('Copiar'));
    await tester.pump();
    expect(copied, hasLength(1));
  });

  testWidgets('a setlist from an annex the user is not in shares without the annex', (tester) async {
    final setlist = sampleSetlist();
    await showSetlist(tester, setlist);

    await choose(tester, 'Copiar texto');

    expect(copied, [setlistShareText(setlist)]);
  });

  testWidgets('an empty setlist has nothing to share', (tester) async {
    await showSetlist(tester, sampleSetlist(songs: const []));

    expect(find.byTooltip('Compartir'), findsNothing);
  });
}
