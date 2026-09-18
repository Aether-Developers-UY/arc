import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'setlist_detail_screen.dart';
import 'setlist_editor_screen.dart';
import 'setlist_list_provider.dart';

class SetlistListScreen extends ConsumerWidget {
  const SetlistListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlistsAsync = ref.watch(setlistListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Setlists')),
      body: setlistsAsync.when(
        data: (setlists) => setlists.isEmpty
            ? const Center(child: Text('No hay setlists todavía.'))
            : RefreshIndicator(
                onRefresh: () => ref.read(setlistListProvider.notifier).refresh(),
                child: ListView.builder(
                  itemCount: setlists.length,
                  itemBuilder: (context, index) {
                    final setlist = setlists[index];
                    final dateLabel =
                        '${setlist.serviceDate.day.toString().padLeft(2, '0')}/${setlist.serviceDate.month.toString().padLeft(2, '0')}/${setlist.serviceDate.year}';
                    return ListTile(
                      title: Text(setlist.name?.isNotEmpty == true ? setlist.name! : dateLabel),
                      subtitle: Text(dateLabel),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => SetlistDetailScreen(setlistId: setlist.id)),
                      ),
                    );
                  },
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error al cargar setlists: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SetlistEditorScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
