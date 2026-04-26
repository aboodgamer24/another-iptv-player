import 'package:flutter/material.dart';
import 'tv_browse_screen.dart';

class TvMoviesScreen extends StatelessWidget {
  const TvMoviesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TvBrowseScreen(
      title: 'Movies',
      mockCategories: const ['All', 'Action', 'Comedy', 'Drama', 'Horror', 'Sci-Fi'],
      mockItems: List.generate(12, (i) => MockContentItem(
        title: 'Movie ${i + 1}',
        color: Colors.primaries[i % Colors.primaries.length].shade900,
      )),
    );
  }
}
