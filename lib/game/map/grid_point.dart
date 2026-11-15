/// Integer coordinate of a tile on the map grid.
///
/// [col] increases towards the lower-right of the screen and [row] towards
/// the lower-left, so (0, 0) is the top corner of the diamond.
class GridPoint {
  const GridPoint(this.col, this.row);

  final int col;
  final int row;

  GridPoint translate(int dCol, int dRow) => GridPoint(col + dCol, row + dRow);

  @override
  bool operator ==(Object other) =>
      other is GridPoint && other.col == col && other.row == row;

  @override
  int get hashCode => Object.hash(col, row);

  @override
  String toString() => 'GridPoint($col, $row)';
}
