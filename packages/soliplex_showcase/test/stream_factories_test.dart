import 'package:soliplex_showcase/soliplex_showcase.dart';
import 'package:test/test.dart';

void main() {
  group(
    'radarMetricsStream',
    () {
      test('yields 30 items then ends', () async {
        final items = await radarMetricsStream().toList();
        expect(items, hasLength(30));
      });

      test('each item is a radar config map', () async {
        final item = await radarMetricsStream().first;
        expect(item, isA<Map<String, Object?>>());
        final map = item! as Map<String, Object?>;
        expect(map['type'], 'radar');
        expect(map['axes'], isA<List<String>>());
        expect(map['values'], isA<List<double>>());
      });
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  group(
    'marketShareStream',
    () {
      test('yields 20 items then ends', () async {
        final items = await marketShareStream().toList();
        expect(items, hasLength(20));
      });

      test('each item is a pie config map', () async {
        final item = await marketShareStream().first;
        expect(item, isA<Map<String, Object?>>());
        final map = item! as Map<String, Object?>;
        expect(map['type'], 'pie');
        expect(map['labels'], isA<List<String>>());
        expect(map['values'], isA<List<double>>());
      });
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  group(
    'serverMetricsStream',
    () {
      test('yields 30 items then ends', () async {
        final items = await serverMetricsStream().toList();
        expect(items, hasLength(30));
      });

      test('each item is a bar config map', () async {
        final item = await serverMetricsStream().first;
        expect(item, isA<Map<String, Object?>>());
        final map = item! as Map<String, Object?>;
        expect(map['type'], 'bar');
        expect(map['labels'], isA<List<String>>());
        expect(map['values'], isA<List<Object?>>());
      });
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
