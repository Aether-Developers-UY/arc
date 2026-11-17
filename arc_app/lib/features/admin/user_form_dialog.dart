import 'package:flutter/material.dart';

import 'admin_repository.dart';

/// What the admin filled in. [password] is only set when creating.
class UserFormResult {
  UserFormResult({required this.name, required this.username, required this.role, this.password});

  final String name;
  final String username;
  final String role;
  final String? password;
}

/// Create a user ([user] null) or edit one's name, username and role.
Future<UserFormResult?> showUserFormDialog(BuildContext context, {AdminUser? user}) =>
    showDialog<UserFormResult>(context: context, builder: (_) => _UserFormDialog(user: user));

class _UserFormDialog extends StatefulWidget {
  const _UserFormDialog({this.user});

  final AdminUser? user;

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  late final _name = TextEditingController(text: widget.user?.name);
  late final _username = TextEditingController(text: widget.user?.username);
  final _password = TextEditingController();
  late String _role = widget.user?.role ?? 'standard';
  String? _error;

  bool get _creating => widget.user == null;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final username = _username.text.trim();
    if (name.isEmpty || username.isEmpty) {
      setState(() => _error = 'Completá el nombre y el usuario.');
      return;
    }
    if (_creating && _password.text.length < 8) {
      setState(() => _error = 'La contraseña tiene que tener al menos 8 caracteres.');
      return;
    }
    Navigator.of(context).pop(UserFormResult(
      name: name,
      username: username,
      role: _role,
      password: _creating ? _password.text : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_creating ? 'Nuevo usuario' : 'Editar usuario'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _username,
              decoration: const InputDecoration(
                labelText: 'Usuario',
                helperText: 'Una sola palabra: letras, números, punto o guion. Con esto inicia sesión.',
                helperMaxLines: 2,
              ),
              autocorrect: false,
              enableSuggestions: false,
            ),
            if (_creating) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                decoration: const InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: const [
                DropdownMenuItem(value: 'standard', child: Text('Estándar')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (role) => setState(() => _role = role ?? _role),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: Text(_creating ? 'Crear' : 'Guardar')),
      ],
    );
  }
}

/// Asks for a new password for [name]. Returns null if cancelled.
Future<String?> showResetPasswordDialog(BuildContext context, {required String name}) =>
    showDialog<String>(context: context, builder: (_) => _ResetPasswordDialog(name: name));

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.name});

  final String name;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Restablecer contraseña de ${widget.name}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Se van a cerrar todas sus sesiones abiertas.'),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              decoration: InputDecoration(labelText: 'Nueva contraseña', errorText: _error),
              obscureText: true,
              autofocus: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (_password.text.length < 8) {
              setState(() => _error = 'Al menos 8 caracteres.');
              return;
            }
            Navigator.of(context).pop(_password.text);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
