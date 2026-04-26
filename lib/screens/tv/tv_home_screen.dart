import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusable_control_builder/focusable_control_builder.dart';
import '../../utils/tv_utils.dart';

class TvHomeScreen extends StatefulWidget {
  const TvHomeScreen({super.key});

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends State<TvHomeScreen> {
  final FocusNode _heroFocusNode = FocusNode(debugLabel: 'home-hero-btn');
  final List<FocusNode> _rowFocusNodes = List.generate(6, (i) => FocusNode(debugLabel: 'home-card-$i'));

  @override
  void dispose() {
    _heroFocusNode.dispose();
    for (final node in _rowFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HERO BANNER ──────────────────────────────────────────────
            _HeroBanner(focusNode: _heroFocusNode),

            const SizedBox(height: 48),

            // ── CONTINUE WATCHING ────────────────────────────────────────
            const Text(
              'Continue Watching',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 6,
                  itemBuilder: (context, index) => _HomeCard(
                    index: index,
                    focusNode: _rowFocusNodes[index],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final FocusNode focusNode;
  const _HeroBanner({required this.focusNode});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.blueGrey.withValues(alpha: 0.8),
            Colors.blueGrey.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Featured Content',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const SizedBox(
            width: 400,
            child: Text(
              'This is a description of the featured IPTV content. Experience the best streaming quality right on your Android TV.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 24),
          Focus(
            focusNode: focusNode,
            child: FocusableControlBuilder(
              autoFocus: true,
              onPressed: () {
                debugPrint('Hero Watch Pressed');
              },
              builder: (context, state) => AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                decoration: BoxDecoration(
                  color: state.isFocused || focusNode.hasFocus ? Colors.white : primary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: state.isFocused || focusNode.hasFocus ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: state.isFocused || focusNode.hasFocus
                      ? [BoxShadow(color: primary.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      color: state.isFocused || focusNode.hasFocus ? Colors.black : Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Watch Now',
                      style: TextStyle(
                        color: state.isFocused || focusNode.hasFocus ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final int index;
  final FocusNode focusNode;

  const _HomeCard({required this.index, required this.focusNode});

  @override
  Widget build(BuildContext context) {
    final colors = [
      Colors.redAccent,
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.tealAccent,
    ];

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Focus(
        focusNode: focusNode,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.arrowLeft &&
              index == 0) {
            Actions.maybeInvoke(context, const MoveToRailIntent());
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: FocusableControlBuilder(
          onPressed: () {
            debugPrint('Card $index pressed');
          },
          builder: (context, state) => AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 160,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: state.isFocused || focusNode.hasFocus ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colors[index % colors.length].withValues(alpha: 0.3),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    ),
                    child: state.isFocused || focusNode.hasFocus
                        ? Center(
                            child: Icon(
                              Icons.play_circle_fill,
                              color: Colors.white.withValues(alpha: 0.8),
                              size: 40,
                            ),
                          )
                        : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Item ${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
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
