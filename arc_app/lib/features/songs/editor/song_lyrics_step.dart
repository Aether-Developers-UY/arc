import 'package:flutter/material.dart';

import 'editable_document.dart';
import 'song_lyrics_editor.dart';

/// Step 2 of the song editor: lyrics with chords, plus the indications
/// field, with the back and save actions. Holds no state of its own.
class SongLyricsStep extends StatelessWidget {
  const SongLyricsStep({
    super.key,
    required this.sections,
    required this.onSectionsChanged,
    required this.notesController,
    required this.isSaving,
    required this.errorMessage,
    required this.onBack,
    required this.onSave,
  });

  final List<EditableSection> sections;
  final ValueChanged<List<EditableSection>> onSectionsChanged;
  final TextEditingController notesController;
  final bool isSaving;
  final String? errorMessage;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Letra y acordes', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SongLyricsEditor(sections: sections, onChanged: onSectionsChanged),
        const SizedBox(height: 12),
        TextField(
          controller: notesController,
          decoration: const InputDecoration(labelText: 'Indicaciones'),
          maxLines: 3,
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
        Row(
          children: [
            OutlinedButton(onPressed: onBack, child: const Text('Atrás')),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: isSaving ? null : onSave,
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
