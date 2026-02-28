import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:test/test.dart';

void main() {
  group('FakeHostApi', () {
    late FakeHostApi api;

    setUp(() {
      api = FakeHostApi();
    });

    group('registerDataFrame', () {
      test('returns incrementing handles', () {
        final h1 = api.registerDataFrame({
          'a': [1, 2],
        });
        final h2 = api.registerDataFrame({
          'b': [3, 4],
        });

        expect(h2, greaterThan(h1));
      });

      test('stores and retrieves DataFrame by handle', () {
        final columns = {
          'name': <Object?>['Alice', 'Bob'],
          'age': <Object?>[30, 25],
        };
        final handle = api.registerDataFrame(columns);

        final retrieved = api.getDataFrame(handle);
        expect(retrieved, equals(columns));
      });

      test('returns null for unknown handle', () {
        expect(api.getDataFrame(999), isNull);
      });

      test('exposes all registered DataFrames', () {
        api
          ..registerDataFrame({
            'x': [1],
          })
          ..registerDataFrame({
            'y': [2],
          });

        expect(api.dataFrames, hasLength(2));
      });
    });

    group('registerChart', () {
      test('returns incrementing handles', () {
        final h1 = api.registerChart({'type': 'line'});
        final h2 = api.registerChart({'type': 'bar'});

        expect(h2, greaterThan(h1));
      });

      test('exposes all registered charts', () {
        api.registerChart({
          'type': 'line',
          'data': [1, 2, 3],
        });

        expect(api.charts, hasLength(1));
        expect(api.charts.values.first['type'], equals('line'));
      });
    });

    group('invoke', () {
      test('throws UnimplementedError without handler', () async {
        expect(
          () => api.invoke('test.op', {}),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('delegates to handler when provided', () async {
        final api = FakeHostApi(
          invokeHandler: (name, args) async => 'result-$name',
        );

        final result = await api.invoke('native.location', {});
        expect(result, equals('result-native.location'));
      });

      test('passes args to handler', () async {
        Map<String, Object?>? capturedArgs;
        final api = FakeHostApi(
          invokeHandler: (name, args) async {
            capturedArgs = args;
            return null;
          },
        );

        await api.invoke('test', {'key': 'value'});
        expect(capturedArgs, equals({'key': 'value'}));
      });
    });

    group('handle numbering', () {
      test('DataFrames and charts share the handle counter', () {
        final dfHandle = api.registerDataFrame({
          'a': [1],
        });
        final chartHandle = api.registerChart({'type': 'bar'});

        expect(chartHandle, equals(dfHandle + 1));
      });
    });
  });
}
