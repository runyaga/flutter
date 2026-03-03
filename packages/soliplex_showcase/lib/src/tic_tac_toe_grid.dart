/// A 3×3 tic-tac-toe board that tracks game state.
class TicTacToeGrid {
  /// Grid dimension.
  static const size = 3;

  /// Board cells: each is `''` (empty), `'X'`, or `'O'`.
  final List<String> _cells = List<String>.filled(9, '');

  /// Returns the value at [index] (0-8).
  String getCell(int index) => _cells[index];

  /// Places [player] at [index]. Returns `false` if occupied or
  /// out of range.
  bool play(int index, String player) {
    if (index < 0 || index > 8 || _cells[index] != '') return false;
    _cells[index] = player;
    return true;
  }

  /// Returns `'X'`, `'O'`, `'draw'`, or `''` (game in progress).
  String checkWinner() {
    const lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
      [0, 3, 6], [1, 4, 7], [2, 5, 8], // cols
      [0, 4, 8], [2, 4, 6], // diags
    ];
    for (final line in lines) {
      final a = _cells[line[0]];
      if (a != '' && a == _cells[line[1]] && a == _cells[line[2]]) {
        return a;
      }
    }
    if (_cells.every((c) => c != '')) return 'draw';
    return '';
  }

  /// Clears every cell.
  void reset() => _cells.fillRange(0, 9, '');
}
