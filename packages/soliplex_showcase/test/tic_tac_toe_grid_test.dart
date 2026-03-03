import 'package:soliplex_showcase/soliplex_showcase.dart';
import 'package:test/test.dart';

void main() {
  group('TicTacToeGrid', () {
    late TicTacToeGrid grid;

    setUp(() => grid = TicTacToeGrid());

    test('starts empty with no winner', () {
      for (var i = 0; i < 9; i++) {
        expect(grid.getCell(i), '');
      }
      expect(grid.checkWinner(), '');
    });

    test('play marks cell correctly', () {
      expect(grid.play(4, 'X'), isTrue);
      expect(grid.getCell(4), 'X');
    });

    test('play on occupied cell returns false', () {
      grid.play(0, 'X');
      expect(grid.play(0, 'O'), isFalse);
      expect(grid.getCell(0), 'X');
    });

    test('play out of range returns false', () {
      expect(grid.play(-1, 'X'), isFalse);
      expect(grid.play(9, 'X'), isFalse);
    });

    test('detects horizontal win', () {
      grid
        ..play(0, 'X')
        ..play(1, 'X')
        ..play(2, 'X');
      expect(grid.checkWinner(), 'X');
    });

    test('detects vertical win', () {
      grid
        ..play(1, 'O')
        ..play(4, 'O')
        ..play(7, 'O');
      expect(grid.checkWinner(), 'O');
    });

    test('detects diagonal win', () {
      grid
        ..play(0, 'X')
        ..play(4, 'X')
        ..play(8, 'X');
      expect(grid.checkWinner(), 'X');
    });

    test('detects anti-diagonal win', () {
      grid
        ..play(2, 'O')
        ..play(4, 'O')
        ..play(6, 'O');
      expect(grid.checkWinner(), 'O');
    });

    test('detects draw when board full with no winner', () {
      // X O X
      // X X O
      // O X O
      grid
        ..play(0, 'X')
        ..play(1, 'O')
        ..play(2, 'X')
        ..play(3, 'X')
        ..play(4, 'X')
        ..play(5, 'O')
        ..play(6, 'O')
        ..play(7, 'X')
        ..play(8, 'O');
      expect(grid.checkWinner(), 'draw');
    });

    test('reset clears board', () {
      grid
        ..play(0, 'X')
        ..play(4, 'O')
        ..reset();
      for (var i = 0; i < 9; i++) {
        expect(grid.getCell(i), '');
      }
      expect(grid.checkWinner(), '');
    });
  });
}
