import 'package:c4tv_player/repositories/user_preferences.dart';
import 'package:flutter/material.dart';
import 'package:c4tv_player/l10n/localization_extension.dart';
import 'package:provider/provider.dart';
import '../../controllers/xtream_code_home_controller.dart';

class CategorySettingsScreen extends StatefulWidget {
  final XtreamCodeHomeController controller;
  final bool isEmbedded;

  const CategorySettingsScreen({super.key, required this.controller, this.isEmbedded = false});

  @override
  State<CategorySettingsScreen> createState() => _CategorySettingsScreenState();
}

class _CategorySettingsScreenState extends State<CategorySettingsScreen> {
  Set<String> _hiddenCategories = {};
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadHiddenCategories();
  }

  Future<void> _loadHiddenCategories() async {
    final hidden = await UserPreferences.getHiddenCategories();
    setState(() {
      _hiddenCategories = hidden.toSet();
    });
  }

  Future<void> _toggleHidden(bool isVisible, String categoryId) async {
    setState(() {
      _hasChanges = true;
      if (isVisible) {
        _hiddenCategories.remove(categoryId);
      } else {
        _hiddenCategories.add(categoryId);
      }
    });
    await UserPreferences.setHiddenCategories(_hiddenCategories.toList());
    widget.controller.refresh();
  }

  Future<void> _setAllCategoriesVisible(
    Iterable<String> ids,
    bool visible,
  ) async {
    setState(() {
      _hasChanges = true;
      if (visible) {
        _hiddenCategories.removeAll(ids);
      } else {
        _hiddenCategories.addAll(ids);
      }
    });
    await UserPreferences.setHiddenCategories(_hiddenCategories.toList());
    widget.controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final content = Consumer<XtreamCodeHomeController>(
      builder: (context, controller, _) {
        return ListView(
          padding: widget.isEmbedded ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16),
          children: [
            ListTile(
              title: Text(context.loc.live, style: const TextStyle(fontWeight: FontWeight.bold)),
              tileColor: Colors.black12,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _setAllCategoriesVisible(
                    widget.controller.liveCategories!.map(
                      (c) => c.category.categoryId,
                    ),
                    true,
                  ),
                  child: Text(context.loc.select_all),
                ),
                TextButton(
                  onPressed: () => _setAllCategoriesVisible(
                    widget.controller.liveCategories!.map(
                      (c) => c.category.categoryId,
                    ),
                    false,
                  ),
                  child: Text(context.loc.deselect_all),
                ),
              ],
            ),
            ...?controller.liveCategories?.map((cat) {
              final isHidden = _hiddenCategories.contains(
                cat.category.categoryId,
              );
              return SwitchListTile(
                title: Text(cat.category.categoryName),
                value: !isHidden,
                onChanged: (val) =>
                    _toggleHidden(val, cat.category.categoryId),
              );
            }),

            const Divider(),
            ListTile(
              title: Text(context.loc.movies, style: const TextStyle(fontWeight: FontWeight.bold)),
              tileColor: Colors.black12,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _setAllCategoriesVisible(
                    widget.controller.movieCategories.map(
                      (c) => c.category.categoryId,
                    ),
                    true,
                  ),
                  child: Text(context.loc.select_all),
                ),
                TextButton(
                  onPressed: () => _setAllCategoriesVisible(
                    widget.controller.movieCategories.map(
                      (c) => c.category.categoryId,
                    ),
                    false,
                  ),
                  child: Text(context.loc.deselect_all),
                ),
              ],
            ),
            ...controller.movieCategories.map((cat) {
              final isHidden = _hiddenCategories.contains(
                cat.category.categoryId,
              );
              return SwitchListTile(
                title: Text(cat.category.categoryName),
                value: !isHidden,
                onChanged: (val) =>
                    _toggleHidden(val, cat.category.categoryId),
              );
            }),

            const Divider(),
            ListTile(
              title: Text(context.loc.series_plural, style: const TextStyle(fontWeight: FontWeight.bold)),
              tileColor: Colors.black12,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _setAllCategoriesVisible(
                    widget.controller.seriesCategories.map(
                      (c) => c.category.categoryId,
                    ),
                    true,
                  ),
                  child: Text(context.loc.select_all),
                ),
                TextButton(
                  onPressed: () => _setAllCategoriesVisible(
                    widget.controller.seriesCategories.map(
                      (c) => c.category.categoryId,
                    ),
                    false,
                  ),
                  child: Text(context.loc.deselect_all),
                ),
              ],
            ),
            ...controller.seriesCategories.map((cat) {
              final isHidden = _hiddenCategories.contains(
                cat.category.categoryId,
              );
              return SwitchListTile(
                title: Text(cat.category.categoryName),
                value: !isHidden,
                onChanged: (val) =>
                    _toggleHidden(val, cat.category.categoryId),
              );
            }),
          ],
        );
      },
    );

    if (widget.isEmbedded) {
      return ChangeNotifierProvider.value(
        value: widget.controller,
        child: content,
      );
    }

    return ChangeNotifierProvider.value(
      value: widget.controller,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (didPop) return;
          Navigator.pop(context, _hasChanges);
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.loc.hide_category),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pop(context, _hasChanges);
              },
            ),
          ),
          body: content,
        ),
      ),
    );
  }
}
