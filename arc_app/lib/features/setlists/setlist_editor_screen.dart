import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'setlist.dart';
import 'setlist_list_provider.dart';

class SetlistEditorScreen extends ConsumerStatefulWidget {
  const SetlistEditorScreen({super.key, this.existingSetlist});

  /// Null when creating a new setlist, non-null when editing one.
  final Setlist? existingSetlist;

  @override
  ConsumerState<SetlistEditorScreen> createState() => _SetlistEditorScreenState();
}

class _SetlistEditorScreenState extends ConsumerState<SetlistEditorScreen> {
  late DateTime _serviceDate = widget.existingSetlist?.serviceDate ?? DateTime.now();
  late final _nameController = TextEditingController(text: widget.existingSetlist?.name);

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _serviceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _serviceDate = picked);
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final setlist = Setlist(
      id: widget.existingSetlist?.id ?? 0,
      serviceDate: _serviceDate,
      name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
      songs: widget.existingSetlist?.songs ?? [],
    );

    try {
      final repository = ref.read(setlistRepositoryProvider);
      if (widget.existingSetlist == null) {
        await repository.create(setlist);
      } else {
        await repository.update(setlist);
      }
      await ref.read(setlistListProvider.notifier).refresh();
      if (mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      setState(() => _errorMessage = _messageFor(e));
    } catch (_) {
      setState(() => _errorMessage = 'No se pudo guardar el setlist.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Mirrors the pattern established in SongEditorScreen: extract a clean
  /// message from Laravel's 422 validation response instead of interpolating
  /// the raw exception.
  String _messageFor(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['errors'] is Map) {
      final errors = data['errors'] as Map;
      final firstFieldErrors = errors.values.first;
      if (firstFieldErrors is List && firstFieldErrors.isNotEmpty) {
        return firstFieldErrors.first.toString();
      }
    }
    return 'No se pudo guardar el setlist. Verificá tu conexión e intentá de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingSetlist != null;
    final dateLabel =
        '${_serviceDate.day.toString().padLeft(2, '0')}/${_serviceDate.month.toString().padLeft(2, '0')}/${_serviceDate.year}';

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Editar setlist' : 'Nuevo setlist')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha del servicio *'),
              subtitle: Text(dateLabel),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nombre (opcional)'),
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
