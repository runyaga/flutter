// TEMPORARY: Chart renderer for debug REPL —
// remove after validation.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:soliplex_frontend/features/debug/debug_chart_config.dart';

/// Renders a [DebugChartConfig] as an fl_chart widget.
class DebugChartRenderer extends StatelessWidget {
  const DebugChartRenderer({required this.config, super.key});

  final DebugChartConfig config;

  @override
  Widget build(BuildContext context) => switch (config) {
        final LineChartConfig c => _LineChartView(config: c),
        final BarChartConfig c => _BarChartView(config: c),
        final ScatterChartConfig c => _ScatterChartView(config: c),
        final PieChartConfig c => _PieChartView(config: c),
        final RadarChartConfig c => _RadarChartView(config: c),
        final ImageConfig c => _ImageView(config: c),
        final GraphConfig c => _GraphView(config: c),
        final HeatmapConfig c => _HeatmapView(config: c),
      };
}

class _LineChartView extends StatelessWidget {
  const _LineChartView({required this.config});
  final LineChartConfig config;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (final p in config.points) FlSpot(p.x, p.y),
            ],
            isCurved: true,
            color: color,
          ),
        ],
        titlesData: _titlesData(
          config.xLabel,
          config.yLabel,
        ),
        borderData: FlBorderData(show: true),
      ),
    );
  }
}

class _BarChartView extends StatelessWidget {
  const _BarChartView({required this.config});
  final BarChartConfig config;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.tertiary;
    return BarChart(
      BarChartData(
        barGroups: [
          for (var i = 0; i < config.values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: config.values[i],
                  color: color,
                  width: 16,
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            axisNameWidget: Text(
              config.xLabel,
              style: const TextStyle(fontSize: 11),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= config.labels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    config.labels[i],
                    style: const TextStyle(
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: Text(
              config.yLabel,
              style: const TextStyle(fontSize: 11),
            ),
            sideTitles: const SideTitles(
              showTitles: true,
              reservedSize: 40,
            ),
          ),
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
        ),
        gridData: const FlGridData(),
        borderData: FlBorderData(show: true),
      ),
    );
  }
}

class _ScatterChartView extends StatelessWidget {
  const _ScatterChartView({required this.config});
  final ScatterChartConfig config;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return ScatterChart(
      ScatterChartData(
        scatterSpots: [
          for (final p in config.points)
            ScatterSpot(
              p.x,
              p.y,
              dotPainter: FlDotCirclePainter(
                color: color,
                radius: 10,
              ),
            ),
        ],
        titlesData: _titlesData(
          config.xLabel,
          config.yLabel,
        ),
        gridData: const FlGridData(),
        borderData: FlBorderData(show: true),
      ),
    );
  }
}

const _sliceColors = [
  Colors.blue,
  Colors.red,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.teal,
  Colors.pink,
  Colors.amber,
];

class _PieChartView extends StatelessWidget {
  const _PieChartView({required this.config});
  final PieChartConfig config;

  @override
  Widget build(BuildContext context) {
    return PieChart(
      PieChartData(
        centerSpaceRadius: config.centerRadius,
        sections: [
          for (var i = 0; i < config.values.length; i++)
            PieChartSectionData(
              value: config.values[i],
              title: i < config.labels.length
                  ? config.labels[i]
                  : '${config.values[i]}',
              color: _sliceColors[i % _sliceColors.length],
              radius: 60,
              titleStyle: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}

class _RadarChartView extends StatelessWidget {
  const _RadarChartView({required this.config});
  final RadarChartConfig config;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return RadarChart(
      RadarChartData(
        radarShape: RadarShape.polygon,
        dataSets: [
          RadarDataSet(
            dataEntries: [
              for (final v in config.values) RadarEntry(value: v),
            ],
            fillColor: color.withValues(alpha: 0.2),
            borderColor: color,
            borderWidth: 2,
          ),
        ],
        getTitle: (index, _) {
          if (index < config.axes.length) {
            return RadarChartTitle(text: config.axes[index]);
          }
          return const RadarChartTitle(text: '');
        },
        tickCount: 4,
        tickBorderData: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(
                alpha: 0.3,
              ),
        ),
        gridBorderData: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(
                alpha: 0.3,
              ),
        ),
      ),
    );
  }
}

class _ImageView extends StatefulWidget {
  const _ImageView({required this.config});
  final ImageConfig config;

  @override
  State<_ImageView> createState() => _ImageViewState();
}

class _ImageViewState extends State<_ImageView> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  @override
  void didUpdateWidget(_ImageView old) {
    super.didUpdateWidget(old);
    if (old.config != widget.config) _decodeImage();
  }

  void _decodeImage() {
    final c = widget.config;
    if (c.width <= 0 || c.height <= 0 || c.pixels.isEmpty) return;
    final bytes = Uint8List.fromList(c.pixels);
    ui.decodeImageFromPixels(
      bytes,
      c.width,
      c.height,
      ui.PixelFormat.rgba8888,
      (img) {
        if (mounted) setState(() => _image = img);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    if (img == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(child: RawImage(image: img));
  }
}

class _GraphView extends StatelessWidget {
  const _GraphView({required this.config});
  final GraphConfig config;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return CustomPaint(
      painter: _GraphPainter(
        config: config,
        nodeColor: color,
        edgeColor: Theme.of(context).colorScheme.outline,
        labelColor: Theme.of(context).colorScheme.onSurface,
      ),
      size: Size.infinite,
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.config,
    required this.nodeColor,
    required this.edgeColor,
    required this.labelColor,
  });

  final GraphConfig config;
  final Color nodeColor;
  final Color edgeColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (config.positions.isEmpty) return;

    final edgePaint = Paint()
      ..color = edgeColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final nodePaint = Paint()
      ..color = nodeColor
      ..style = PaintingStyle.fill;

    // Scale positions to canvas.
    final xs = config.positions.map((p) => p.x);
    final ys = config.positions.map((p) => p.y);
    final minX = xs.reduce((a, b) => a < b ? a : b);
    final maxX = xs.reduce((a, b) => a > b ? a : b);
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    final rangeX = maxX - minX;
    final rangeY = maxY - minY;
    const pad = 30.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;

    Offset toCanvas(int i) {
      final p = config.positions[i];
      final dx = rangeX == 0 ? w / 2 : (p.x - minX) / rangeX * w;
      final dy = rangeY == 0 ? h / 2 : (p.y - minY) / rangeY * h;
      return Offset(pad + dx, pad + dy);
    }

    // Draw edges.
    for (final (from, to) in config.edges) {
      if (from < config.positions.length && to < config.positions.length) {
        canvas.drawLine(toCanvas(from), toCanvas(to), edgePaint);
      }
    }

    // Draw nodes.
    for (var i = 0; i < config.positions.length; i++) {
      final c = toCanvas(i);
      canvas.drawCircle(c, 12, nodePaint);
      if (i < config.nodes.length) {
        final tp = TextPainter(
          text: TextSpan(
            text: config.nodes[i],
            style: TextStyle(color: labelColor, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, c - Offset(tp.width / 2, tp.height + 14));
      }
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) => old.config != config;
}

class _HeatmapView extends StatelessWidget {
  const _HeatmapView({required this.config});
  final HeatmapConfig config;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HeatmapPainter(
        config: config,
        labelColor: Theme.of(context).colorScheme.onSurface,
      ),
      size: Size.infinite,
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.config,
    required this.labelColor,
  });

  final HeatmapConfig config;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (config.rows <= 0 || config.cols <= 0) return;
    if (config.values.isEmpty) return;

    const labelPad = 40.0;
    final cellW = (size.width - labelPad) / config.cols;
    final cellH = (size.height - labelPad) / config.rows;

    // Find value range for color interpolation.
    final minV = config.values.reduce(
      (a, b) => a < b ? a : b,
    );
    final maxV = config.values.reduce(
      (a, b) => a > b ? a : b,
    );
    final range = maxV - minV;

    for (var r = 0; r < config.rows; r++) {
      for (var c = 0; c < config.cols; c++) {
        final idx = r * config.cols + c;
        if (idx >= config.values.length) continue;
        final t = range == 0 ? 0.5 : (config.values[idx] - minV) / range;
        final color = Color.lerp(
          Colors.blue.shade100,
          Colors.red.shade700,
          t,
        )!;
        canvas.drawRect(
          Rect.fromLTWH(
            labelPad + c * cellW,
            r * cellH,
            cellW,
            cellH,
          ),
          Paint()..color = color,
        );
      }
    }

    // Row labels.
    for (var r = 0; r < config.rowLabels.length; r++) {
      final tp = TextPainter(
        text: TextSpan(
          text: config.rowLabels[r],
          style: TextStyle(color: labelColor, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(2, r * cellH + (cellH - tp.height) / 2),
      );
    }

    // Column labels.
    for (var c = 0; c < config.colLabels.length; c++) {
      final tp = TextPainter(
        text: TextSpan(
          text: config.colLabels[c],
          style: TextStyle(color: labelColor, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          labelPad + c * cellW + (cellW - tp.width) / 2,
          config.rows * cellH + 4,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) => old.config != config;
}

FlTitlesData _titlesData(String xLabel, String yLabel) => FlTitlesData(
      bottomTitles: AxisTitles(
        axisNameWidget: Text(
          xLabel,
          style: const TextStyle(fontSize: 11),
        ),
        sideTitles: const SideTitles(
          showTitles: true,
          reservedSize: 28,
        ),
      ),
      leftTitles: AxisTitles(
        axisNameWidget: Text(
          yLabel,
          style: const TextStyle(fontSize: 11),
        ),
        sideTitles: const SideTitles(
          showTitles: true,
          reservedSize: 40,
        ),
      ),
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
    );
