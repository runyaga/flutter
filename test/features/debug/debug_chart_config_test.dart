import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/features/debug/debug_chart_config.dart';

void main() {
  group('DebugChartConfig.fromMap', () {
    group('line chart', () {
      test('parses valid config', () {
        final config = DebugChartConfig.fromMap({
          'type': 'line',
          'title': 'My Line',
          'x_label': 'Time',
          'y_label': 'Value',
          'points': [
            [1, 2],
            [3, 4],
          ],
        });

        expect(config, isA<LineChartConfig>());
        final line = config as LineChartConfig;
        expect(line.title, 'My Line');
        expect(line.xLabel, 'Time');
        expect(line.yLabel, 'Value');
        expect(line.points, hasLength(2));
        expect(line.points[0], const math.Point<double>(1, 2));
        expect(line.points[1], const math.Point<double>(3, 4));
      });

      test('uses defaults for missing optional fields', () {
        final config = DebugChartConfig.fromMap({'type': 'line'});

        final line = config as LineChartConfig;
        expect(line.title, '');
        expect(line.xLabel, 'X');
        expect(line.yLabel, 'Y');
        expect(line.points, isEmpty);
      });
    });

    group('bar chart', () {
      test('parses valid config', () {
        final config = DebugChartConfig.fromMap({
          'type': 'bar',
          'title': 'Sales',
          'labels': ['Q1', 'Q2', 'Q3'],
          'values': [100, 200, 150],
        });

        expect(config, isA<BarChartConfig>());
        final bar = config as BarChartConfig;
        expect(bar.title, 'Sales');
        expect(bar.labels, ['Q1', 'Q2', 'Q3']);
        expect(bar.values, [100.0, 200.0, 150.0]);
      });

      test('uses defaults for missing optional fields', () {
        final config = DebugChartConfig.fromMap({'type': 'bar'});

        final bar = config as BarChartConfig;
        expect(bar.labels, isEmpty);
        expect(bar.values, isEmpty);
      });
    });

    group('scatter chart', () {
      test('parses valid config', () {
        final config = DebugChartConfig.fromMap({
          'type': 'scatter',
          'title': 'Distribution',
          'points': [
            [1.5, 2.5],
            [3.0, 4.0],
          ],
        });

        expect(config, isA<ScatterChartConfig>());
        final scatter = config as ScatterChartConfig;
        expect(scatter.title, 'Distribution');
        expect(scatter.points, hasLength(2));
        expect(scatter.points[0].x, 1.5);
        expect(scatter.points[0].y, 2.5);
      });
    });

    group('pie chart', () {
      test('parses valid config', () {
        final config = DebugChartConfig.fromMap({
          'type': 'pie',
          'title': 'Market Share',
          'labels': ['Chrome', 'Safari', 'Firefox'],
          'values': [65.0, 18.5, 6.3],
          'center_radius': 50,
        });

        expect(config, isA<PieChartConfig>());
        final pie = config as PieChartConfig;
        expect(pie.title, 'Market Share');
        expect(pie.labels, ['Chrome', 'Safari', 'Firefox']);
        expect(pie.values, [65.0, 18.5, 6.3]);
        expect(pie.centerRadius, 50.0);
      });

      test('uses defaults for missing optional fields', () {
        final config = DebugChartConfig.fromMap({'type': 'pie'});

        final pie = config as PieChartConfig;
        expect(pie.labels, isEmpty);
        expect(pie.values, isEmpty);
        expect(pie.centerRadius, 40.0);
      });
    });

    group('radar chart', () {
      test('parses valid config', () {
        final config = DebugChartConfig.fromMap({
          'type': 'radar',
          'title': 'Performance',
          'axes': ['Speed', 'Quality', 'Cost'],
          'values': [80, 90, 70],
        });

        expect(config, isA<RadarChartConfig>());
        final radar = config as RadarChartConfig;
        expect(radar.title, 'Performance');
        expect(radar.axes, ['Speed', 'Quality', 'Cost']);
        expect(radar.values, [80.0, 90.0, 70.0]);
      });
    });

    group('image config', () {
      test('parses valid config', () {
        final config = DebugChartConfig.fromMap({
          'type': 'image',
          'title': 'Test Image',
          'width': 2,
          'height': 2,
          'pixels': [
            255,
            0,
            0,
            255,
            0,
            255,
            0,
            255,
            0,
            0,
            255,
            255,
            255,
            255,
            255,
            255,
          ],
        });

        expect(config, isA<ImageConfig>());
        final img = config as ImageConfig;
        expect(img.width, 2);
        expect(img.height, 2);
        expect(img.pixels, hasLength(16));
      });
    });

    group('graph config', () {
      test('parses valid config', () {
        final config = DebugChartConfig.fromMap({
          'type': 'graph',
          'title': 'Network',
          'nodes': ['A', 'B', 'C'],
          'edges': [
            [0, 1],
            [1, 2],
          ],
          'positions': [
            [0, 0],
            [1, 0],
            [0.5, 1],
          ],
        });

        expect(config, isA<GraphConfig>());
        final graph = config as GraphConfig;
        expect(graph.nodes, ['A', 'B', 'C']);
        expect(graph.edges, [(0, 1), (1, 2)]);
        expect(graph.positions, hasLength(3));
      });
    });

    group('heatmap config', () {
      test('parses valid config', () {
        final config = DebugChartConfig.fromMap({
          'type': 'heatmap',
          'title': 'Correlation',
          'rows': 2,
          'cols': 2,
          'values': [1.0, 0.5, 0.5, 1.0],
          'row_labels': ['A', 'B'],
          'col_labels': ['A', 'B'],
        });

        expect(config, isA<HeatmapConfig>());
        final hm = config as HeatmapConfig;
        expect(hm.rows, 2);
        expect(hm.cols, 2);
        expect(hm.values, [1.0, 0.5, 0.5, 1.0]);
        expect(hm.rowLabels, ['A', 'B']);
        expect(hm.colLabels, ['A', 'B']);
      });
    });

    group('error cases', () {
      test('throws FormatException when type is missing', () {
        expect(
          () => DebugChartConfig.fromMap({'title': 'No Type'}),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException when type is not a string', () {
        expect(
          () => DebugChartConfig.fromMap({'type': 42}),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException for unknown chart type', () {
        expect(
          () => DebugChartConfig.fromMap({'type': 'unknown_type'}),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Unknown chart type'),
            ),
          ),
        );
      });
    });

    group('point parsing edge cases', () {
      test('handles null points gracefully', () {
        final config = DebugChartConfig.fromMap({
          'type': 'line',
          'points': null,
        });

        expect((config as LineChartConfig).points, isEmpty);
      });

      test('handles non-list points gracefully', () {
        final config = DebugChartConfig.fromMap({
          'type': 'scatter',
          'points': 'not a list',
        });

        expect((config as ScatterChartConfig).points, isEmpty);
      });

      test('handles malformed point entries', () {
        final config = DebugChartConfig.fromMap({
          'type': 'line',
          'points': [
            [1, 2],
            [3], // too few elements
            'not a list',
          ],
        });

        final line = config as LineChartConfig;
        expect(line.points, hasLength(3));
        expect(line.points[0], const math.Point<double>(1, 2));
        // Malformed entries default to (0, 0).
        expect(line.points[1], const math.Point<double>(0, 0));
        expect(line.points[2], const math.Point<double>(0, 0));
      });
    });
  });
}
