import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/arca_tokens.dart';
import '../../core/widgets/content_frame.dart';
import '../auth/auth_provider.dart';
import 'annex.dart';
import 'annex_repository.dart';

/// Every annex of the church, with a switch to join or leave each one.
class MyAnnexesScreen extends ConsumerStatefulWidget {
  const MyAnnexesScreen({super.key});

  @override
  ConsumerState<MyAnnexesScreen> createState() => _MyAnnexesScreenState();
}

class _MyAnnexesScreenState extends ConsumerState<MyAnnexesScreen> {
  List<Annex>? _annexes;
  bool _failedToLoad = false;

  /// Membership as shown, updated before the server answers.
  final Map<int, bool> _member = {};
  final Set<int> _saving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failedToLoad = false);
    try {
      final annexes = await ref.read(annexRepositoryProvider).list();
      if (!mounted) return;
      setState(() {
        _annexes = annexes;
        _member
          ..clear()
          ..addEntries(annexes.map((a) => MapEntry(a.id, a.isMember)));
      });
    } catch (_) {
      if (mounted) setState(() => _failedToLoad = true);
    }
  }

  Future<void> _toggle(Annex annex, bool join) async {
    setState(() {
      _member[annex.id] = join;
      _saving.add(annex.id);
    });
    try {
      final repository = ref.read(annexRepositoryProvider);
      await (join ? repository.join(annex.id) : repository.leave(annex.id));
      await ref.read(authProvider.notifier).refreshUser();
    } catch (_) {
      if (!mounted) return;
      setState(() => _member[annex.id] = !join);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No se pudo actualizar el anexo.')));
    } finally {
      if (mounted) setState(() => _saving.remove(annex.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final annexes = _annexes;
    final Widget body;
    if (_failedToLoad) {
      body = Center(
        child: TextButton(onPressed: _load, child: const Text('No se pudieron cargar. Reintentar')),
      );
    } else if (annexes == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (annexes.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Todavía no hay anexos. Pedile al admin que cree uno.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.arca.textSecondary),
          ),
        ),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Elegí los anexos en los que servís. Vas a ver los setlists de esos anexos.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.arca.textSecondary,
                  ),
            ),
          ),
          for (final annex in annexes)
            SwitchListTile(
              title: Text(annex.name),
              subtitle: const Text('Soy parte'),
              value: _member[annex.id] ?? false,
              onChanged: _saving.contains(annex.id) ? null : (join) => _toggle(annex, join),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mis anexos')),
      body: ContentFrame(maxWidth: 640, child: body),
    );
  }
}
