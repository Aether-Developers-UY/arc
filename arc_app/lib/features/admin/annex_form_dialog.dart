import 'package:flutter/material.dart';

/// Asks for an annex name: a new one ([current] null) or a rename.
Future<String?> showAnnexFormDialog(BuildContext context, {String? current}) =>
    showDialog<String>(context: context, builder: (_) => _AnnexFormDialog(current: current));

class _AnnexFormDialog extends StatefulWidget {
  const _AnnexFormDialog({this.current});

  final String? current;

  @override
  State<_AnnexFormDialog> createState() => _AnnexFormDialogState();
}

class _AnnexFormDialogState extends State<_AnnexFormDialog> {
  late final _name = TextEditingController(text: widget.current);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Escribí un nombre.');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final creating = widget.current == null;
    return AlertDialog(
      title: Text(creating ? 'Nuevo anexo' : 'Renombrar anexo'),
      content: SizedBox(
        width: 400,
        child: TextField(
          controller: _name,
          autofocus: true,
          decoration: InputDecoration(labelText: 'Nombre del anexo', errorText: _error),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: Text(creating ? 'Crear' : 'Guardar')),
      ],
    );
  }
}
