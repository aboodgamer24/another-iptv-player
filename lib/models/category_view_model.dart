import 'package:c4tv_player/models/category.dart';
import 'package:c4tv_player/models/playlist_content_model.dart';

class CategoryViewModel {
  final Category category;
  final List<ContentItem> contentItems;

  CategoryViewModel({required this.category, required this.contentItems});
}
