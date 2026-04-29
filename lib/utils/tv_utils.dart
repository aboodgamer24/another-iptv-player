import 'package:flutter/material.dart';

class TvNavigation {
  /// Request focus to the TV rail (side menu).
  /// This should be called when the user navigates left from the leftmost item.
  static void requestRailFocus(BuildContext context) {
    // We look for the FocusScope that represents the rail.
    // In our TvShellScreen, we can find it by looking for a specific debug label or
    // by using a specialized FocusScopeNode if we were using a provider.
    // Since we want a decoupled way, we can use a custom Intent.
    Actions.maybeInvoke(context, const MoveToRailIntent());
  }
}

class MoveToRailIntent extends Intent {
  const MoveToRailIntent();
}
