/// A simple 20×20 boolean grid for drawing input.
class DrawingGrid {
  /// Creates a blank 20×20 grid.
  DrawingGrid() : _cells = List.generate(20, (_) => List.filled(20, false));

  final List<List<bool>> _cells;

  /// Grid size (always 20).
  static const size = 20;

  /// Mark the cell at ([row], [col]) as filled.
  void setCell(int row, int col) {
    if (row >= 0 && row < size && col >= 0 && col < size) {
      _cells[row][col] = true;
    }
  }

  /// Whether the cell at ([row], [col]) is filled.
  bool getCell(int row, int col) {
    if (row >= 0 && row < size && col >= 0 && col < size) {
      return _cells[row][col];
    }
    return false;
  }

  /// Converts the grid to ASCII art: `#` for filled, `.` for empty.
  String toAscii() {
    final buf = StringBuffer();
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        buf.write(_cells[r][c] ? '#' : '.');
      }
      if (r < size - 1) buf.writeln();
    }
    return buf.toString();
  }

  /// Reset all cells to empty.
  void clear() {
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        _cells[r][c] = false;
      }
    }
  }
}
