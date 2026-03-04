import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens/colors.dart';
import '../design/tokens/spacing.dart';
import '../design/tokens/typography.dart';
import '../design/theme/steampunk_theme_extension.dart';
import '../providers/room_providers.dart';

/// Right panel: nick/user list in mIRC style.
///
/// ```
///  CREW
/// ══════
///  @engineer1
///  +operator1
///  worker1
/// ```
class NickListPanel extends ConsumerWidget {
  const NickListPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sp = SteampunkTheme.of(context);
    final nicks = ref.watch(nickListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Panel header
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: BoilerSpacing.s3,
            vertical: BoilerSpacing.s2,
          ),
          color: BoilerColors.surface,
          child: Text(
            'CREW',
            style: BoilerTypography.oswald(
              fontSize: 13,
              color: sp.steamMuted,
            ),
          ),
        ),
        Container(height: 1, color: sp.borderColor),

        // Nick list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: BoilerSpacing.s1),
            itemCount: nicks.length,
            itemBuilder: (context, index) {
              final nick = nicks[index];
              return _NickTile(nick: nick, sp: sp);
            },
          ),
        ),
      ],
    );
  }
}

class _NickTile extends StatelessWidget {
  const _NickTile({required this.nick, required this.sp});

  final String nick;
  final SteampunkTheme sp;

  @override
  Widget build(BuildContext context) {
    // Parse prefix: @ = op (orange), + = voice (amber), none = regular
    final Color prefixColor;
    if (nick.startsWith('@')) {
      prefixColor = sp.furnaceOrange;
    } else if (nick.startsWith('+')) {
      prefixColor = sp.gaugeAmber;
    } else {
      prefixColor = sp.steamDim;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BoilerSpacing.s3,
        vertical: 2,
      ),
      child: Text(
        nick,
        style: BoilerTypography.sourceCodePro(
          fontSize: 12,
          color: prefixColor,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
