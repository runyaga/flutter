import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens/colors.dart';
import '../../design/tokens/spacing.dart';
import '../../design/tokens/typography.dart';
import '../../design/theme/steampunk_theme_extension.dart';
import '../../painters/hex_bolt_painter.dart';
import '../../painters/pressure_gauge_painter.dart';
import '../../painters/steam_particle_painter.dart';
import '../../providers/agent_providers.dart';
import '../../providers/room_providers.dart';

/// Backend URL entry screen — no auth, direct connect.
///
/// Features a smoking boiler room scene with animated steam,
/// spinning gears, pulsing furnace glow, and pressure gauge.
class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({required this.onConnected, super.key});

  final VoidCallback onConnected;

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen>
    with TickerProviderStateMixin {
  final _urlController =
      TextEditingController(text: 'https://demo.toughserv.com');
  var _isConnecting = false;
  String? _error;

  // Steam particles
  late final Ticker _ticker;
  final _steamController = SteamParticleController(maxParticles: 60);
  Duration _lastTick = Duration.zero;

  // Gear rotation
  late final AnimationController _gearController;

  // Furnace pulse
  late final AnimationController _furnaceController;

  // Gauge value
  late final AnimationController _gaugeController;

  @override
  void initState() {
    super.initState();

    _ticker = createTicker(_onTick)..start();

    _gearController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _furnaceController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _gaugeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;

    final dt = _lastTick == Duration.zero
        ? 0.016
        : (elapsed - _lastTick).inMilliseconds / 1000.0;
    _lastTick = elapsed;

    // Guard: context.size is only available after layout
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      _steamController.emitAmbient(renderObject.size);
    }
    _steamController.tick(dt);
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _gearController.dispose();
    _furnaceController.dispose();
    _gaugeController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
      _error = null;
    });

    // Animate gauge to high pressure
    _gaugeController.animateTo(0.85, curve: Curves.easeOut);

    // Speed up gears
    _gearController
      ..stop()
      ..duration = const Duration(seconds: 2)
      ..repeat();

    // Burst steam
    final size = context.size;
    if (size != null) {
      _steamController.burst(
        Offset(size.width / 2, size.height * 0.7),
        count: 20,
      );
    }

    final url = _urlController.text.trim();
    ref.read(baseUrlProvider.notifier).set(url);

    try {
      await ref.read(apiProvider).getRooms();
      ref.invalidate(roomsProvider);

      // Full pressure on success
      await _gaugeController.animateTo(1.0, curve: Curves.easeIn);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      widget.onConnected();
    } catch (e) {
      // Gauge drops back
      _gaugeController.animateTo(0.1, curve: Curves.easeOut);
      _gearController
        ..stop()
        ..duration = const Duration(seconds: 8)
        ..repeat();
      setState(() {
        _error = 'CONNECTION FAILED: $e';
        _isConnecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = SteampunkTheme.of(context);

    return Scaffold(
      backgroundColor: BoilerColors.background,
      body: Stack(
        children: [
          // ── Background: furnace glow from bottom ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 200,
            child: AnimatedBuilder(
              animation: _furnaceController,
              builder: (context, _) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        BoilerColors.furnaceRed.withAlpha(
                          (50 + 30 * _furnaceController.value).round(),
                        ),
                        BoilerColors.furnaceOrange.withAlpha(
                          (20 * _furnaceController.value).round(),
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Decorative gears (left side) ──
          Positioned(
            left: 40,
            top: 80,
            child: _SpinningGear(
              controller: _gearController,
              size: 100,
              color: BoilerColors.iron.withAlpha(40),
            ),
          ),
          Positioned(
            left: 110,
            top: 130,
            child: _SpinningGear(
              controller: _gearController,
              size: 60,
              color: BoilerColors.iron.withAlpha(30),
              reverse: true,
            ),
          ),

          // ── Decorative gears (right side) ──
          Positioned(
            right: 40,
            bottom: 120,
            child: _SpinningGear(
              controller: _gearController,
              size: 80,
              color: BoilerColors.iron.withAlpha(35),
            ),
          ),
          Positioned(
            right: 100,
            bottom: 80,
            child: _SpinningGear(
              controller: _gearController,
              size: 50,
              color: BoilerColors.iron.withAlpha(25),
              reverse: true,
            ),
          ),

          // ── Pipe decorations along edges ──
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 8,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    BoilerColors.iron.withAlpha(60),
                    BoilerColors.iron.withAlpha(20),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 8,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    BoilerColors.iron.withAlpha(60),
                    BoilerColors.iron.withAlpha(20),
                  ],
                ),
              ),
            ),
          ),

          // ── Steam particles overlay ──
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: SteamParticlePainter(
                  particles: _steamController.particles,
                ),
              ),
            ),
          ),

          // ── Main content ──
          Center(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated pressure gauge
                  AnimatedBuilder(
                    animation: _gaugeController,
                    builder: (context, _) {
                      return CustomPaint(
                        size: const Size(100, 100),
                        painter: PressureGaugePainter(
                          value: _gaugeController.value,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: BoilerSpacing.s6),

                  // Title with subtle glow
                  Text(
                    'THE BOILER ROOM',
                    style: BoilerTypography.oswald(
                      fontSize: 32,
                      color: sp.steamWhite,
                    ),
                  ),
                  const SizedBox(height: BoilerSpacing.s2),
                  Text(
                    'FULL STEAM AHEAD',
                    style: BoilerTypography.barlowCondensed(
                      fontSize: 16,
                      color: sp.steamDim,
                    ),
                  ),
                  const SizedBox(height: BoilerSpacing.s8),

                  // URL input with bolt decoration
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: sp.borderHeavy, width: 2),
                      borderRadius: BorderRadius.circular(2),
                      color: BoilerColors.codeBackground,
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(BoilerSpacing.s2),
                          child: CustomPaint(
                            size: const Size(16, 16),
                            painter: HexBoltPainter(
                              color: sp.iron,
                              highlightColor: sp.ironLight,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            style: BoilerTypography.sourceCodePro(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'BACKEND URL',
                              hintStyle: BoilerTypography.sourceCodePro(
                                fontSize: 14,
                                color: sp.steamDim,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: BoilerSpacing.s2,
                                vertical: BoilerSpacing.s3,
                              ),
                            ),
                            onSubmitted: (_) => _connect(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(BoilerSpacing.s2),
                          child: CustomPaint(
                            size: const Size(16, 16),
                            painter: HexBoltPainter(
                              color: sp.iron,
                              highlightColor: sp.ironLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: BoilerSpacing.s4),

                  // Connect lever button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: AnimatedBuilder(
                      animation: _furnaceController,
                      builder: (context, _) {
                        final glowAlpha = _isConnecting
                            ? (40 + 40 * _furnaceController.value).round()
                            : 0;
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              if (_isConnecting)
                                BoxShadow(
                                  color: BoilerColors.furnaceOrange
                                      .withAlpha(glowAlpha),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                            ],
                          ),
                          child: FilledButton(
                            onPressed: _isConnecting ? null : _connect,
                            style: FilledButton.styleFrom(
                              backgroundColor: _isConnecting
                                  ? BoilerColors.furnaceRed
                                  : BoilerColors.rust,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isConnecting) ...[
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: BoilerColors.steamWhite,
                                    ),
                                  ),
                                  const SizedBox(width: BoilerSpacing.s3),
                                ],
                                Text(
                                  _isConnecting
                                      ? 'FIRING UP BOILERS...'
                                      : 'ENGAGE BOILERS',
                                  style: BoilerTypography.oswald(
                                    fontSize: 16,
                                    color: sp.steamWhite,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Error display
                  if (_error != null) ...[
                    const SizedBox(height: BoilerSpacing.s4),
                    Container(
                      padding: const EdgeInsets.all(BoilerSpacing.s3),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: BoilerColors.furnaceRed.withAlpha(100),
                        ),
                        borderRadius: BorderRadius.circular(2),
                        color: BoilerColors.furnaceRed.withAlpha(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber,
                            size: 16,
                            color: BoilerColors.furnaceRed,
                          ),
                          const SizedBox(width: BoilerSpacing.s2),
                          Expanded(
                            child: Text(
                              _error!,
                              style: BoilerTypography.barlowCondensed(
                                fontSize: 12,
                                color: sp.furnaceRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A gear that spins continuously — decorative background element.
class _SpinningGear extends StatelessWidget {
  const _SpinningGear({
    required this.controller,
    required this.size,
    required this.color,
    this.reverse = false,
  });

  final AnimationController controller;
  final double size;
  final Color color;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final angle = controller.value * 2 * math.pi * (reverse ? -1 : 1);
        return Transform.rotate(
          angle: angle,
          child: CustomPaint(
            size: Size.square(size),
            painter: _GearPainter(color: color),
          ),
        );
      },
    );
  }
}

/// Paints a gear with teeth — used for decorative background elements.
class _GearPainter extends CustomPainter {
  _GearPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.7;
    const teethCount = 12;
    const toothWidth = math.pi / teethCount * 0.6;

    final path = Path();

    for (var i = 0; i < teethCount; i++) {
      final angle = (2 * math.pi / teethCount) * i;

      // Inner point before tooth
      final innerAngle1 = angle - toothWidth;
      path.lineTo(
        center.dx + innerRadius * math.cos(innerAngle1),
        center.dy + innerRadius * math.sin(innerAngle1),
      );

      // Outer tooth
      path.lineTo(
        center.dx + outerRadius * math.cos(angle - toothWidth * 0.5),
        center.dy + outerRadius * math.sin(angle - toothWidth * 0.5),
      );
      path.lineTo(
        center.dx + outerRadius * math.cos(angle + toothWidth * 0.5),
        center.dy + outerRadius * math.sin(angle + toothWidth * 0.5),
      );

      // Inner point after tooth
      final innerAngle2 = angle + toothWidth;
      path.lineTo(
        center.dx + innerRadius * math.cos(innerAngle2),
        center.dy + innerRadius * math.sin(innerAngle2),
      );
    }
    path.close();

    canvas.drawPath(path, Paint()..color = color);

    // Center hole
    canvas.drawCircle(
      center,
      innerRadius * 0.35,
      Paint()..color = BoilerColors.background,
    );

    // Center ring
    canvas.drawCircle(
      center,
      innerRadius * 0.35,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_GearPainter oldDelegate) => color != oldDelegate.color;
}
