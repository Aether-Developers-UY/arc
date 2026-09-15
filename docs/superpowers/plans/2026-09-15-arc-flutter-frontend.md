# Arc Flutter Frontend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Flutter client (mobile + web) for Arc — login, song list/search, ChordPro rendering with live key transposition, song editor, and attachments (audio/PDF upload, playback, download) — consuming the Laravel API from `docs/superpowers/plans/2026-09-15-arc-backend.md`, per `docs/superpowers/specs/2026-09-15-arc-design.md`.

**Architecture:** Single Flutter codebase targeting Android/iOS/Web. Riverpod for state management. A thin `ApiClient` (Dio) talks to the Laravel API (`http://localhost:4200/api` in dev); a Sanctum bearer token is stored via `flutter_secure_storage` (mobile) — on web, `flutter_secure_storage` falls back to browser storage automatically, no extra code needed. Key transposition is pure Dart logic with no network round-trip. The song list is cached to `shared_preferences` as JSON so the app stays usable if the connection drops mid-service.

**Tech Stack:** Flutter 3.44 / Dart 3.12, Riverpod (`flutter_riverpod`), Dio, `flutter_secure_storage`, `shared_preferences`, `file_picker`, `audioplayers`, `url_launcher`, `intl` (not required but commonly pulled by Flutter templates — ignore if absent).

---

## File Structure

- `arc_app/` — new Flutter project, lives at `C:\wamp64\www\arc\arc_app`
- `lib/main.dart` — app entrypoint, `ProviderScope`, routing
- `lib/core/api_client.dart` — Dio wrapper: base URL, auth header injection, error mapping
- `lib/core/token_storage.dart` — read/write/clear the Sanctum token
- `lib/core/chordpro/chordpro_parser.dart` — parses ChordPro text into a structured `ChordProDocument`
- `lib/core/chordpro/transposer.dart` — chromatic transposition of chord symbols
- `lib/features/auth/auth_repository.dart` — login/logout calls to the API
- `lib/features/auth/auth_provider.dart` — Riverpod state for the logged-in user/token
- `lib/features/auth/login_screen.dart` — login UI
- `lib/features/songs/song.dart` — `Song`/`Attachment` models + JSON (de)serialization
- `lib/features/songs/song_repository.dart` — CRUD + search calls to the API, plus local cache read/write
- `lib/features/songs/song_list_provider.dart` — Riverpod state for the song list/search
- `lib/features/songs/song_list_screen.dart` — list + search UI
- `lib/features/songs/song_detail_screen.dart` — renders ChordPro, key selector, attachments list
- `lib/features/songs/song_editor_screen.dart` — create/edit form
- `lib/features/attachments/attachment_repository.dart` — upload/delete calls to the API
- `lib/features/attachments/attachment_list.dart` — attachment list widget (audio player + PDF open/download row)
- `test/core/chordpro/chordpro_parser_test.dart`
- `test/core/chordpro/transposer_test.dart`

---

## Task 1: Create the Flutter project and add dependencies

**Files:**
- Create: `C:\wamp64\www\arc\arc_app\` (entire Flutter project skeleton)
- Modify: `arc_app/pubspec.yaml`

- [ ] **Step 1: Scaffold the project**

Run from `C:\wamp64\www\arc`:

```bash
flutter create --platforms=android,ios,web --org uy.aetherdevelopers arc_app
```

Expected: `arc_app/` created with `lib/main.dart`, `pubspec.yaml`, platform folders for android/ios/web.

- [ ] **Step 2: Add dependencies**

Run from `arc_app/`:

```bash
cd "C:\wamp64\www\arc\arc_app"
flutter pub add dio flutter_riverpod flutter_secure_storage shared_preferences file_picker audioplayers url_launcher
```

Expected: `pubspec.yaml` updated with these packages under `dependencies:`.

- [ ] **Step 3: Verify the default counter app still runs (web, since it's fastest to check headlessly)**

```bash
flutter pub get
flutter analyze
```

Expected: `flutter analyze` reports "No issues found!" (default template has no lint errors).

- [ ] **Step 4: Commit**

```bash
cd "C:\wamp64\www\arc"
git add arc_app
git commit -m "Scaffold Flutter app and add dependencies"
```

---

## Task 2: API client, token storage, auth repository/provider, and login screen

**Files:**
- Create: `lib/core/api_client.dart`
- Create: `lib/core/token_storage.dart`
- Create: `lib/features/auth/auth_repository.dart`
- Create: `lib/features/auth/auth_provider.dart`
- Create: `lib/features/auth/login_screen.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Token storage**

Create `lib/core/token_storage.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;
  static const _key = 'arc_auth_token';

  Future<String?> read() => _storage.read(key: _key);

  Future<void> write(String token) => _storage.write(key: _key, value: token);

  Future<void> clear() => _storage.delete(key: _key);
}
```

- [ ] **Step 2: API client**

Create `lib/core/api_client.dart`:

```dart
import 'package:dio/dio.dart';

import 'token_storage.dart';

class ApiClient {
  ApiClient(this._tokenStorage) {
    _dio = Dio(BaseOptions(baseUrl: baseUrl));
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.read();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          options.headers['Accept'] = 'application/json';
          handler.next(options);
        },
      ),
    );
  }

  static const baseUrl = 'http://localhost:4200/api';

  final TokenStorage _tokenStorage;
  late final Dio _dio;

  Dio get dio => _dio;
}
```

- [ ] **Step 3: Auth repository**

Create `lib/features/auth/auth_repository.dart`:

```dart
import 'package:dio/dio.dart';

import '../../core/api_client.dart';
import '../../core/token_storage.dart';

class AuthUser {
  AuthUser({required this.id, required this.name, required this.email});

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
      );

  final int id;
  final String name;
  final String email;
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
}

class AuthRepository {
  AuthRepository(this._apiClient, this._tokenStorage);

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<AuthUser> login({required String email, required String password}) async {
    try {
      final response = await _apiClient.dio.post('/login', data: {
        'email': email,
        'password': password,
      });
      final token = response.data['token'] as String;
      await _tokenStorage.write(token);
      return AuthUser.fromJson(response.data['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        throw AuthException('El email o la contraseña no son correctos.');
      }
      throw AuthException('No se pudo conectar con el servidor.');
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.dio.post('/logout');
    } on DioException {
      // Ignore network errors on logout — clear the local token regardless.
    }
    await _tokenStorage.clear();
  }

  Future<bool> hasStoredToken() async => (await _tokenStorage.read()) != null;
}
```

- [ ] **Step 4: Auth provider (Riverpod)**

Create `lib/features/auth/auth_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api_client.dart';
import '../../core/token_storage.dart';
import 'auth_repository.dart';

final tokenStorageProvider = Provider((ref) => TokenStorage(const FlutterSecureStorage()));

final apiClientProvider = Provider((ref) => ApiClient(ref.watch(tokenStorageProvider)));

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStorageProvider)),
);

class AuthState {
  const AuthState({this.user, this.isLoading = false, this.errorMessage});

  final AuthUser? user;
  final bool isLoading;
  final String? errorMessage;

  bool get isLoggedIn => user != null;

  AuthState copyWith({AuthUser? user, bool? isLoading, String? errorMessage}) => AuthState(
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository) : super(const AuthState());

  final AuthRepository _repository;

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _repository.login(email: email, password: password);
      state = AuthState(user: user);
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(authRepositoryProvider)),
);
```

- [ ] **Step 5: Login screen**

Create `lib/features/auth/login_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Arc')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            if (authState.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  authState.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: authState.isLoading
                  ? null
                  : () => ref.read(authProvider.notifier).login(
                        _emailController.text.trim(),
                        _passwordController.text,
                      ),
              child: authState.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Ingresar'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Wire `main.dart`**

Replace `lib/main.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';

void main() {
  runApp(const ProviderScope(child: ArcApp()));
}

class ArcApp extends ConsumerWidget {
  const ArcApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Arc',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: authState.isLoggedIn ? const _PlaceholderHome() : const LoginScreen(),
    );
  }
}

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Sesión iniciada')));
  }
}
```

`_PlaceholderHome` will be replaced by the real song list screen in Task 4 — this task only needs to prove login works end-to-end.

- [ ] **Step 7: Verify against the running backend**

The backend must be running (`http://localhost:4200`, started via `php artisan serve --port=4200` from `arc-backend/`). Create a test user if one doesn't exist yet:

```bash
cd "C:\wamp64\www\arc\arc-backend"
"/c/wamp64/bin/php/php8.3.28/php.exe" artisan tinker --execute="App\Models\User::factory()->create(['email' => 'test@arc.local', 'password' => bcrypt('password123')]);"
```

Then run the Flutter app on web (fastest to verify headlessly isn't possible for UI, but `flutter analyze` plus a manual check is the bar here):

```bash
cd "C:\wamp64\www\arc\arc_app"
flutter analyze
```

Expected: no analyzer errors. Manually confirm in a browser/emulator that entering `test@arc.local` / `password123` logs in and shows "Sesión iniciada"; wrong password shows the Spanish error message.

- [ ] **Step 8: Commit**

```bash
cd "C:\wamp64\www\arc"
git add arc_app
git commit -m "Add API client, auth flow, and login screen"
```

---

## Task 3: ChordPro parser and transposer (TDD)

**Files:**
- Create: `lib/core/chordpro/chordpro_parser.dart`
- Create: `lib/core/chordpro/transposer.dart`
- Test: `test/core/chordpro/chordpro_parser_test.dart`
- Test: `test/core/chordpro/transposer_test.dart`

This is the most critical, highest-risk logic in the app — the plan mandates TDD here specifically.

- [ ] **Step 1: Write the failing transposer tests**

Create `test/core/chordpro/transposer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:arc_app/core/chordpro/transposer.dart';

void main() {
  group('transposeChord', () {
    test('transposes a simple major chord up by semitones', () {
      expect(transposeChord('G', semitones: 2), 'A');
      expect(transposeChord('C', semitones: 1), 'C#');
    });

    test('transposes minor chords, preserving the "m" suffix', () {
      expect(transposeChord('Am', semitones: 3), 'Cm');
    });

    test('transposes chords with extensions, preserving the suffix', () {
      expect(transposeChord('G7', semitones: 2), 'A7');
      expect(transposeChord('Dsus4', semitones: 5), 'Gsus4');
      expect(transposeChord('Cmaj7', semitones: 2), 'Dmaj7');
    });

    test('wraps around the octave correctly', () {
      expect(transposeChord('B', semitones: 1), 'C');
      expect(transposeChord('C', semitones: -1), 'B');
    });

    test('handles negative transposition', () {
      expect(transposeChord('D', semitones: -2), 'C');
    });

    test('prefers flats when transposing into a flat-friendly key context', () {
      expect(transposeChord('A', semitones: 1, preferFlats: true), 'Bb');
    });

    test('prefers sharps by default', () {
      expect(transposeChord('A', semitones: 1), 'A#');
    });

    test('leaves non-chord input unchanged if unrecognized', () {
      expect(transposeChord('N.C.', semitones: 2), 'N.C.');
    });
  });

  group('semitonesBetweenKeys', () {
    test('computes the distance between two keys', () {
      expect(semitonesBetweenKeys(from: 'C', to: 'D'), 2);
      expect(semitonesBetweenKeys(from: 'G', to: 'C'), -7 % 12);
      expect(semitonesBetweenKeys(from: 'C', to: 'C'), 0);
    });
  });
}
```

- [ ] **Step 2: Run to verify failure**

```bash
cd "C:\wamp64\www\arc\arc_app"
flutter test test/core/chordpro/transposer_test.dart
```

Expected: FAIL — `transposer.dart` doesn't exist yet (compile error).

- [ ] **Step 3: Implement the transposer**

Create `lib/core/chordpro/transposer.dart`:

```dart
const _sharpScale = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
const _flatScale = ['C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'];

final _chordRootPattern = RegExp(r'^([A-G])(#|b)?');

/// Transposes a chord symbol like "G", "Am7", "F#sus4" by [semitones].
/// Returns the input unchanged if it doesn't start with a recognizable
/// note letter (e.g. "N.C." for "no chord" markers).
String transposeChord(String chord, {required int semitones, bool preferFlats = false}) {
  final match = _chordRootPattern.firstMatch(chord);
  if (match == null) return chord;

  final rootLetter = match.group(1)!;
  final accidental = match.group(2) ?? '';
  final suffix = chord.substring(match.end);

  final rootIndex = _indexOfNote('$rootLetter$accidental');
  if (rootIndex == -1) return chord;

  final newIndex = (rootIndex + semitones) % 12;
  final normalizedIndex = newIndex < 0 ? newIndex + 12 : newIndex;

  final scale = preferFlats ? _flatScale : _sharpScale;
  return '${scale[normalizedIndex]}$suffix';
}

int _indexOfNote(String note) {
  final sharpIndex = _sharpScale.indexOf(note);
  if (sharpIndex != -1) return sharpIndex;
  return _flatScale.indexOf(note);
}

/// Number of semitones (0-11) to go from key [from] to key [to].
int semitonesBetweenKeys({required String from, required String to}) {
  final fromIndex = _indexOfNote(from);
  final toIndex = _indexOfNote(to);
  if (fromIndex == -1 || toIndex == -1) return 0;
  final diff = (toIndex - fromIndex) % 12;
  return diff < 0 ? diff + 12 : diff;
}
```

- [ ] **Step 4: Run to verify pass**

```bash
flutter test test/core/chordpro/transposer_test.dart
```

Expected: all tests pass. If the "wraps around" or "negative transposition" cases fail due to Dart's `%` operator returning negative results for negative operands, fix `transposeChord`'s modulo handling to normalize (the `normalizedIndex` line above already does this — verify it actually covers the case where `rootIndex + semitones` is very negative, e.g. `-1 % 12` in Dart is `11` already since Dart's `%` on int always returns non-negative for a positive divisor — confirm by running the tests rather than assuming).

- [ ] **Step 5: Write the failing parser tests**

Create `test/core/chordpro/chordpro_parser_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:arc_app/core/chordpro/chordpro_parser.dart';

void main() {
  group('ChordProParser', () {
    test('parses plain lyric lines with inline chords', () {
      final doc = ChordProParser.parse('[G]Cantaré de tu [D]amor');

      expect(doc.lines, hasLength(1));
      expect(doc.lines.first.segments, [
        const ChordProSegment(chord: 'G', text: 'Cantaré de tu '),
        const ChordProSegment(chord: 'D', text: 'amor'),
      ]);
    });

    test('parses lines with no chords as a single text segment', () {
      final doc = ChordProParser.parse('Solo letra sin acordes');

      expect(doc.lines.first.segments, [
        const ChordProSegment(chord: null, text: 'Solo letra sin acordes'),
      ]);
    });

    test('recognizes section directives like {verse} and {chorus}', () {
      final doc = ChordProParser.parse('{verse}\n[G]Letra\n{chorus}\n[D]Otra letra');

      expect(doc.lines[0].sectionLabel, 'verse');
      expect(doc.lines[1].sectionLabel, isNull);
      expect(doc.lines[2].sectionLabel, 'chorus');
    });

    test('handles multiple chords back-to-back with no lyric between them', () {
      final doc = ChordProParser.parse('[G][D]Instrumental');

      expect(doc.lines.first.segments, [
        const ChordProSegment(chord: 'G', text: ''),
        const ChordProSegment(chord: 'D', text: 'Instrumental'),
      ]);
    });

    test('preserves blank lines', () {
      final doc = ChordProParser.parse('[G]Primera\n\n[D]Segunda');

      expect(doc.lines, hasLength(3));
      expect(doc.lines[1].segments, isEmpty);
    });
  });
}
```

- [ ] **Step 6: Run to verify failure**

```bash
flutter test test/core/chordpro/chordpro_parser_test.dart
```

Expected: FAIL — `chordpro_parser.dart` doesn't exist.

- [ ] **Step 7: Implement the parser**

Create `lib/core/chordpro/chordpro_parser.dart`:

```dart
class ChordProSegment {
  const ChordProSegment({required this.chord, required this.text});

  final String? chord;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is ChordProSegment && other.chord == chord && other.text == text;

  @override
  int get hashCode => Object.hash(chord, text);

  @override
  String toString() => 'ChordProSegment(chord: $chord, text: "$text")';
}

class ChordProLine {
  const ChordProLine({required this.segments, this.sectionLabel});

  final List<ChordProSegment> segments;
  final String? sectionLabel;
}

class ChordProDocument {
  const ChordProDocument({required this.lines});

  final List<ChordProLine> lines;
}

class ChordProParser {
  static final _directivePattern = RegExp(r'^\{(\w+)(:.*)?\}$');
  static final _chordTokenPattern = RegExp(r'\[([^\]]+)\]');

  static ChordProDocument parse(String content) {
    final rawLines = content.split('\n');
    final lines = <ChordProLine>[];
    String? currentSection;

    for (final rawLine in rawLines) {
      final directiveMatch = _directivePattern.firstMatch(rawLine.trim());
      if (directiveMatch != null) {
        final name = directiveMatch.group(1)!.toLowerCase();
        if (name == 'verse' || name == 'chorus' || name == 'bridge' || name == 'tag') {
          currentSection = name;
        }
        lines.add(ChordProLine(segments: const [], sectionLabel: currentSection));
        continue;
      }

      if (rawLine.isEmpty) {
        lines.add(const ChordProLine(segments: []));
        continue;
      }

      lines.add(ChordProLine(segments: _parseLineSegments(rawLine)));
    }

    return ChordProDocument(lines: lines);
  }

  static List<ChordProSegment> _parseLineSegments(String line) {
    final segments = <ChordProSegment>[];
    var lastEnd = 0;
    String? pendingChord;

    for (final match in _chordTokenPattern.allMatches(line)) {
      final textBefore = line.substring(lastEnd, match.start);
      if (pendingChord != null || textBefore.isNotEmpty || segments.isEmpty) {
        if (pendingChord != null || textBefore.isNotEmpty) {
          segments.add(ChordProSegment(chord: pendingChord, text: textBefore));
        }
      }
      pendingChord = match.group(1);
      lastEnd = match.end;
    }

    final remainingText = line.substring(lastEnd);
    if (pendingChord != null || remainingText.isNotEmpty) {
      segments.add(ChordProSegment(chord: pendingChord, text: remainingText));
    } else if (segments.isEmpty && remainingText.isNotEmpty) {
      segments.add(ChordProSegment(chord: null, text: remainingText));
    }

    if (segments.isEmpty && line.isNotEmpty) {
      segments.add(ChordProSegment(chord: null, text: line));
    }

    return segments;
  }
}
```

NOTE: the segment-splitting logic above is subtle (chords attach to the text that follows them, consecutive chords with no text between produce an empty-text segment). If your implementation diverges from this exact algorithm, that's fine as long as all 5 parser tests pass — the tests are the actual spec here, not this reference implementation. If you find a cleaner algorithm that passes all tests, prefer it and note the deviation in your report.

- [ ] **Step 8: Run to verify pass**

```bash
flutter test test/core/chordpro/chordpro_parser_test.dart
flutter test test/core/chordpro/transposer_test.dart
```

Expected: all tests pass in both files.

- [ ] **Step 9: Commit**

```bash
cd "C:\wamp64\www\arc"
git add arc_app
git commit -m "Add ChordPro parser and transposer with unit tests"
```

---

## Task 4: Song model, repository, list provider, and song list screen

**Files:**
- Create: `lib/features/songs/song.dart`
- Create: `lib/features/songs/song_repository.dart`
- Create: `lib/features/songs/song_list_provider.dart`
- Create: `lib/features/songs/song_list_screen.dart`
- Modify: `lib/main.dart` (point `_PlaceholderHome` replacement at the real song list)

- [ ] **Step 1: Song and Attachment models**

Create `lib/features/songs/song.dart`:

```dart
class Attachment {
  Attachment({
    required this.id,
    required this.type,
    required this.originalName,
    required this.filePath,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        id: json['id'] as int,
        type: json['type'] as String,
        originalName: json['original_name'] as String,
        filePath: json['file_path'] as String,
      );

  final int id;
  final String type; // audio | pdf | other
  final String originalName;
  final String filePath;
}

class Song {
  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.originalKey,
    required this.tempo,
    required this.timeSignature,
    required this.content,
    required this.notes,
    required this.attachments,
  });

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        id: json['id'] as int,
        title: json['title'] as String,
        artist: json['artist'] as String?,
        originalKey: json['original_key'] as String,
        tempo: json['tempo'] as int?,
        timeSignature: json['time_signature'] as String?,
        content: json['content'] as String,
        notes: json['notes'] as String?,
        attachments: (json['attachments'] as List<dynamic>? ?? [])
            .map((a) => Attachment.fromJson(a as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toRequestJson() => {
        'title': title,
        'artist': artist,
        'original_key': originalKey,
        'tempo': tempo,
        'time_signature': timeSignature,
        'content': content,
        'notes': notes,
      };

  final int id;
  final String title;
  final String? artist;
  final String originalKey;
  final int? tempo;
  final String? timeSignature;
  final String content;
  final String? notes;
  final List<Attachment> attachments;
}
```

- [ ] **Step 2: Song repository with local cache fallback**

Create `lib/features/songs/song_repository.dart`:

```dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';
import 'song.dart';

class SongRepository {
  SongRepository(this._apiClient);

  final ApiClient _apiClient;
  static const _cacheKey = 'arc_song_list_cache';

  Future<List<Song>> list({String? search}) async {
    try {
      final response = await _apiClient.dio.get('/songs', queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
      });
      final data = (response.data['data'] as List<dynamic>)
          .map((json) => Song.fromJson(json as Map<String, dynamic>))
          .toList();
      if (search == null || search.isEmpty) {
        await _cacheSongs(data);
      }
      return data;
    } catch (_) {
      if (search == null || search.isEmpty) {
        return _readCachedSongs();
      }
      rethrow;
    }
  }

  Future<Song> create(Song song) async {
    final response = await _apiClient.dio.post('/songs', data: song.toRequestJson());
    return Song.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Song> update(Song song) async {
    final response =
        await _apiClient.dio.put('/songs/${song.id}', data: song.toRequestJson());
    return Song.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> delete(int songId) => _apiClient.dio.delete('/songs/$songId');

  Future<void> _cacheSongs(List<Song> songs) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = songs.map((s) => s.toRequestJson()..['id'] = s.id).toList();
    await prefs.setString(_cacheKey, jsonEncode(jsonList));
  }

  Future<List<Song>> _readCachedSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((json) => Song.fromJson({...json as Map<String, dynamic>, 'attachments': []}))
        .toList();
  }
}
```

- [ ] **Step 3: Song list provider**

Create `lib/features/songs/song_list_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import 'song.dart';
import 'song_repository.dart';

final songRepositoryProvider =
    Provider((ref) => SongRepository(ref.watch(apiClientProvider)));

final songListProvider =
    AsyncNotifierProvider<SongListNotifier, List<Song>>(SongListNotifier.new);

class SongListNotifier extends AsyncNotifier<List<Song>> {
  @override
  Future<List<Song>> build() => ref.read(songRepositoryProvider).list();

  Future<void> search(String query) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(songRepositoryProvider).list(search: query));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(songRepositoryProvider).list());
  }
}
```

- [ ] **Step 4: Song list screen**

Create `lib/features/songs/song_list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import 'song_list_provider.dart';

class SongListScreen extends ConsumerStatefulWidget {
  const SongListScreen({super.key});

  @override
  ConsumerState<SongListScreen> createState() => _SongListScreenState();
}

class _SongListScreenState extends ConsumerState<SongListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Canciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por título o artista',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) => ref.read(songListProvider.notifier).search(value),
            ),
          ),
          Expanded(
            child: songsAsync.when(
              data: (songs) => songs.isEmpty
                  ? const Center(child: Text('No hay canciones todavía.'))
                  : RefreshIndicator(
                      onRefresh: () => ref.read(songListProvider.notifier).refresh(),
                      child: ListView.builder(
                        itemCount: songs.length,
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          return ListTile(
                            title: Text(song.title),
                            subtitle: Text(song.artist ?? ''),
                            trailing: Text(song.originalKey),
                            onTap: () {
                              // Navigation to song detail is wired in Task 5.
                            },
                          );
                        },
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error al cargar canciones: $error')),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Wire into `main.dart`**

Edit `lib/main.dart`: replace the `_PlaceholderHome` reference and class with `SongListScreen`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/songs/song_list_screen.dart';

void main() {
  runApp(const ProviderScope(child: ArcApp()));
}

class ArcApp extends ConsumerWidget {
  const ArcApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Arc',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: authState.isLoggedIn ? const SongListScreen() : const LoginScreen(),
    );
  }
}
```

Delete the now-unused `_PlaceholderHome` class entirely.

- [ ] **Step 6: Verify**

```bash
cd "C:\wamp64\www\arc\arc_app"
flutter analyze
```

Expected: no issues. Manually confirm: log in with the test user from Task 2, seed 2-3 songs via the backend (e.g. through `php artisan tinker` using `Song::factory()->count(3)->create(['created_by' => 1])`), confirm they appear in the list, confirm search filters them, confirm pull-to-refresh works, confirm logout returns to the login screen.

- [ ] **Step 7: Commit**

```bash
cd "C:\wamp64\www\arc"
git add arc_app
git commit -m "Add song model, repository, and song list screen"
```

---

## Task 5: Song detail screen with ChordPro rendering and key transposition

**Files:**
- Create: `lib/features/songs/song_detail_screen.dart`
- Modify: `lib/features/songs/song_list_screen.dart` (wire the `onTap` navigation added in Task 4)

- [ ] **Step 1: Song detail screen**

Create `lib/features/songs/song_detail_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../core/chordpro/chordpro_parser.dart';
import '../../core/chordpro/transposer.dart';
import 'song.dart';

class SongDetailScreen extends StatefulWidget {
  const SongDetailScreen({super.key, required this.song});

  final Song song;

  @override
  State<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends State<SongDetailScreen> {
  late String _currentKey = widget.song.originalKey;
  static const _availableKeys = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
  ];

  @override
  Widget build(BuildContext context) {
    final document = ChordProParser.parse(widget.song.content);
    final semitones =
        semitonesBetweenKeys(from: widget.song.originalKey, to: _currentKey);

    return Scaffold(
      appBar: AppBar(title: Text(widget.song.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('Tonalidad:'),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _currentKey,
                  items: _availableKeys
                      .map((key) => DropdownMenuItem(value: key, child: Text(key)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _currentKey = value);
                  },
                ),
                if (_currentKey != widget.song.originalKey) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => setState(() => _currentKey = widget.song.originalKey),
                    child: const Text('Restablecer'),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: document.lines.length,
              itemBuilder: (context, index) {
                final line = document.lines[index];
                if (line.sectionLabel != null && line.segments.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Text(
                      line.sectionLabel!.toUpperCase(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  );
                }
                if (line.segments.isEmpty) {
                  return const SizedBox(height: 16);
                }
                return _ChordLine(segments: line.segments, semitones: semitones);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChordLine extends StatelessWidget {
  const _ChordLine({required this.segments, required this.semitones});

  final List<ChordProSegment> segments;
  final int semitones;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        children: segments.map((segment) {
          final transposed = segment.chord == null
              ? null
              : transposeChord(segment.chord!, semitones: semitones);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transposed ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(segment.text.isEmpty ? ' ' : segment.text),
            ],
          );
        }).toList(),
      ),
    );
  }
}
```

- [ ] **Step 2: Wire navigation from the song list**

Edit `lib/features/songs/song_list_screen.dart`. Add the import:

```dart
import 'song_detail_screen.dart';
```

Replace the `onTap` body (currently a comment placeholder from Task 4) with:

```dart
onTap: () => Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => SongDetailScreen(song: song)),
),
```

- [ ] **Step 3: Verify**

```bash
cd "C:\wamp64\www\arc\arc_app"
flutter analyze
```

Expected: no issues. Manually confirm: tapping a song in the list opens the detail screen with chords rendered above the lyrics; changing the key dropdown transposes every chord instantly; "Restablecer" returns to the original key.

- [ ] **Step 4: Commit**

```bash
cd "C:\wamp64\www\arc"
git add arc_app
git commit -m "Add song detail screen with ChordPro rendering and transposition"
```

---

## Task 6: Song editor screen (create/edit)

**Files:**
- Create: `lib/features/songs/song_editor_screen.dart`
- Modify: `lib/features/songs/song_list_screen.dart` (add a floating action button to create a new song)
- Modify: `lib/features/songs/song_detail_screen.dart` (add an edit button in the AppBar)

- [ ] **Step 1: Song editor screen**

Create `lib/features/songs/song_editor_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'song.dart';
import 'song_list_provider.dart';

class SongEditorScreen extends ConsumerStatefulWidget {
  const SongEditorScreen({super.key, this.existingSong});

  /// Null when creating a new song, non-null when editing one.
  final Song? existingSong;

  @override
  ConsumerState<SongEditorScreen> createState() => _SongEditorScreenState();
}

class _SongEditorScreenState extends ConsumerState<SongEditorScreen> {
  late final _titleController = TextEditingController(text: widget.existingSong?.title);
  late final _artistController = TextEditingController(text: widget.existingSong?.artist);
  late final _keyController =
      TextEditingController(text: widget.existingSong?.originalKey ?? 'C');
  late final _tempoController =
      TextEditingController(text: widget.existingSong?.tempo?.toString());
  late final _timeSignatureController =
      TextEditingController(text: widget.existingSong?.timeSignature);
  late final _contentController = TextEditingController(text: widget.existingSong?.content);
  late final _notesController = TextEditingController(text: widget.existingSong?.notes);

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _keyController.dispose();
    _tempoController.dispose();
    _timeSignatureController.dispose();
    _contentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final song = Song(
      id: widget.existingSong?.id ?? 0,
      title: _titleController.text.trim(),
      artist: _artistController.text.trim().isEmpty ? null : _artistController.text.trim(),
      originalKey: _keyController.text.trim(),
      tempo: int.tryParse(_tempoController.text.trim()),
      timeSignature:
          _timeSignatureController.text.trim().isEmpty ? null : _timeSignatureController.text.trim(),
      content: _contentController.text,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      attachments: widget.existingSong?.attachments ?? [],
    );

    try {
      final repository = ref.read(songRepositoryProvider);
      if (widget.existingSong == null) {
        await repository.create(song);
      } else {
        await repository.update(song);
      }
      await ref.read(songListProvider.notifier).refresh();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _errorMessage = 'No se pudo guardar la canción: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingSong != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Editar canción' : 'Nueva canción')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _artistController,
              decoration: const InputDecoration(labelText: 'Artista'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _keyController,
                    decoration: const InputDecoration(labelText: 'Tonalidad *'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _tempoController,
                    decoration: const InputDecoration(labelText: 'Tempo (BPM)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _timeSignatureController,
              decoration: const InputDecoration(labelText: 'Compás (ej: 4/4)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Letra y acordes (formato ChordPro) *',
                alignLabelWithHint: true,
              ),
              maxLines: 12,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notas'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Add a "new song" FAB to the list screen**

Edit `lib/features/songs/song_list_screen.dart`. Add the import:

```dart
import 'song_editor_screen.dart';
```

Add a `floatingActionButton` to the `Scaffold`:

```dart
floatingActionButton: FloatingActionButton(
  onPressed: () => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const SongEditorScreen()),
  ),
  child: const Icon(Icons.add),
),
```

- [ ] **Step 3: Add an "edit" button to the detail screen's AppBar**

Edit `lib/features/songs/song_detail_screen.dart`. Add the import:

```dart
import 'song_editor_screen.dart';
```

Change the `AppBar` to:

```dart
appBar: AppBar(
  title: Text(widget.song.title),
  actions: [
    IconButton(
      icon: const Icon(Icons.edit),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SongEditorScreen(existingSong: widget.song)),
      ),
    ),
  ],
),
```

- [ ] **Step 4: Verify**

```bash
cd "C:\wamp64\www\arc\arc_app"
flutter analyze
```

Expected: no issues. Manually confirm: the FAB opens a blank editor that creates a new song and returns to an updated list; editing an existing song pre-fills all fields and saves changes; leaving the required title/key/content fields empty and saving shows the backend's validation error message.

- [ ] **Step 5: Commit**

```bash
cd "C:\wamp64\www\arc"
git add arc_app
git commit -m "Add song editor screen for create and edit"
```

---

## Task 7: Attachments — upload, list, audio playback, PDF open/download

**Files:**
- Create: `lib/features/attachments/attachment_repository.dart`
- Create: `lib/features/attachments/attachment_list.dart`
- Modify: `lib/features/songs/song_detail_screen.dart` (render the attachment list below the lyrics, add an "add attachment" button)

- [ ] **Step 1: Attachment repository**

Create `lib/features/attachments/attachment_repository.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/api_client.dart';
import '../songs/song.dart';

class AttachmentRepository {
  AttachmentRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<Attachment> upload({
    required int songId,
    required PlatformFile file,
    required String type,
  }) async {
    final formData = FormData.fromMap({
      'type': type,
      'file': file.bytes != null
          ? MultipartFile.fromBytes(file.bytes!, filename: file.name)
          : await MultipartFile.fromFile(file.path!, filename: file.name),
    });

    final response =
        await _apiClient.dio.post('/songs/$songId/attachments', data: formData);
    return Attachment.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> delete(int attachmentId) =>
      _apiClient.dio.delete('/attachments/$attachmentId');

  String downloadUrl(int attachmentId) =>
      '${ApiClient.baseUrl}/attachments/$attachmentId/download';
}
```

NOTE: `file.bytes` is populated on web (where raw file paths aren't accessible); `file.path` is populated on mobile/desktop. The branch above handles both — confirm this is actually how `file_picker`'s `PlatformFile` behaves on this Flutter version by checking its README/API docs if the upload test in Step 4 fails on either platform.

- [ ] **Step 2: Attachment list widget**

Create `lib/features/attachments/attachment_list.dart`:

```dart
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../songs/song.dart';
import 'attachment_repository.dart';

final attachmentRepositoryProvider =
    Provider((ref) => AttachmentRepository(ref.watch(apiClientProvider)));

class AttachmentList extends ConsumerStatefulWidget {
  const AttachmentList({super.key, required this.song, required this.onChanged});

  final Song song;

  /// Called after a successful upload or delete so the parent can refresh
  /// the song (and its attachments) from the server.
  final VoidCallback onChanged;

  @override
  ConsumerState<AttachmentList> createState() => _AttachmentListState();
}

class _AttachmentListState extends ConsumerState<AttachmentList> {
  final _player = AudioPlayer();
  bool _isUploading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final extension = file.extension?.toLowerCase();
    final type = extension == 'pdf' ? 'pdf' : 'audio';

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(attachmentRepositoryProvider).upload(
            songId: widget.song.id,
            file: file,
            type: type,
          );
      widget.onChanged();
    } catch (e) {
      setState(() => _errorMessage = 'No se pudo subir el archivo: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _delete(Attachment attachment) async {
    await ref.read(attachmentRepositoryProvider).delete(attachment.id);
    widget.onChanged();
  }

  Future<void> _openOrPlay(Attachment attachment) async {
    final repository = ref.read(attachmentRepositoryProvider);
    final url = repository.downloadUrl(attachment.id);

    if (attachment.type == 'audio') {
      await _player.play(UrlSource(url));
    } else {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Archivos adjuntos', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            IconButton(
              icon: _isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              onPressed: _isUploading ? null : _pickAndUpload,
            ),
          ],
        ),
        if (_errorMessage != null)
          Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (widget.song.attachments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Sin archivos adjuntos todavía.'),
          ),
        for (final attachment in widget.song.attachments)
          ListTile(
            leading: Icon(attachment.type == 'audio' ? Icons.audiotrack : Icons.picture_as_pdf),
            title: Text(attachment.originalName),
            onTap: () => _openOrPlay(attachment),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(attachment),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 3: Wire into the song detail screen**

Edit `lib/features/songs/song_detail_screen.dart`. This screen currently takes an immutable `widget.song` passed in from the list — to reflect attachment changes without a full app restart, convert the song into local state that can be replaced after upload/delete.

Add the import:

```dart
import '../attachments/attachment_list.dart';
```

Add a mutable field and update logic in `_SongDetailScreenState`:

```dart
late Song _song = widget.song;
```

(Replace all other uses of `widget.song` inside `build()` with `_song` — the `_currentKey` initializer should now read `_song.originalKey`.)

Add, right after the `Divider(height: 1)` in the `Column`'s children list (before the `Expanded` wrapping the lyrics `ListView.builder`), a new section for attachments — since the lyrics view is already an `Expanded` ListView, wrap the whole body in a `ListView`/`Column` structure that puts attachments below the lyrics instead: change the outer `Expanded(child: ListView.builder(...))` for lyrics to a fixed-height or flexible section, and append:

```dart
Padding(
  padding: const EdgeInsets.all(16),
  child: AttachmentList(
    song: _song,
    onChanged: () async {
      // Re-fetch the song so its attachments list reflects the change.
      // Simplest correct approach: reload via the repository using the
      // song's id, since SongRepository doesn't have a `getOne` method yet
      // — add one if needed, following the same pattern as `list()`.
    },
  ),
),
```

Since `SongRepository` (Task 4) has no single-song fetch method, add one to `lib/features/songs/song_repository.dart`:

```dart
Future<Song> getOne(int id) async {
  final response = await _apiClient.dio.get('/songs/$id');
  return Song.fromJson(response.data['data'] as Map<String, dynamic>);
}
```

Then implement the `onChanged` callback in the detail screen to actually reload:

```dart
onChanged: () async {
  final repository = ref.read(songRepositoryProvider);
  final refreshed = await repository.getOne(_song.id);
  setState(() => _song = refreshed);
},
```

This requires converting `SongDetailScreen`'s `State` class to a `ConsumerState` (it needs `ref`) — change:

```dart
class SongDetailScreen extends StatefulWidget {
```
to
```dart
class SongDetailScreen extends ConsumerStatefulWidget {
```

and

```dart
class _SongDetailScreenState extends State<SongDetailScreen> {
```
to
```dart
class _SongDetailScreenState extends ConsumerState<SongDetailScreen> {
```

adding the `flutter_riverpod` import at the top of the file, and importing `song_list_provider.dart` for `songRepositoryProvider`.

- [ ] **Step 4: Verify**

```bash
cd "C:\wamp64\www\arc\arc_app"
flutter analyze
```

Expected: no issues. Manually confirm: from a song's detail screen, tapping "+" opens a file picker restricted to mp3/wav/m4a/pdf; picking an audio file uploads it and it appears in the list; tapping an audio attachment plays it; tapping a PDF attachment opens it externally; the delete icon removes an attachment from both the list and the server (confirm via a second reload that it's gone).

- [ ] **Step 5: Commit**

```bash
cd "C:\wamp64\www\arc"
git add arc_app
git commit -m "Add attachment upload, playback, and download to song detail screen"
```

---

## Task 8: Push the frontend to the `working` branch

**Files:** none (git operation only)

- [ ] **Step 1: Confirm current branch is `working`**

```bash
cd "C:\wamp64\www\arc"
git branch --show-current
```

Expected: `working`

- [ ] **Step 2: Run the full Dart test suite one last time**

```bash
cd "C:\wamp64\www\arc\arc_app"
flutter test
```

Expected: all tests pass (transposer + parser suites at minimum).

- [ ] **Step 3: Push**

```bash
cd "C:\wamp64\www\arc"
git push origin working
```

Expected: push succeeds, all frontend commits visible on `origin/working`.
