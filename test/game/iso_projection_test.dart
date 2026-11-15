
import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/map/iso_projection.dart';

void main() {
  group('IsoProjection', () {
    test('tile (0, 0) has its top corner at the world origin', () {
      expect(IsoProjection.tileTop(0, 0), Offset.zero);
      expect(IsoProjection.tileCenter(0, 0), const Offset(0, 16));
    });

    test('moving along columns goes down-right, along rows down-left', () {
      expect(IsoProjection.tileTop(1, 0), const Offset(32, 16));
      expect(IsoProjection.tileTop(0, 1), const Offset(-32, 16));
      expect(IsoProjection.tileTop(1, 1), const Offset(0, 32));
    });

    test('the center of every tile converts back to that tile', () {
      for (var r = 0; r < 20; r++) {
        for (var c = 0; c < 20; c++) {
          final center = IsoProjection.tileCenter(c, r);
          expect(IsoProjection.worldToGrid(center), GridPoint(c, r));
        }
      }
    });

    test('points just inside each corner belong to the tile', () {
      const c = 7;
      const r = 4;
      final center = IsoProjection.tileCenter(c, r);
      for (final nudge in const [
        Offset(0, -14),
        Offset(30, 0),
        Offset(0, 14),
        Offset(-30, 0),
      ]) {
        expect(
          IsoProjection.worldToGrid(center + nudge),
          const GridPoint(c, r),
        );
      }
    });

    test('points just outside the diamond belong to a neighbour', () {
      final center = IsoProjection.tileCenter(5, 5);
      expect(
        IsoProjection.worldToGrid(center + const Offset(34, 0)),
        isNot(const GridPoint(5, 5)),
      );
      expect(
        IsoProjection.worldToGrid(center + const Offset(0, 18)),
        isNot(const GridPoint(5, 5)),
      );
    });

    test('coordinates outside the map convert to negative indices', () {
      final p = IsoProjection.worldToGrid(IsoProjection.tileCenter(-3, 2));
      expect(p, const GridPoint(-3, 2));
    });

    test('tile corners are top, right, bottom, left', () {
      final corners = IsoProjection.tileCorners(0, 0);
      expect(corners, const [
        Offset(0, 0),
        Offset(32, 16),
        Offset(0, 32),
        Offset(-32, 16),
      ]);
    });

    test('map bounds contain every tile corner', () {
      const cols = 10;
      const rows = 6;
      final bounds = IsoProjection.mapBounds(cols, rows);
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          for (final corner in IsoProjection.tileCorners(c, r)) {
            expect(bounds.inflate(0.001).contains(corner), isTrue);
          }
        }
      }
    });
  });
}
