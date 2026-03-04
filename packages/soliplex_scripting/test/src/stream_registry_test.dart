import 'package:soliplex_scripting/soliplex_scripting.dart';
import 'package:test/test.dart';

void main() {
  group('StreamRegistry', () {
    late StreamRegistry registry;

    setUp(() {
      registry = StreamRegistry();
    });

    tearDown(() async {
      await registry.dispose();
    });

    test('subscribe + next yields values then null', () async {
      registry.registerFactory('counter', () => Stream.fromIterable([1, 2, 3]));

      final handle = registry.subscribe('counter');
      expect(handle, isPositive);

      expect(await registry.next(handle), 1);
      expect(await registry.next(handle), 2);
      expect(await registry.next(handle), 3);
      expect(await registry.next(handle), isNull);
    });

    test('close cancels early', () async {
      registry.registerFactory('infinite', () async* {
        var i = 0;
        while (true) {
          yield i++;
        }
      });

      final handle = registry.subscribe('infinite');
      expect(await registry.next(handle), 0);
      expect(await registry.next(handle), 1);

      final closed = await registry.close(handle);
      expect(closed, isTrue);

      // Closing again returns false.
      final closedAgain = await registry.close(handle);
      expect(closedAgain, isFalse);
    });

    test('unknown handle throws ArgumentError', () async {
      expect(() => registry.next(999), throwsA(isA<ArgumentError>()));
    });

    test('subscribe with unknown name throws ArgumentError', () {
      expect(
        () => registry.subscribe('nonexistent'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('dispose cancels all active subscriptions', () async {
      registry
        ..registerFactory('a', () => Stream.fromIterable([1, 2, 3]))
        ..registerFactory('b', () => Stream.fromIterable([4, 5, 6]));

      final h1 = registry.subscribe('a');
      final h2 = registry.subscribe('b');

      // Pull one value from each.
      expect(await registry.next(h1), 1);
      expect(await registry.next(h2), 4);

      await registry.dispose();

      // After dispose, handles are gone.
      expect(() => registry.next(h1), throwsA(isA<ArgumentError>()));
      expect(() => registry.next(h2), throwsA(isA<ArgumentError>()));
    });

    test('multiple subscriptions to same factory are independent', () async {
      registry.registerFactory('nums', () => Stream.fromIterable([10, 20]));

      final h1 = registry.subscribe('nums');
      final h2 = registry.subscribe('nums');

      expect(await registry.next(h1), 10);
      expect(await registry.next(h2), 10);
      expect(await registry.next(h1), 20);
      expect(await registry.next(h2), 20);
    });
  });
}
