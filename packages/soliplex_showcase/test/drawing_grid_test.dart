import 'package:soliplex_showcase/soliplex_showcase.dart';
import 'package:test/test.dart';

void main() {
  group('DrawingGrid', () {
    late DrawingGrid grid;

    setUp(() {
      grid = DrawingGrid();
    });

    test('starts empty', () {
      for (var r = 0; r < DrawingGrid.size; r++) {
        for (var c = 0; c < DrawingGrid.size; c++) {
          expect(grid.getCell(r, c), isFalse);
        }
      }
    });

    test('setCell marks correct position', () {
      grid.setCell(5, 10);
      expect(grid.getCell(5, 10), isTrue);
      expect(grid.getCell(5, 11), isFalse);
      expect(grid.getCell(4, 10), isFalse);
    });

    test('setCell ignores out-of-bounds', () {
      grid
        ..setCell(-1, 0)
        ..setCell(0, -1)
        ..setCell(20, 0)
        ..setCell(0, 20);
      // Should not throw and grid stays empty.
      expect(grid.getCell(0, 0), isFalse);
    });

    test('getCell returns false for out-of-bounds', () {
      expect(grid.getCell(-1, 0), isFalse);
      expect(grid.getCell(0, -1), isFalse);
      expect(grid.getCell(20, 0), isFalse);
      expect(grid.getCell(0, 20), isFalse);
    });

    test('toAscii produces expected output', () {
      grid
        ..setCell(0, 0)
        ..setCell(0, 1)
        ..setCell(1, 0);

      final ascii = grid.toAscii();
      final lines = ascii.split('\n');
      expect(lines, hasLength(DrawingGrid.size));
      expect(lines[0], startsWith('##'));
      expect(lines[1], startsWith('#.'));
      expect(lines[2], startsWith('..'));
    });

    test('clear resets grid', () {
      grid
        ..setCell(3, 3)
        ..setCell(7, 7);
      expect(grid.getCell(3, 3), isTrue);

      grid.clear();

      expect(grid.getCell(3, 3), isFalse);
      expect(grid.getCell(7, 7), isFalse);
    });
  });
}
