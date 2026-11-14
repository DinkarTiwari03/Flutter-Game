import 'package:flutter/widgets.dart';

enum ScreenSize { compact, medium, expanded }

abstract final class Breakpoints {
  static const double medium = 600;
  static const double expanded = 1024;

  static ScreenSize of(double width) {
    if (width >= expanded) return ScreenSize.expanded;
    if (width >= medium) return ScreenSize.medium;
    return ScreenSize.compact;
  }
}

extension ResponsiveContext on BuildContext {
  ScreenSize get screenSize => Breakpoints.of(MediaQuery.sizeOf(this).width);

  bool get isCompact => screenSize == ScreenSize.compact;

  /// Picks a value by screen size, falling back to the next smaller one.
  T responsive<T>({required T compact, T? medium, T? expanded}) {
    return switch (screenSize) {
      ScreenSize.compact => compact,
      ScreenSize.medium => medium ?? compact,
      ScreenSize.expanded => expanded ?? medium ?? compact,
    };
  }
}
