import 'package:flutter/widgets.dart';

enum ScreenSize { compact, medium, expanded }

/// Which arrangement of the in-game UI fits the available space.
///
/// - [phone]: top resource bar, map, bottom navigation, floating panels.
/// - [phoneLandscape]: like phone, but navigation moves to a side rail so the
///   map keeps its height.
/// - [desktop]: dashboard on top, navigation rail, a section panel on the
///   left, the map in the middle and an inspection panel on the right.
enum GameLayoutKind {
  phone,
  phoneLandscape,
  desktop;

  static GameLayoutKind of(Size size) {
    if (size.width >= Breakpoints.gameDesktopWidth &&
        size.height >= Breakpoints.gameDesktopHeight) {
      return desktop;
    }
    if (size.width > size.height &&
        size.height < Breakpoints.landscapePhoneHeight) {
      return phoneLandscape;
    }
    return phone;
  }
}

abstract final class Breakpoints {
  static const double medium = 600;
  static const double expanded = 1024;

  /// The game screen switches to its desktop layout at this size.
  static const double gameDesktopWidth = 1000;
  static const double gameDesktopHeight = 560;

  /// Windows shorter than this (in landscape) use the landscape phone layout.
  static const double landscapePhoneHeight = 480;

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
