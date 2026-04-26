import 'package:flutter/material.dart';
import 'tv_browse_screen.dart';

class TvSeriesScreen extends StatelessWidget {
  const TvSeriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TvBrowseScreen(
      title: 'Series',
      mockCategories: const ['All', 'Drama', 'Comedy', 'Action', 'Reality', 'Anime'],
      mockItems: List.generate(12, (i) => MockContentItem(
        title: 'Series ${i + 1}',
        color: Colors.primaries[(i + 6) % Colors.primaries.length].shade900,
      )),
    );
  }
}
