// TEMPORARY: Chart config for debug REPL validation — remove after validation.

import 'dart:math' as math;

/// Lightweight chart configuration for the debug DataFrame REPL.
///
/// Each config holds extracted numeric data ready for rendering.
/// The extraction happens at command time; rendering is stateless.
sealed class DebugChartConfig {
  const DebugChartConfig({
    required this.title,
    required this.xLabel,
    required this.yLabel,
  });

  /// Parses a chart configuration map into the appropriate subtype.
  ///
  /// Throws [FormatException] if `type` is missing or unknown.
  static DebugChartConfig fromMap(Map<String, Object?> map) {
    final type = map['type'];
    if (type is! String) {
      throw FormatException('Chart config missing "type" field', map);
    }
    return switch (type) {
      'line' => LineChartConfig(
          title: map['title'] as String? ?? '',
          xLabel: map['x_label'] as String? ?? 'X',
          yLabel: map['y_label'] as String? ?? 'Y',
          points: _parsePoints(map['points']),
        ),
      'bar' => BarChartConfig(
          title: map['title'] as String? ?? '',
          xLabel: map['x_label'] as String? ?? 'X',
          yLabel: map['y_label'] as String? ?? 'Y',
          labels: (map['labels'] as List?)?.cast<String>() ?? [],
          values: _parseDoubles(map['values']),
        ),
      'scatter' => ScatterChartConfig(
          title: map['title'] as String? ?? '',
          xLabel: map['x_label'] as String? ?? 'X',
          yLabel: map['y_label'] as String? ?? 'Y',
          points: _parsePoints(map['points']),
        ),
      'pie' => PieChartConfig(
          title: map['title'] as String? ?? '',
          xLabel: map['x_label'] as String? ?? '',
          yLabel: map['y_label'] as String? ?? '',
          labels: (map['labels'] as List?)?.cast<String>() ?? [],
          values: _parseDoubles(map['values']),
          centerRadius: (map['center_radius'] as num?)?.toDouble() ?? 40,
        ),
      'radar' => RadarChartConfig(
          title: map['title'] as String? ?? '',
          xLabel: map['x_label'] as String? ?? '',
          yLabel: map['y_label'] as String? ?? '',
          axes: (map['axes'] as List?)?.cast<String>() ?? [],
          values: _parseDoubles(map['values']),
        ),
      'image' => ImageConfig(
          title: map['title'] as String? ?? '',
          xLabel: map['x_label'] as String? ?? '',
          yLabel: map['y_label'] as String? ?? '',
          width: (map['width'] as num?)?.toInt() ?? 0,
          height: (map['height'] as num?)?.toInt() ?? 0,
          pixels: _parseInts(map['pixels']),
        ),
      'graph' => GraphConfig(
          title: map['title'] as String? ?? '',
          xLabel: map['x_label'] as String? ?? '',
          yLabel: map['y_label'] as String? ?? '',
          nodes: (map['nodes'] as List?)?.cast<String>() ?? [],
          edges: _parseEdges(map['edges']),
          positions: _parsePoints(map['positions']),
        ),
      'heatmap' => HeatmapConfig(
          title: map['title'] as String? ?? '',
          xLabel: map['x_label'] as String? ?? '',
          yLabel: map['y_label'] as String? ?? '',
          rows: (map['rows'] as num?)?.toInt() ?? 0,
          cols: (map['cols'] as num?)?.toInt() ?? 0,
          values: _parseDoubles(map['values']),
          rowLabels: (map['row_labels'] as List?)?.cast<String>() ?? [],
          colLabels: (map['col_labels'] as List?)?.cast<String>() ?? [],
        ),
      _ => throw FormatException('Unknown chart type: $type', map),
    };
  }

  final String title;
  final String xLabel;
  final String yLabel;
}

List<math.Point<double>> _parsePoints(Object? raw) {
  if (raw is! List) return [];
  return raw.map<math.Point<double>>((item) {
    if (item is List && item.length >= 2) {
      return math.Point(
        (item[0] as num).toDouble(),
        (item[1] as num).toDouble(),
      );
    }
    return const math.Point(0, 0);
  }).toList();
}

List<double> _parseDoubles(Object? raw) {
  if (raw is! List) return [];
  return raw.map((v) => (v as num).toDouble()).toList();
}

List<int> _parseInts(Object? raw) {
  if (raw is! List) return [];
  return raw.map((v) => (v as num).toInt()).toList();
}

List<(int, int)> _parseEdges(Object? raw) {
  if (raw is! List) return [];
  return raw.map<(int, int)>((item) {
    if (item is List && item.length >= 2) {
      return ((item[0] as num).toInt(), (item[1] as num).toInt());
    }
    return (0, 0);
  }).toList();
}

/// Line chart: series of (x, y) points connected by lines.
class LineChartConfig extends DebugChartConfig {
  const LineChartConfig({
    required super.title,
    required super.xLabel,
    required super.yLabel,
    required this.points,
  });

  final List<math.Point<double>> points;
}

/// Bar chart: labelled categories with numeric values.
class BarChartConfig extends DebugChartConfig {
  const BarChartConfig({
    required super.title,
    required super.xLabel,
    required super.yLabel,
    required this.labels,
    required this.values,
  });

  final List<String> labels;
  final List<double> values;
}

/// Scatter chart: unconnected (x, y) data points.
class ScatterChartConfig extends DebugChartConfig {
  const ScatterChartConfig({
    required super.title,
    required super.xLabel,
    required super.yLabel,
    required this.points,
  });

  final List<math.Point<double>> points;
}

/// Pie chart: labelled slices with proportional values.
class PieChartConfig extends DebugChartConfig {
  const PieChartConfig({
    required super.title,
    required super.xLabel,
    required super.yLabel,
    required this.labels,
    required this.values,
    this.centerRadius = 40,
  });

  final List<String> labels;
  final List<double> values;
  final double centerRadius;
}

/// Radar chart: multi-axis polygon plot.
class RadarChartConfig extends DebugChartConfig {
  const RadarChartConfig({
    required super.title,
    required super.xLabel,
    required super.yLabel,
    required this.axes,
    required this.values,
  });

  final List<String> axes;
  final List<double> values;
}

/// Raw pixel image: flat RGBA byte array rendered as a bitmap.
class ImageConfig extends DebugChartConfig {
  const ImageConfig({
    required super.title,
    required super.xLabel,
    required super.yLabel,
    required this.width,
    required this.height,
    required this.pixels,
  });

  final int width;
  final int height;

  /// Flat RGBA byte array (length = width * height * 4).
  final List<int> pixels;
}

/// Node-and-edge graph with positioned nodes.
class GraphConfig extends DebugChartConfig {
  const GraphConfig({
    required super.title,
    required super.xLabel,
    required super.yLabel,
    required this.nodes,
    required this.edges,
    required this.positions,
  });

  final List<String> nodes;
  final List<(int, int)> edges;
  final List<math.Point<double>> positions;
}

/// Grid-based heatmap with labeled rows and columns.
class HeatmapConfig extends DebugChartConfig {
  const HeatmapConfig({
    required super.title,
    required super.xLabel,
    required super.yLabel,
    required this.rows,
    required this.cols,
    required this.values,
    required this.rowLabels,
    required this.colLabels,
  });

  final int rows;
  final int cols;

  /// Flat values array (length = rows * cols), row-major order.
  final List<double> values;
  final List<String> rowLabels;
  final List<String> colLabels;
}
