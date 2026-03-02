import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart' show ToolCallInfo;
import 'package:soliplex_dataframe/soliplex_dataframe.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/flutter_host_api.dart';
import 'package:soliplex_frontend/features/debug/debug_chart_config.dart';
import 'package:soliplex_frontend/features/debug/debug_chart_renderer.dart';
import 'package:soliplex_scripting/soliplex_scripting.dart';

// ---------------------------------------------------------------------------
// Demo step definitions
// ---------------------------------------------------------------------------

class _DemoStep {
  const _DemoStep({
    required this.title,
    required this.narration,
    required this.code,
    this.expectsError = false,
  });

  final String title;
  final String narration;
  final String code;
  final bool expectsError;
}

const _demos = <(String name, String description, List<_DemoStep> steps)>[
  (
    'Error Recovery',
    'Demonstrates the retry loop: code fails, gets fixed, succeeds.',
    [
      _DemoStep(
        title: 'Step 1: Buggy code',
        narration: 'The LLM writes code with a typo — pritn instead of print.',
        code: 'pritn("hello world")',
        expectsError: true,
      ),
      _DemoStep(
        title: 'Step 2: LLM reads the error, fixes the typo',
        narration: 'Monty reported NameError. The LLM corrects pritn → print.',
        code: 'print("hello world")',
      ),
    ],
  ),
  (
    'DataFrame → Chart',
    'Creates a DataFrame, computes stats, and renders a bar chart.',
    [
      _DemoStep(
        title: 'Step 1: Create DataFrame',
        narration: 'Python creates a DataFrame with city population data.',
        code: '''
handle = df_create([
    {"city": "Tokyo", "population": 37.4, "continent": "Asia"},
    {"city": "Delhi", "population": 32.9, "continent": "Asia"},
    {"city": "Shanghai", "population": 28.5, "continent": "Asia"},
    {"city": "São Paulo", "population": 22.4, "continent": "S. America"},
    {"city": "Mexico City", "population": 21.8, "continent": "N. America"}
])
print(f"Created DataFrame handle={handle}")
shape = df_shape(handle)
print(f"Shape: {shape[0]} rows x {shape[1]} columns")
head = df_head(handle, 5)
for row in head:
    print(row)
''',
      ),
      _DemoStep(
        title: 'Step 2: Render bar chart',
        narration:
            'Now we visualize the data as a bar chart in the Flutter UI.',
        code: '''
chart_create({
    "type": "bar",
    "title": "World Largest Cities by Population (millions)",
    "labels": ["Tokyo", "Delhi", "Shanghai", "São Paulo", "Mexico City"],
    "values": [37.4, 32.9, 28.5, 22.4, 21.8]
})
print("Chart rendered!")
''',
      ),
    ],
  ),
  (
    'Scatter Plot from Computation',
    'Python computes mathematical data and charts it.',
    [
      _DemoStep(
        title: 'Step 1: Compute data',
        narration: 'Python generates x² values and creates a scatter plot.',
        code: '''
points = []
for x in range(1, 16):
    y = (x ** 0.5) * 10
    points.append([x, round(y, 1)])
    print(f"x={x}, y={round(y, 1)}")

chart_create({
    "type": "scatter",
    "title": "Square Root Curve (√x × 10)",
    "x_label": "x",
    "y_label": "√x × 10",
    "points": points
})
print(f"Plotted {len(points)} points")
''',
      ),
    ],
  ),
  (
    'Fake Streaming Gauges',
    'A live server dashboard — all computation happens in Python '
        'with sleep-based pacing.',
    [
      _DemoStep(
        title: 'Step 1: Live dashboard (Python-driven)',
        narration: 'Creates a bar chart as gauge display, then streams '
            '30 ticks of Ornstein-Uhlenbeck random data at ~400ms intervals. '
            'Python computes the data and calls sleep() between ticks.',
        code: '''
seed = [42]
labels = ["CPU", "MEM", "NET", "DSK", "TMP"]
mus = [55.0, 40.0, 65.0, 25.0, 50.0]
vals = [55.0, 40.0, 65.0, 25.0, 50.0]

chart_id = await chart_create({
    "type": "bar", "title": "Server Dashboard (Live)",
    "labels": labels, "values": vals
})

for tick in range(30):
    for i in range(5):
        seed[0] = (seed[0] * 1103515245 + 12345) % 2147483648
        n = (seed[0] / 2147483648) * 2 - 1
        vals[i] = vals[i] + 0.15 * (mus[i] - vals[i]) + 8 * n
        if vals[i] < 0:
            vals[i] = 0.0
        if vals[i] > 100:
            vals[i] = 100.0
    r = [round(v, 1) for v in vals]
    print(f"[{tick + 1:02d}] CPU:{r[0]}% MEM:{r[1]}% NET:{r[2]}% DSK:{r[3]}% TMP:{r[4]}%")
    await chart_update(chart_id, {
        "type": "bar", "title": "Server Dashboard (Live)",
        "labels": labels, "values": r
    })
    await sleep(400)
print("Stream ended.")
''',
      ),
    ],
  ),
  (
    'Stream Gauges',
    'A live server dashboard — Dart produces O-U data via a stream, '
        'Python consumes it with stream_subscribe / stream_next.',
    [
      _DemoStep(
        title: 'Step 1: Live dashboard (Dart-driven)',
        narration: 'Subscribes to a Dart-side "server_metrics" stream that '
            'emits 30 ticks at ~400ms. Python pulls each snapshot and '
            'updates the chart — no sleep needed.',
        code: '''
chart_id = await chart_create({
    "type": "bar", "title": "Server Dashboard (Live)",
    "labels": ["CPU", "MEM", "NET", "DSK", "TMP"],
    "values": [50, 50, 50, 50, 50]
})

handle = await stream_subscribe("server_metrics")
tick = 0
while True:
    snapshot = await stream_next(handle)
    if snapshot is None:
        break
    tick = tick + 1
    vals = snapshot["values"]
    print(f"[{tick:02d}] CPU:{vals[0]}% MEM:{vals[1]}% NET:{vals[2]}% DSK:{vals[3]}% TMP:{vals[4]}%")
    await chart_update(chart_id, snapshot)

await stream_close(handle)
print("Stream ended.")
''',
      ),
    ],
  ),
  (
    'Multi-Step Analysis',
    'Create, filter, sort, and chart — a realistic analysis workflow.',
    [
      _DemoStep(
        title: 'Step 1: Create sales dataset',
        narration:
            'Build a sales DataFrame with regions and quarterly revenue.',
        code: '''
h = df_create([
    {"region": "North", "quarter": "Q1", "revenue": 120},
    {"region": "South", "quarter": "Q1", "revenue": 95},
    {"region": "East", "quarter": "Q1", "revenue": 140},
    {"region": "West", "quarter": "Q1", "revenue": 88},
    {"region": "North", "quarter": "Q2", "revenue": 135},
    {"region": "South", "quarter": "Q2", "revenue": 102},
    {"region": "East", "quarter": "Q2", "revenue": 155},
    {"region": "West", "quarter": "Q2", "revenue": 91}
])
print(f"Sales data created (handle={h})")
rows = df_head(h, 8)
for r in rows:
    print(r)
''',
      ),
      _DemoStep(
        title: 'Step 2: Filter Q2 and chart',
        narration: 'Filter to Q2 only, then chart regional revenue.',
        code: '''
h = 1
q2 = df_filter(h, "quarter", "==", "Q2")
print(f"Filtered to Q2 (handle={q2})")
q2_rows = df_head(q2, 4)
regions = []
revenues = []
for r in q2_rows:
    regions.append(r["region"])
    revenues.append(r["revenue"])
    print(r)

chart_create({
    "type": "bar",
    "title": "Q2 Revenue by Region",
    "labels": regions,
    "values": revenues
})
print("Q2 chart rendered!")
''',
      ),
      _DemoStep(
        title: 'Step 3: Growth line chart',
        narration: 'Compute Q1→Q2 growth per region and plot as a line chart.',
        code: '''
points = []
regions = ["North", "South", "East", "West"]
q1_vals = [120, 95, 140, 88]
q2_vals = [135, 102, 155, 91]
for i in range(4):
    pct = (q2_vals[i] - q1_vals[i]) / q1_vals[i] * 100
    points.append([i + 1, pct])
    print(f"{regions[i]}: {q1_vals[i]} -> {q2_vals[i]} = +{pct:.1f}%")

chart_create({
    "type": "line",
    "title": "Q1 -> Q2 Revenue Growth %",
    "x_label": "Region (1=N, 2=S, 3=E, 4=W)",
    "y_label": "Growth %",
    "points": points
})
print("Growth chart rendered!")
''',
      ),
    ],
  ),
];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class MontyShowcaseScreen extends ConsumerStatefulWidget {
  const MontyShowcaseScreen({super.key});

  @override
  ConsumerState<MontyShowcaseScreen> createState() =>
      _MontyShowcaseScreenState();
}

class _MontyShowcaseScreenState extends ConsumerState<MontyShowcaseScreen> {
  static const _threadKey = (
    serverId: 'local',
    roomId: 'showcase',
    threadId: 'demo',
  );

  late final BridgeCache _bridgeCache;
  late final MontyToolExecutor _executor;
  late final DfRegistry _dfRegistry;
  late final StreamRegistry _streamRegistry;
  final _charts = <int, DebugChartConfig>{};
  final _log = <_LogEntry>[];
  int _selectedDemo = 0;
  int _currentStep = 0;
  bool _isRunning = false;
  bool _autoPlay = false;

  @override
  void initState() {
    super.initState();
    _bridgeCache = ref.read(bridgeCacheProvider);
    final (:hostApi, :dfRegistry) = createFlutterHostBundle(
      onChartCreated: (id, config) {
        setState(() => _charts[id] = config);
      },
      onChartUpdated: (id, config) {
        setState(() => _charts[id] = config);
      },
    );
    _dfRegistry = dfRegistry;
    _streamRegistry = StreamRegistry()
      ..registerFactory('server_metrics', _serverMetricsStream);
    _executor = MontyToolExecutor(
      threadKey: _threadKey,
      bridgeCache: _bridgeCache,
      hostWiring: HostFunctionWiring(
        hostApi: hostApi,
        dfRegistry: dfRegistry,
        streamRegistry: _streamRegistry,
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_streamRegistry.dispose());
    _dfRegistry.disposeAll();
    _bridgeCache.evict(_threadKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (name, description, steps) = _demos[_selectedDemo];

    return Column(
      children: [
        // Demo selector bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: theme.colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (var i = 0; i < _demos.length; i++)
                      ChoiceChip(
                        label: Text(_demos[i].$1),
                        selected: i == _selectedDemo,
                        onSelected: _isRunning
                            ? null
                            : (selected) {
                                if (selected) _selectDemo(i);
                              },
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _isRunning ? null : _runAllSteps,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Run All'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _isRunning ? null : _reset,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
              ),
            ],
          ),
        ),
        // Description
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        // Main content
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Steps + code
              Expanded(
                flex: 3,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (var i = 0; i < steps.length; i++) ...[
                      _buildStepCard(i, steps[i]),
                      if (i < steps.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              // Right: Output + charts
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Charts
                    if (_charts.isNotEmpty) ...[
                      SizedBox(
                        height: 220,
                        child: PageView.builder(
                          itemCount: _charts.length,
                          itemBuilder: (_, i) {
                            final config = _charts.values.elementAt(i);
                            return Padding(
                              padding: const EdgeInsets.all(12),
                              child: DebugChartRenderer(config: config),
                            );
                          },
                        ),
                      ),
                      Center(
                        child: Text(
                          '${_charts.length} chart(s) — swipe to browse',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                    // Console output
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        'Console Output',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: SelectableText.rich(
                            TextSpan(
                              children: [
                                for (final entry in _log) _buildLogSpan(entry),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepCard(int index, _DemoStep step) {
    final theme = Theme.of(context);
    final isDone = _stepResults.containsKey(index);
    final isActive = index == _currentStep && _isRunning;
    final result = _stepResults[index];

    return Card(
      elevation: isActive ? 4 : 1,
      color: isActive
          ? theme.colorScheme.primaryContainer
          : isDone
              ? ((result?.isError ?? false)
                  ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
                  : theme.colorScheme.surfaceContainerLow)
              : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isActive)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (isDone && !(result?.isError ?? false))
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 18,
                  )
                else if (isDone && (result?.isError ?? false))
                  const Icon(Icons.error, color: Colors.orange, size: 18)
                else
                  Icon(
                    Icons.circle_outlined,
                    color: theme.colorScheme.outline,
                    size: 18,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!_isRunning && !isDone)
                  TextButton(
                    onPressed: () => _runStep(index),
                    child: const Text('Run'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              step.narration,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                step.code.trim(),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFFD4D4D4),
                  height: 1.4,
                ),
              ),
            ),
            if (result != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: result.isError
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: result.isError
                        ? Colors.red.shade200
                        : Colors.green.shade200,
                  ),
                ),
                child: SelectableText(
                  result.isError ? 'Error: ${result.output}' : result.output,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: result.isError
                        ? Colors.red.shade900
                        : Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  TextSpan _buildLogSpan(_LogEntry entry) {
    final color = switch (entry.kind) {
      _LogKind.narration => const Color(0xFF6A9955),
      _LogKind.code => const Color(0xFF569CD6),
      _LogKind.output => const Color(0xFFD4D4D4),
      _LogKind.error => const Color(0xFFF44747),
      _LogKind.system => const Color(0xFF808080),
    };
    final prefix = switch (entry.kind) {
      _LogKind.narration => '# ',
      _LogKind.code => '> ',
      _LogKind.output => '  ',
      _LogKind.error => '! ',
      _LogKind.system => '~ ',
    };

    return TextSpan(
      text: '$prefix${entry.text}\n',
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        color: color,
        height: 1.4,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Execution
  // -------------------------------------------------------------------------

  final _stepResults = <int, _StepResult>{};

  void _selectDemo(int index) {
    setState(() {
      _selectedDemo = index;
      _currentStep = 0;
      _stepResults.clear();
      _log.clear();
      _charts.clear();
    });
    _dfRegistry.disposeAll();
  }

  void _reset() {
    setState(() {
      _currentStep = 0;
      _stepResults.clear();
      _log.clear();
      _charts.clear();
    });
    _dfRegistry.disposeAll();
  }

  Future<void> _runAllSteps() async {
    _reset();
    setState(() {
      _autoPlay = true;
      _isRunning = true;
    });
    final (_, _, steps) = _demos[_selectedDemo];
    for (var i = 0; i < steps.length; i++) {
      if (!mounted) return;
      await _runStep(i);
      if (i < steps.length - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
    }
    setState(() {
      _isRunning = false;
      _autoPlay = false;
    });
  }

  Future<void> _runStep(int index) async {
    final (_, _, steps) = _demos[_selectedDemo];
    final step = steps[index];

    setState(() {
      _currentStep = index;
      if (!_autoPlay) _isRunning = true;
    });

    _addLog(step.narration, _LogKind.narration);
    _addLog('Executing Python...', _LogKind.system);

    try {
      final toolCall = ToolCallInfo(
        id: 'demo-${DateTime.now().millisecondsSinceEpoch}',
        name: PythonExecutorTool.toolName,
        arguments: jsonEncode({'code': step.code.trim()}),
      );
      final output = await _executor.execute(toolCall);

      if (step.expectsError) {
        // Shouldn't get here for expected errors, but handle gracefully
        _addLog(output, _LogKind.output);
        setState(() {
          _stepResults[index] = _StepResult(output);
        });
      } else {
        _addLog(output.isEmpty ? '(no output)' : output, _LogKind.output);
        setState(() {
          _stepResults[index] = _StepResult(
            output.isEmpty ? '(completed successfully)' : output,
          );
        });
      }
    } on Object catch (e) {
      final msg = '$e';
      _addLog(msg, _LogKind.error);
      setState(() {
        _stepResults[index] = _StepResult(msg, isError: step.expectsError);
      });
      if (step.expectsError) {
        _addLog(
          '(Expected error — the next step will fix it)',
          _LogKind.system,
        );
      }
    }

    if (!_autoPlay) {
      setState(() => _isRunning = false);
    }
  }

  void _addLog(String text, _LogKind kind) {
    setState(() => _log.add(_LogEntry(text, kind)));
  }

  /// Ornstein-Uhlenbeck stream: 30 ticks at ~400ms with mean-reverting noise.
  static Stream<Object?> _serverMetricsStream() async* {
    final labels = ['CPU', 'MEM', 'NET', 'DSK', 'TMP'];
    final mus = [55.0, 40.0, 65.0, 25.0, 50.0];
    final vals = [...mus];
    var seed = 42;

    for (var tick = 0; tick < 30; tick++) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      for (var i = 0; i < 5; i++) {
        seed = (seed * 1103515245 + 12345) % 2147483648;
        final n = (seed / 2147483648) * 2 - 1;
        vals[i] = (vals[i] + 0.15 * (mus[i] - vals[i]) + 8 * n).clamp(0, 100);
      }
      yield <String, Object?>{
        'type': 'bar',
        'title': 'Server Dashboard (Live)',
        'labels': labels,
        'values': vals.map((v) => (v * 10).round() / 10).toList(),
      };
    }
  }
}

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

class _StepResult {
  const _StepResult(this.output, {this.isError = false});
  final String output;
  final bool isError;
}

class _LogEntry {
  const _LogEntry(this.text, this.kind);
  final String text;
  final _LogKind kind;
}

enum _LogKind { narration, code, output, error, system }
