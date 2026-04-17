import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/xtream_code_home_controller.dart';
import '../../widgets/common/c4_card.dart';
import '../../l10n/localization_extension.dart';
import '../../models/playlist_content_model.dart';
import '../../models/content_type.dart';
import '../../utils/navigate_by_content_type.dart';

class C4LiveGridScreen extends StatefulWidget {
  const C4LiveGridScreen({super.key});

  @override
  State<C4LiveGridScreen> createState() => _C4LiveGridScreenState();
}

class _C4LiveGridScreenState extends State<C4LiveGridScreen> {
  int _selectedCategoryIndex = 0;
  ContentItem? _focusedChannel;
  final FocusNode _gridFocusNode = FocusNode();

  @override
  void dispose() {
    _gridFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<XtreamCodeHomeController>();
    
    if (controller.liveCategories == null || controller.liveCategories!.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final categories = controller.liveCategories!;
    final selectedCategory = categories[_selectedCategoryIndex];
    final channels = selectedCategory.contentItems;

    return Row(
      children: [
        // 1. Categories Sidebar (Left)
        Container(
          width: 200,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: theme.dividerColor, width: 0.5)),
          ),
          child: ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final isSelected = _selectedCategoryIndex == index;
              return _CategoryTile(
                title: categories[index].category.categoryName,
                isSelected: isSelected,
                onTap: () => setState(() => _selectedCategoryIndex = index),
              );
            },
          ),
        ),

        // 2. Channels Grid (Middle)
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedCategory.category.categoryName,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: GridView.builder(
                    focusNode: _gridFocusNode,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 16 / 10,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: channels.length,
                    itemBuilder: (context, index) {
                      final channel = channels[index];
                      return C4Card(
                        title: channel.name,
                        imageUrl: channel.imageUrl,
                        onFocusChanged: (focused) {
                          if (focused) setState(() => _focusedChannel = channel);
                        },
                        onTap: () {
                           navigateByContentType(context, channel);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3. Info Panel (Right)
        Container(
          width: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.5),
            border: Border(left: BorderSide(color: theme.dividerColor, width: 0.5)),
          ),
          child: _focusedChannel == null
              ? const Center(child: Text('Focus a channel to see details'))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.black,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _focusedChannel!.imageUrl.isNotEmpty
                            ? Image.network(_focusedChannel!.imageUrl, fit: BoxFit.contain)
                            : const Icon(Icons.live_tv, size: 48, color: Colors.white24),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _focusedChannel!.name,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'LIVE',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Program Information',
                      style: theme.textTheme.labelLarge?.copyWith(color: theme.hintColor),
                    ),
                    const SizedBox(height: 8),
                    const Text('EPG data not available for this channel.'),
                  ],
                ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Focus(
        onFocusChange: (focused) {
          if (focused) onTap();
        },
        child: Builder(
          builder: (context) {
            final focused = Focus.of(context).hasFocus;
            return GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? theme.colorScheme.primary.withOpacity(0.2) 
                      : (focused ? theme.colorScheme.surface : Colors.transparent),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected 
                        ? theme.colorScheme.primary.withOpacity(0.5) 
                        : (focused ? theme.colorScheme.primary.withOpacity(0.3) : Colors.transparent),
                  ),
                ),
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected || focused ? Colors.white : theme.hintColor,
                    fontWeight: isSelected || focused ? FontWeight.bold : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }
        ),
      ),
    );
  }
}
