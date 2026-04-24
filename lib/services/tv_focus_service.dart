import 'package:flutter/widgets.dart';

class TvFocusService {
  TvFocusService._();
  static final TvFocusService instance = TvFocusService._();

  // section key → last focused item index
  final Map<String, int> _focusMemory = {};
  // section key → FocusNode list
  final Map<String, List<FocusNode>> _nodes = {};

  int getLastIndex(String section) => _focusMemory[section] ?? 0;

  void saveIndex(String section, int index) {
    _focusMemory[section] = index;
  }

  List<FocusNode> getNodes(String section, int count) {
    if (_nodes[section] == null || _nodes[section]!.length != count) {
      _nodes[section]?.forEach((n) => n.dispose());
      _nodes[section] = List.generate(count, (_) => FocusNode());
    }
    return _nodes[section]!;
  }

  void dispose(String section) {
    _nodes[section]?.forEach((n) => n.dispose());
    _nodes.remove(section);
    _focusMemory.remove(section);
  }
}
