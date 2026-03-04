import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens/colors.dart';
import '../design/tokens/spacing.dart';
import '../design/tokens/typography.dart';
import '../design/theme/steampunk_theme_extension.dart';
import '../painters/hex_bolt_painter.dart';
import '../painters/rivet_row_painter.dart';
import '../painters/steel_plate_painter.dart';
import 'channel_tab_bar.dart';
import 'nick_list_panel.dart';
import 'server_tree_panel.dart';
import 'status_bar.dart';

/// The 3-panel mIRC layout scaffold — THE BOILER ROOM.
///
/// ```
/// [VALVE] THE BOILER ROOM  [GAUGE: CPU] [GAUGE: MEM] [GAUGE: LAG]
/// ═══════════════════════════════════════════════════════════════
///  CONDUITS ║ #GENERAL        [PIPE TAB] [PIPE TAB]     ║ CREW
/// ══════════║═══════════════════════════════════════════  ║══════
///  > MAIN   ║ [chat messages]                            ║ @eng1
///   # gen   ║                                            ║ +opr1
///   # eng   ║                                            ║ wrk1
/// ══════════║════════════════════════════════════════════ ║══════
///           ║ [====INPUT PIPE====] [SEND LEVER] [BOLT]   ║
/// ═══════════════════════════════════════════════════════════════
/// [!] PRESSURE: NOMINAL │ FLOW: 847 msg/h │ UPTIME: 4d 12h
/// ```
class MircShell extends ConsumerWidget {
  const MircShell({
    required this.chatPanel,
    super.key,
  });

  /// The chat content area (center panel).
  final Widget chatPanel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sp = SteampunkTheme.of(context);

    return Scaffold(
      backgroundColor: BoilerColors.background,
      body: Column(
        children: [
          // ── Title bar ──
          _TitleBar(sp: sp),

          // ── Heavy divider ──
          _HeavyDivider(color: sp.borderHeavy),

          // ── 3-panel body ──
          Expanded(
            child: Row(
              children: [
                // Left: Server/channel tree
                const SizedBox(
                  width: BoilerSpacing.serverTreeWidth,
                  child: ServerTreePanel(),
                ),
                _VerticalDivider(color: sp.borderHeavy),

                // Center: Tabs + chat
                Expanded(
                  child: Column(
                    children: [
                      const ChannelTabBar(),
                      _HeavyDivider(color: sp.borderColor),
                      Expanded(child: chatPanel),
                    ],
                  ),
                ),

                _VerticalDivider(color: sp.borderHeavy),
                // Right: Nick list
                const SizedBox(
                  width: BoilerSpacing.nickListWidth,
                  child: NickListPanel(),
                ),
              ],
            ),
          ),

          // ── Heavy divider ──
          _HeavyDivider(color: sp.borderHeavy),

          // ── Status bar ──
          const StatusBar(),
        ],
      ),
    );
  }
}

/// Industrial title bar with valve icon and gauge indicators.
class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.sp});

  final SteampunkTheme sp;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: SteelPlatePainter(color: BoilerColors.surface),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: BoilerSpacing.s4),
        child: Row(
          children: [
            // Valve icon
            CustomPaint(
              size: const Size(20, 20),
              painter: HexBoltPainter(
                color: sp.iron,
                highlightColor: sp.ironLight,
              ),
            ),
            const SizedBox(width: BoilerSpacing.s3),
            Text(
              'THE BOILER ROOM',
              style: BoilerTypography.oswald(
                fontSize: 18,
                color: sp.steamWhite,
              ),
            ),
            const Spacer(),
            // Mini gauges placeholder
            _MiniGaugeLabel(label: 'PRESSURE', value: 'NOMINAL', sp: sp),
            const SizedBox(width: BoilerSpacing.s4),
            _MiniGaugeLabel(label: 'FLOW', value: '---', sp: sp),
            const SizedBox(width: BoilerSpacing.s4),
            _MiniGaugeLabel(label: 'LAG', value: '0ms', sp: sp),
          ],
        ),
      ),
    );
  }
}

class _MiniGaugeLabel extends StatelessWidget {
  const _MiniGaugeLabel({
    required this.label,
    required this.value,
    required this.sp,
  });

  final String label;
  final String value;
  final SteampunkTheme sp;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: BoilerTypography.barlowCondensed(
            fontSize: 11,
            color: sp.steamDim,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: BoilerTypography.barlowCondensed(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: sp.gaugeAmber,
          ),
        ),
      ],
    );
  }
}

class _HeavyDivider extends StatelessWidget {
  const _HeavyDivider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, BoilerSpacing.dividerThickness),
      painter: RivetRowPainter(
        color: color,
        rivetColor: BoilerColors.iron,
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: BoilerSpacing.dividerThickness,
      color: color,
    );
  }
}
