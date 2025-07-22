import 'package:flutter/material.dart';
import '../widgets/app_bar_actions.dart';

/// Helper class to create consistent AppBars across the application
class AppBarHelper {
  /// Creates a standard AppBar with consistent styling
  static PreferredSizeWidget createAppBar(
    BuildContext context, {
    required String title,
    List<Widget>? additionalActions,
    Widget? leading,
    PreferredSizeWidget? bottom,
    bool centerTitle = false,
    bool automaticallyImplyLeading = true,
  }) {
    return AppBar(
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      iconTheme: Theme.of(context).appBarTheme.iconTheme,
      title: Text(title, style: Theme.of(context).appBarTheme.titleTextStyle),
      centerTitle: centerTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      bottom: bottom,
      actions: [
        AppBarActions(additionalActions: additionalActions),
        const SizedBox(width: 8),
      ],
    );
  }
}
