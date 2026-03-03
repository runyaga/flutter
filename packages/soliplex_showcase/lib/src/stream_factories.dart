import 'dart:math';

/// Creates a stream yielding 30 radar config maps at ~400ms intervals.
///
/// Simulates an Ornstein-Uhlenbeck random walk on 5 axes, producing
/// gradually changing radar chart data.
Stream<Object?> radarMetricsStream() async* {
  final rng = Random();
  final axes = ['Speed', 'Quality', 'Teamwork', 'Innovation', 'Delivery'];
  final values = [80.0, 85.0, 75.0, 90.0, 88.0];

  for (var tick = 0; tick < 30; tick++) {
    // O-U random walk: mean-revert towards 80, add noise.
    for (var i = 0; i < values.length; i++) {
      final noise = (rng.nextDouble() - 0.5) * 10;
      values[i] = values[i] + 0.1 * (80 - values[i]) + noise;
      values[i] = values[i].clamp(20, 100);
    }

    yield <String, Object?>{
      'type': 'radar',
      'title': 'Live Metrics (tick ${tick + 1}/30)',
      'axes': List<String>.from(axes),
      'values': List<double>.from(values),
    };

    await Future<void>.delayed(const Duration(milliseconds: 400));
  }
}

/// Creates a stream yielding 30 bar-chart config maps at ~400ms intervals.
///
/// Simulates a server dashboard with Ornstein-Uhlenbeck mean-reverting
/// random walks on 5 metrics: CPU, MEM, NET, DSK, TMP.
Stream<Object?> serverMetricsStream() async* {
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
      'labels': List<String>.from(labels),
      'values': vals.map((v) => (v * 10).round() / 10).toList(),
    };
  }
}

/// Creates a stream yielding 20 pie config maps at ~500ms intervals.
///
/// Simulates fluctuating browser market share data.
Stream<Object?> marketShareStream() async* {
  final rng = Random();
  final browsers = ['Chrome', 'Safari', 'Firefox', 'Edge', 'Other'];
  final shares = [65.0, 18.5, 6.3, 5.2, 5.0];

  for (var tick = 0; tick < 20; tick++) {
    // Randomly shift shares.
    for (var i = 0; i < shares.length; i++) {
      shares[i] += (rng.nextDouble() - 0.5) * 2;
      if (shares[i] < 1) shares[i] = 1;
    }
    // Normalize to 100%.
    final total = shares.reduce((a, b) => a + b);
    for (var i = 0; i < shares.length; i++) {
      shares[i] = (shares[i] / total * 100 * 10).roundToDouble() / 10;
    }

    yield <String, Object?>{
      'type': 'pie',
      'title': 'Market Share (tick ${tick + 1}/20)',
      'labels': List<String>.from(browsers),
      'values': List<double>.from(shares),
      'center_radius': 40,
    };

    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
}
