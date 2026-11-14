import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/core/utils/responsive.dart';

void main() {
  test('Breakpoints map widths to screen sizes', () {
    expect(Breakpoints.of(360), ScreenSize.compact);
    expect(Breakpoints.of(700), ScreenSize.medium);
    expect(Breakpoints.of(1280), ScreenSize.expanded);
  });
}
