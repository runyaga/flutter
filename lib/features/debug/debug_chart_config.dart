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

  final String title;
  final String xLabel;
  final String yLabel;
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
