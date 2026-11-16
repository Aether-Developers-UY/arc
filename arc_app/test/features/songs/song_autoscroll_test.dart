import 'package:arc_app/core/screen_awake.dart';
import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/songs/song.dart';
import 'package:arc_app/features/songs/song_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records what the screen was asked to do instead of touching the device.
class FakeScreenAwake implements ScreenAwake {
  final calls = <bool>[];

  @override
  Future<void> keep(bool on) async => calls.add(on);
}

late FakeScreenAwake awake;

/// Base speed: 20 logical pixels per second at 1×.
const _base = 20.0;

final _longSong = [
  for (var i = 1; i <= 60; i++) '[G]Línea número $i de la [D]canción',
].join('\n');

Song _song({int id = 1, String? content}) => Song(
      id: id,
      title: 'Prueba',
      artist: null,
      originalKey: 'G',
      tempo: null,
      timeSignature: null,
      content: content ?? _longSong,
      notes: null,
      attachments: const [],
    );

Future<void> showSong(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  Song? song,
  Map<String, Object> stored = const {},
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(stored);
  awake = FakeScreenAwake();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [screenAwakeProvider.overrideWithValue(awake)],
      child: MaterialApp(theme: ArcaTheme.light(), home: SongDetailScreen(song: song ?? _song())),
    ),
  );
  await tester.pumpAndSettle();
}

double offset(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(of: find.byKey(const Key('song-scroll')), matching: find.byType(Scrollable)).first,
    )
    .position
    .pixels;

double maxOffset(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(of: find.byKey(const Key('song-scroll')), matching: find.byType(Scrollable)).first,
    )
    .position
    .maxScrollExtent;

Future<void> tap(WidgetTester tester, String tooltip) async {
  await tester.tap(find.byTooltip(tooltip));
  await tester.pump();
}

/// Lets [seconds] of autoscroll run in one frame. The frame that starts
/// (or resumes) the scroll counts as time zero.
Future<void> run(WidgetTester tester, double seconds) async {
  await tester.pump(Duration(milliseconds: (seconds * 1000).round()));
}

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  for (final (label, size) in [('phone', const Size(390, 844)), ('desktop', const Size(1200, 900))]) {
    testWidgets('autoscroll moves the song down ($label)', (tester) async {
      await showSong(tester, size: size);
      expect(offset(tester), 0);

      await tap(tester, 'Desplazamiento automático');
      await run(tester, 1);

      expect(offset(tester), moreOrLessEquals(_base, epsilon: 1));
      await tap(tester, 'Detener');
    });
  }

  testWidgets('pause holds the position and resume carries on', (tester) async {
    await showSong(tester);
    await tap(tester, 'Desplazamiento automático');
    await run(tester, 1);

    await tap(tester, 'Pausar');
    final paused = offset(tester);
    await run(tester, 2);
    expect(offset(tester), paused);

    await tap(tester, 'Reanudar');
    await run(tester, 1);
    expect(offset(tester), moreOrLessEquals(paused + _base, epsilon: 1));
    await tap(tester, 'Detener');
  });

  testWidgets('the speed can go up and down, and shows on the bar', (tester) async {
    await showSong(tester);
    await tap(tester, 'Desplazamiento automático');
    expect(find.text('1×'), findsOneWidget);

    await tap(tester, 'Más rápido');
    await tap(tester, 'Más rápido');
    expect(find.text('1.5×'), findsOneWidget);
    final start = offset(tester);
    await run(tester, 1);
    expect(offset(tester) - start, moreOrLessEquals(_base * 1.5, epsilon: 1));

    await tap(tester, 'Más lento');
    expect(find.text('1.25×'), findsOneWidget);
    await tap(tester, 'Detener');
  });

  testWidgets('the speed stops at its limits', (tester) async {
    await showSong(tester);
    await tap(tester, 'Desplazamiento automático');

    for (var i = 0; i < 10; i++) {
      await tap(tester, 'Más lento');
    }
    expect(find.text('0.25×'), findsOneWidget);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove)).onPressed, isNull);

    for (var i = 0; i < 20; i++) {
      await tap(tester, 'Más rápido');
    }
    expect(find.text('3×'), findsOneWidget);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add)).onPressed, isNull);
    await tap(tester, 'Detener');
  });

  testWidgets('stopping leaves the song where it is and brings back the start button', (tester) async {
    await showSong(tester);
    await tap(tester, 'Desplazamiento automático');
    await run(tester, 1);

    await tap(tester, 'Detener');
    final stopped = offset(tester);
    await run(tester, 2);

    expect(offset(tester), stopped);
    expect(find.byTooltip('Desplazamiento automático'), findsOneWidget);
    expect(find.byTooltip('Pausar'), findsNothing);
  });

  testWidgets('reaching the end pauses, and resuming starts over from the top', (tester) async {
    await showSong(tester);
    await tap(tester, 'Desplazamiento automático');
    for (var i = 0; i < 6; i++) {
      await tap(tester, 'Más rápido');
    }
    for (var i = 0; i < 120; i++) {
      await run(tester, 1);
    }

    expect(offset(tester), maxOffset(tester));
    expect(find.byTooltip('Reanudar'), findsOneWidget);

    await tap(tester, 'Reanudar');
    expect(offset(tester), 0);
    await tap(tester, 'Detener');
  });

  testWidgets('the chosen speed is remembered for that song', (tester) async {
    await showSong(tester, song: _song(id: 9));
    await tap(tester, 'Desplazamiento automático');
    await tap(tester, 'Más rápido');
    await tap(tester, 'Detener');
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('autoscroll_speed_9'), 1.25);

    await showSong(tester, song: _song(id: 9), stored: {'autoscroll_speed_9': 1.25});
    await tap(tester, 'Desplazamiento automático');
    expect(find.text('1.25×'), findsOneWidget);
    await tap(tester, 'Detener');
  });

  testWidgets('the screen stays on while autoscroll is on, paused included', (tester) async {
    await showSong(tester);
    expect(awake.calls, isEmpty);

    await tap(tester, 'Desplazamiento automático');
    expect(awake.calls, [true]);

    await tap(tester, 'Pausar');
    expect(awake.calls, [true]);

    await tap(tester, 'Detener');
    expect(awake.calls, [true, false]);
  });

  testWidgets('leaving the song lets the screen sleep again', (tester) async {
    await showSong(tester);
    await tap(tester, 'Desplazamiento automático');

    await tester.pumpWidget(const SizedBox());

    expect(awake.calls, [true, false]);
  });
}
