import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A single steam particle with position, velocity, and life.
class SteamParticle {
  SteamParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.maxLife,
    required this.radius,
  });

  double x;
  double y;
  double vx;
  double vy;
  double life;
  final double maxLife;
  final double radius;

  bool get isDead => life <= 0;
  double get opacity => (life / maxLife).clamp(0.0, 1.0);
}

/// Steam particle system — soft white circles rising, drifting, fading.
///
/// Renders particles via `MaskFilter.blur` on Canvas for soft glow.
/// Particles are managed externally via [SteamParticleController].
class SteamParticlePainter extends CustomPainter {
  SteamParticlePainter({
    required this.particles,
    this.color = Colors.white,
  }) : super(repaint: null);

  final List<SteamParticle> particles;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    for (final p in particles) {
      if (p.isDead) continue;
      paint.color = color.withAlpha((p.opacity * 40).round());
      canvas.drawCircle(Offset(p.x, p.y), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(SteamParticlePainter oldDelegate) => true; // Animated
}

/// Controller for steam particle lifecycle.
///
/// Call [tick] every frame to update particles. Call [burst] to emit
/// a group of particles (e.g. on message send).
class SteamParticleController {
  SteamParticleController({this.maxParticles = 40});

  final int maxParticles;
  final List<SteamParticle> particles = [];
  final _rng = math.Random();

  /// Emit particles continuously from the bottom of the given size.
  void emitAmbient(Size size) {
    if (particles.length >= maxParticles) return;

    // ~30% chance per tick to spawn one
    if (_rng.nextDouble() > 0.3) return;

    particles.add(SteamParticle(
      x: _rng.nextDouble() * size.width,
      y: size.height + 5,
      vx: (_rng.nextDouble() - 0.5) * 0.5,
      vy: -0.5 - _rng.nextDouble() * 1.0,
      life: 2.0 + _rng.nextDouble() * 2.0,
      maxLife: 4.0,
      radius: 3 + _rng.nextDouble() * 6,
    ));
  }

  /// Burst of particles from a given origin (e.g. message send).
  void burst(Offset origin, {int count = 10}) {
    for (var i = 0; i < count; i++) {
      particles.add(SteamParticle(
        x: origin.dx + (_rng.nextDouble() - 0.5) * 40,
        y: origin.dy,
        vx: (_rng.nextDouble() - 0.5) * 2.0,
        vy: -1.0 - _rng.nextDouble() * 2.0,
        life: 1.0 + _rng.nextDouble() * 1.5,
        maxLife: 2.5,
        radius: 2 + _rng.nextDouble() * 4,
      ));
    }
  }

  /// Advance all particles by [dt] seconds.
  void tick(double dt) {
    for (final p in particles) {
      p.x += p.vx;
      p.y += p.vy;
      p.life -= dt;
      // Slow drift
      p.vx *= 0.99;
    }
    particles.removeWhere((p) => p.isDead);
  }
}
