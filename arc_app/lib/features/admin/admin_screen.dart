import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/arca_tokens.dart';
import '../../core/widgets/arca_card.dart';
import '../../core/widgets/content_frame.dart';
import '../../core/widgets/page_header.dart';
import '../annexes/annex.dart';
import '../annexes/annex_repository.dart';
import '../auth/auth_provider.dart';
import 'admin_repository.dart';
import 'annex_form_dialog.dart';
import 'user_form_dialog.dart';

/// Administración: the church's users and annexes. Only shown to admins.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: ContentFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            PageHeader(title: 'Administración', subtitle: 'Usuarios y anexos de la iglesia'),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [Tab(text: 'Usuarios'), Tab(text: 'Anexos')],
            ),
            SizedBox(height: 12),
            Expanded(child: TabBarView(children: [_UsersTab(), _AnnexesTab()])),
          ],
        ),
      ),
    );
  }
}

void _showMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

Future<bool> _confirmDelete(BuildContext context, {required String title, required String body}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Borrar'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// A list that loads on open, with a button above it and a retry on error.
class _ListScaffold<T> extends StatelessWidget {
  const _ListScaffold({
    required this.items,
    required this.failed,
    required this.onRetry,
    required this.action,
    required this.emptyText,
    required this.itemBuilder,
  });

  final List<T>? items;
  final bool failed;
  final VoidCallback onRetry;
  final Widget action;
  final String emptyText;
  final Widget Function(T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    final items = this.items;
    final Widget list;
    if (failed) {
      list = Center(child: TextButton(onPressed: onRetry, child: const Text('No se pudo cargar. Reintentar')));
    } else if (items == null) {
      list = const Center(child: CircularProgressIndicator());
    } else if (items.isEmpty) {
      list = Center(child: Text(emptyText, style: TextStyle(color: context.arca.textSecondary)));
    } else {
      list = ListView.separated(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, index) => itemBuilder(items[index]),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [action, const SizedBox(height: 12), Expanded(child: list)],
    );
  }
}

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  List<AdminUser>? _users;
  bool _failed = false;

  AdminRepository get _repository => ref.read(adminRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final users = await _repository.users();
      if (mounted) setState(() => _users = users);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Runs [action]; on success reloads and optionally confirms with
  /// [done], on failure shows the server's message.
  Future<void> _run(Future<void> Function() action, {String? done}) async {
    try {
      await action();
      if (!mounted) return;
      if (done != null) _showMessage(context, done);
      await _load();
    } on AdminException catch (e) {
      if (mounted) _showMessage(context, e.message);
    }
  }

  Future<void> _create() async {
    final result = await showUserFormDialog(context);
    if (result == null) return;
    await _run(() => _repository.createUser(
          name: result.name,
          email: result.email,
          password: result.password!,
          role: result.role,
        ));
  }

  Future<void> _edit(AdminUser user) async {
    final result = await showUserFormDialog(context, user: user);
    if (result == null) return;
    await _run(() => _repository.updateUser(
          user.id,
          name: result.name,
          email: result.email,
          role: result.role,
        ));
    // Editing yourself (name, role) changes what the app shows.
    if (user.id == ref.read(authProvider).user?.id) {
      await ref.read(authProvider.notifier).refreshUser();
    }
  }

  Future<void> _resetPassword(AdminUser user) async {
    final password = await showResetPasswordDialog(context, name: user.name);
    if (password == null) return;
    await _run(
      () => _repository.updateUser(user.id, password: password),
      done: 'Contraseña actualizada. Se cerraron sus sesiones.',
    );
  }

  Future<void> _delete(AdminUser user) async {
    final confirmed = await _confirmDelete(
      context,
      title: '¿Borrar a ${user.name}?',
      body: 'Sus canciones y setlists se conservan.',
    );
    if (confirmed) await _run(() => _repository.deleteUser(user.id));
  }

  @override
  Widget build(BuildContext context) {
    return _ListScaffold<AdminUser>(
      items: _users,
      failed: _failed,
      onRetry: _load,
      emptyText: 'Todavía no hay usuarios.',
      action: FilledButton.icon(
        onPressed: _create,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Nuevo usuario'),
      ),
      itemBuilder: (user) => ArcaCard(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(user.name),
          subtitle: Text(user.email),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (user.isAdmin) const Chip(label: Text('Admin'), visualDensity: VisualDensity.compact),
              PopupMenuButton<String>(
                tooltip: 'Acciones de ${user.name}',
                onSelected: (action) => switch (action) {
                  'edit' => _edit(user),
                  'password' => _resetPassword(user),
                  _ => _delete(user),
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'password', child: Text('Restablecer contraseña')),
                  PopupMenuItem(value: 'delete', child: Text('Borrar')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnexesTab extends ConsumerStatefulWidget {
  const _AnnexesTab();

  @override
  ConsumerState<_AnnexesTab> createState() => _AnnexesTabState();
}

class _AnnexesTabState extends ConsumerState<_AnnexesTab> {
  List<Annex>? _annexes;
  bool _failed = false;

  AdminRepository get _repository => ref.read(adminRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final annexes = await ref.read(annexRepositoryProvider).list();
      if (mounted) setState(() => _annexes = annexes);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Runs [action], then reloads the list and the user's own annexes,
  /// whose names may have changed.
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await ref.read(authProvider.notifier).refreshUser();
      await _load();
    } on AdminException catch (e) {
      if (mounted) _showMessage(context, e.message);
    }
  }

  Future<void> _create() async {
    final name = await showAnnexFormDialog(context);
    if (name != null) await _run(() => _repository.createAnnex(name));
  }

  Future<void> _rename(Annex annex) async {
    final name = await showAnnexFormDialog(context, current: annex.name);
    if (name != null && name != annex.name) await _run(() => _repository.renameAnnex(annex.id, name));
  }

  Future<void> _delete(Annex annex) async {
    final confirmed = await _confirmDelete(
      context,
      title: '¿Borrar «${annex.name}»?',
      body: 'Solo se puede borrar un anexo sin setlists. Sus miembros dejan de estar en él.',
    );
    if (confirmed) await _run(() => _repository.deleteAnnex(annex.id));
  }

  @override
  Widget build(BuildContext context) {
    return _ListScaffold<Annex>(
      items: _annexes,
      failed: _failed,
      onRetry: _load,
      emptyText: 'Todavía no hay anexos.',
      action: FilledButton.icon(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo anexo'),
      ),
      itemBuilder: (annex) => ArcaCard(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(annex.name),
          trailing: PopupMenuButton<String>(
            tooltip: 'Acciones de ${annex.name}',
            onSelected: (action) => action == 'rename' ? _rename(annex) : _delete(annex),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Renombrar')),
              PopupMenuItem(value: 'delete', child: Text('Borrar')),
            ],
          ),
        ),
      ),
    );
  }
}
