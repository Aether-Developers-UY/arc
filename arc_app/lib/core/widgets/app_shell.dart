import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/annexes/annex_selector.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/setlist_detail_provider.dart';
import '../../features/setlists/setlist_list_screen.dart';
import '../../features/songs/song_list_screen.dart';
import '../layout.dart';
import '../theme/arca_tokens.dart';
import 'arca_logo.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Destination('Inicio', Icons.home_outlined, Icons.home),
  _Destination('Canciones', Icons.library_music_outlined, Icons.library_music),
  _Destination('Setlists', Icons.event_note_outlined, Icons.event_note),
];

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  void _logout() => ref.read(authProvider.notifier).logout();

  // Task 9 opens Mis anexos from here.
  void _manageAnnexes() {}

  void _select(int index) {
    setState(() => _index = index);
    // Inicio stays alive in the IndexedStack; refetch its pinned setlists
    // so edits made in the other tabs show up when coming back.
    if (index == 0) ref.invalidate(setlistDetailProvider);
  }

  @override
  Widget build(BuildContext context) {
    final body = IndexedStack(
      index: _index,
      children: [
        HomeScreen(
          onOpenSongs: () => _select(1),
          onOpenSetlists: () => _select(2),
          onChooseAnnexes: _manageAnnexes,
        ),
        const SongListScreen(),
        SetlistListScreen(onChooseAnnexes: _manageAnnexes),
      ],
    );

    if (isWide(context)) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              selectedIndex: _index,
              onSelect: _select,
              onLogout: _logout,
              userName: ref.watch(authProvider).user?.name,
              annexSelector: AnnexSelector(onManage: _manageAnnexes),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const ArcaLogo(size: 32, showWordmark: true),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnnexSelector(onManage: _manageAnnexes),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
    required this.userName,
    required this.annexSelector,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  final String? userName;
  final Widget annexSelector;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 248,
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 16),
            child: ArcaLogo(size: 40, showWordmark: true),
          ),
          annexSelector,
          const SizedBox(height: 16),
          for (var i = 0; i < _destinations.length; i++)
            _SidebarItem(
              destination: _destinations[i],
              selected: i == selectedIndex,
              onTap: () => onSelect(i),
            ),
          const Spacer(),
          const Divider(),
          const SizedBox(height: 12),
          if (userName != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                userName!,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.arca.textSecondary,
                    ),
              ),
            ),
          const SizedBox(height: 4),
          _SidebarItem(
            destination: const _Destination(
              'Cerrar sesión',
              Icons.logout,
              Icons.logout,
            ),
            selected: false,
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? scheme.primary.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(selected ? destination.selectedIcon : destination.icon,
                    color: color, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destination.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
