import 'package:flutter/material.dart';

/// Step 1 of the song editor: title, artist, key, tempo and time signature.
/// Holds no state of its own — the owning screen passes the controllers.
class SongMetadataStep extends StatelessWidget {
  const SongMetadataStep({
    super.key,
    required this.titleController,
    required this.artistController,
    required this.keyController,
    required this.tempoController,
    required this.timeSignatureController,
    required this.errorMessage,
    required this.onNext,
  });

  final TextEditingController titleController;
  final TextEditingController artistController;
  final TextEditingController keyController;
  final TextEditingController tempoController;
  final TextEditingController timeSignatureController;
  final String? errorMessage;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: titleController,
          decoration: const InputDecoration(labelText: 'Título *'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: artistController,
          decoration: const InputDecoration(labelText: 'Artista'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: keyController,
                decoration: const InputDecoration(labelText: 'Tonalidad *'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: tempoController,
                decoration: const InputDecoration(labelText: 'Tempo (BPM)'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: timeSignatureController,
          decoration: const InputDecoration(labelText: 'Compás (ej: 4/4)'),
        ),
        const SizedBox(height: 24),
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        FilledButton(onPressed: onNext, child: const Text('Siguiente')),
      ],
    );
  }
}
