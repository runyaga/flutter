import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/providers/flutter_host_api.dart';
import 'package:soliplex_frontend/features/debug/debug_chart_config.dart';

void main() {
  group('createFlutterHostBundle', () {
    test('returns paired HostApi and DfRegistry', () {
      final bundle = createFlutterHostBundle(
        onChartCreated: (_, __) {},
      );

      expect(bundle.hostApi, isNotNull);
      expect(bundle.dfRegistry, isNotNull);
    });

    test('each call returns a new pair', () {
      final a = createFlutterHostBundle(onChartCreated: (_, __) {});
      final b = createFlutterHostBundle(onChartCreated: (_, __) {});

      expect(identical(a.hostApi, b.hostApi), isFalse);
      expect(identical(a.dfRegistry, b.dfRegistry), isFalse);
    });
  });

  group('FlutterHostApi', () {
    group('registerDataFrame / getDataFrame', () {
      test('round-trips column data', () {
        final bundle = createFlutterHostBundle(
          onChartCreated: (_, __) {},
        );
        final api = bundle.hostApi;

        final handle = api.registerDataFrame({
          'name': ['Alice', 'Bob'],
          'score': [92, 85],
        });

        expect(handle, isPositive);

        final columns = api.getDataFrame(handle);
        expect(columns, isNotNull);
        expect(columns!['name'], ['Alice', 'Bob']);
        expect(columns['score'], [92, 85]);
      });

      test('returns null for unknown handle', () {
        final bundle = createFlutterHostBundle(
          onChartCreated: (_, __) {},
        );

        expect(bundle.hostApi.getDataFrame(9999), isNull);
      });

      test('handles empty DataFrame', () {
        final bundle = createFlutterHostBundle(
          onChartCreated: (_, __) {},
        );
        final api = bundle.hostApi;

        final handle = api.registerDataFrame({});
        final columns = api.getDataFrame(handle);
        expect(columns, isEmpty);
      });
    });

    group('registerChart', () {
      test('fires onChartCreated callback with parsed config', () {
        int? capturedId;
        DebugChartConfig? capturedConfig;

        final bundle = createFlutterHostBundle(
          onChartCreated: (id, config) {
            capturedId = id;
            capturedConfig = config;
          },
        );

        final chartId = bundle.hostApi.registerChart({
          'type': 'scatter',
          'title': 'Test',
          'points': [
            [1, 2],
            [3, 4],
          ],
        });

        expect(chartId, isPositive);
        expect(capturedId, chartId);
        expect(capturedConfig, isA<ScatterChartConfig>());
        expect(capturedConfig!.title, 'Test');
      });

      test('returns incrementing chart IDs', () {
        final bundle = createFlutterHostBundle(
          onChartCreated: (_, __) {},
        );
        final api = bundle.hostApi;

        final id1 = api.registerChart({
          'type': 'line',
          'points': <List<num>>[],
        });
        final id2 = api.registerChart({
          'type': 'bar',
          'labels': <String>[],
          'values': <num>[],
        });

        expect(id2, greaterThan(id1));
      });

      test('throws FormatException for invalid chart config', () {
        final bundle = createFlutterHostBundle(
          onChartCreated: (_, __) {},
        );

        expect(
          () => bundle.hostApi.registerChart({'no_type': true}),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('invoke', () {
      test('throws UnimplementedError for unknown operations', () async {
        final bundle = createFlutterHostBundle(
          onChartCreated: (_, __) {},
        );

        await expectLater(
          bundle.hostApi.invoke('unknown_op', {}),
          throwsA(isA<UnimplementedError>()),
        );
      });
    });

    group('isolation', () {
      test('two instances do not share DataFrame state', () {
        final a = createFlutterHostBundle(onChartCreated: (_, __) {});
        final b = createFlutterHostBundle(onChartCreated: (_, __) {});

        final handleA = a.hostApi.registerDataFrame({
          'x': [1, 2, 3],
        });

        // Same handle number, but instance B should not have it.
        expect(b.hostApi.getDataFrame(handleA), isNull);
      });

      test('two instances do not share chart ID counters', () {
        final charts = <(String, int)>[];

        final a = createFlutterHostBundle(
          onChartCreated: (id, config) => charts.add(('a', id)),
        );
        final b = createFlutterHostBundle(
          onChartCreated: (id, config) => charts.add(('b', id)),
        );

        a.hostApi.registerChart({'type': 'line'});
        b.hostApi.registerChart(
          {'type': 'bar', 'labels': <String>[], 'values': <num>[]},
        );

        // Both start from 1 — independent counters.
        expect(charts, hasLength(2));
        expect(charts[0], ('a', 1));
        expect(charts[1], ('b', 1));
      });
    });
  });
}
