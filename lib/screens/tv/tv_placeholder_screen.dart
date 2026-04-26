import 'package:flutter/material.dart';
import '../../utils/tv_utils.dart';

class TvPlaceholderScreen extends StatelessWidget {
  final String title;
  final Color  accent;
  const TvPlaceholderScreen({super.key, required this.title,
      this.accent = Colors.teal});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: const TextStyle(color: Colors.white,
            fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        const Text('← Arrow-left returns to rail',
            style: TextStyle(color: Colors.white38, fontSize: 14)),
        const SizedBox(height: 24),
        OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white54),
          onPressed: () =>
              Actions.maybeInvoke(context, const MoveToRailIntent()),
          child: const Text('Jump to Rail (test)'),
        ),
      ]),
    ),
  );
}
