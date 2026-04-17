import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class C4Header extends StatelessWidget {
  final String title;
  final List<String>? breadcrumbs;
  final VoidCallback? onSearchTap;
  final Widget? trailing;

  const C4Header({
    super.key,
    required this.title,
    this.breadcrumbs,
    this.onSearchTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerTheme.color ?? Colors.white10,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (breadcrumbs != null)
                  Row(
                    children: breadcrumbs!
                        .expand((c) => [
                              Text(c, style: theme.textTheme.labelSmall),
                              const Icon(Icons.chevron_right, size: 12),
                            ])
                        .toList()
                      ..removeLast(),
                  ),
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          if (onSearchTap != null)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: onSearchTap,
              tooltip: 'Search',
            ),

          const SizedBox(width: 16),
          // Clock
          StreamBuilder<DateTime>(
            stream: Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now()),
            initialData: DateTime.now(),
            builder: (context, snapshot) {
              final timeStr = DateFormat('HH:mm').format(snapshot.data!);
              return Text(
                timeStr,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              );
            },
          ),
          if (trailing != null) ...[
            const SizedBox(width: 16),
            trailing!,
          ],
        ],
      ),
    );
  }
}
