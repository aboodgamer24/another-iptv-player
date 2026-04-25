import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/xtream_code_home_controller.dart';
import 'tv_content_grid.dart';
import 'tv_player_screen.dart';

class TvMoviesScreen extends StatefulWidget {
  const TvMoviesScreen({super.key});

  @override
  State<TvMoviesScreen> createState() => _TvMoviesScreenState();
}

class _TvMoviesScreenState extends State<TvMoviesScreen> {
  int _selectedCategoryIndex = 0;

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<XtreamCodeHomeController>(context);
    final categories = controller.movieCategories;
    if (categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final selectedCat = categories[_selectedCategoryIndex];
    final movies = controller.getMoviesByCategory(
      selectedCat.category.categoryId,
    );

    return Column(
      children: [
        // Category row at top
        SizedBox(
          height: 52,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: categories.length,
            itemBuilder: (ctx, i) {
              final cat = categories[i];
              final isSelected = i == _selectedCategoryIndex;
              return Focus(
                onFocusChange: (hasFocus) {
                  if (hasFocus) setState(() => _selectedCategoryIndex = i);
                },
                child: Builder(
                  builder: (ctx) {
                    final hasFocus = Focus.of(ctx).hasFocus;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategoryIndex = i),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected || hasFocus
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white12,
                          borderRadius: BorderRadius.circular(20),
                          border: hasFocus
                              ? Border.all(color: Colors.white, width: 1.5)
                              : null,
                        ),
                        child: Text(
                          cat.category.categoryName,
                          style: TextStyle(
                            color: isSelected || hasFocus
                                ? Colors.white
                                : Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        // Content grid
        Expanded(
          child: TvContentGrid(
            sectionKey: 'movies_${selectedCat.category.categoryId}',
            items: movies,
            crossAxisCount: 6,
            onSelect: (item, index, queue) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TvPlayerScreen(
                    contentItem: item,
                    queue: queue,
                    initialIndex: index,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
