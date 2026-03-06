import 'dart:async';

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

    group('select', () {
      test('returns whichever stream fires first', () async {
        // Stream A fires immediately; stream B is delayed.
        registry
          ..registerFactory(
            'fast',
            () => Stream.fromIterable(['fast-event']),
          )
          ..registerFactory('slow', () async* {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            yield 'slow-event';
          });

        final hFast = registry.subscribe('fast');
        final hSlow = registry.subscribe('slow');

        final result = await registry.select([hFast, hSlow]);
        expect(result, isNotNull);
        expect(result!['handle'], hFast);
        expect(result['data'], 'fast-event');

        // Clean up remaining subscription.
        await registry.close(hSlow);
      });

      test('returns null when all streams are exhausted', () async {
        registry
          ..registerFactory('a', Stream<Object?>.empty)
          ..registerFactory('b', Stream<Object?>.empty);

        final h1 = registry.subscribe('a');
        final h2 = registry.subscribe('b');

        final result = await registry.select([h1, h2]);
        expect(result, isNull);
      });

      test('cleans up exhausted streams automatically', () async {
        // One stream has one event, the other is empty.
        registry
          ..registerFactory('has-data', () => Stream.fromIterable([42]))
          ..registerFactory('empty', Stream<Object?>.empty);

        final hData = registry.subscribe('has-data');
        final hEmpty = registry.subscribe('empty');

        final result = await registry.select([hData, hEmpty]);
        expect(result, isNotNull);
        expect(result!['handle'], hData);
        expect(result['data'], 42);

        // The empty handle should be cleaned up — next() should throw.
        expect(
          () => registry.next(hEmpty),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws on empty handles list', () async {
        expect(
          () => registry.select([]),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws on unknown handle', () async {
        expect(
          () => registry.select([999]),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('works with single handle', () async {
        registry.registerFactory(
          'solo',
          () => Stream.fromIterable(['only']),
        );

        final h = registry.subscribe('solo');
        final result = await registry.select([h]);
        expect(result, isNotNull);
        expect(result!['handle'], h);
        expect(result['data'], 'only');
      });

      test('no data loss: all events from all streams are received', () async {
        // Critical test: drain two 3-element streams exclusively via
        // select(). Peek/consume must preserve loser data — all 6
        // events must appear without any next() fallback.
        registry
          ..registerFactory(
            'x',
            () => Stream.fromIterable(['x1', 'x2', 'x3']),
          )
          ..registerFactory(
            'y',
            () => Stream.fromIterable(['y1', 'y2', 'y3']),
          );

        final hx = registry.subscribe('x');
        final hy = registry.subscribe('y');

        final collected = <String>[];
        final liveHandles = {hx, hy};

        // Drain exclusively through select(). When a stream exhausts
        // as a loser it's auto-removed; the next call with that handle
        // throws ArgumentError — prune the dead handle and retry.
        while (liveHandles.isNotEmpty) {
          try {
            final result = await registry.select(liveHandles.toList());
            if (result == null) break;
            collected.add(result['data']! as String);
          } catch (e) {
            if (e is! ArgumentError) rethrow;
            liveHandles.remove(e.invalidValue);
          }
        }

        // ALL 6 events must be present — no data loss.
        collected.sort();
        expect(collected, containsAll(['x1', 'x2', 'x3', 'y1', 'y2', 'y3']));
      });

      test('select with delayed streams picks fastest', () async {
        registry
          ..registerFactory('d50', () async* {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            yield 'fifty';
          })
          ..registerFactory('d10', () async* {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            yield 'ten';
          });

        final h50 = registry.subscribe('d50');
        final h10 = registry.subscribe('d10');

        final result = await registry.select([h50, h10]);
        expect(result, isNotNull);
        expect(result!['handle'], h10);
        expect(result['data'], 'ten');

        // Clean up.
        await registry.close(h50);
      });
    });
  });
}
