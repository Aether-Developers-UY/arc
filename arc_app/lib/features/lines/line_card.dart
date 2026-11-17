import 'package:flutter/material.dart';

import '../../core/theme/arca_theme.dart';
import '../../core/theme/arca_tokens.dart';
import '../../core/widgets/arca_card.dart';
import 'line.dart';

/// A line in a list: its name, its songs in order and the keys they go
/// through ("G → A → D").
class LineCard extends StatelessWidget {
  const LineCard({super.key, required this.line, this.onTap});

  final Line line;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ArcaCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${line.songs.length}',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: scheme.primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  line.songs.map((s) => s.title).join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(color: context.arca.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  line.songs.map((s) => s.key).join(' → '),
                  style: ArcaTheme.mono(
                    TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LinesEmptyState extends StatelessWidget {
  const LinesEmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_music_outlined, size: 40, color: context.arca.textSecondary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.arca.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
