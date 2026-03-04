import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens/colors.dart';
import '../design/tokens/spacing.dart';
import '../design/tokens/typography.dart';
import '../design/theme/steampunk_theme_extension.dart';
import '../painters/steel_plate_painter.dart';
import '../providers/room_providers.dart';

/// Left panel: server/channel tree in mIRC style.
///
/// ```
///  CONDUITS
/// ══════════
///  > MAIN
///    # general
///    # dev
///  > AUX
///    # logs
/// ```
class ServerTreePanel extends ConsumerWidget {
  const ServerTreePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sp = SteampunkTheme.of(context);
    final roomsAsync = ref.watch(roomsProvider);
    final selectedRoomId = ref.watch(currentRoomIdProvider);

    return CustomPaint(
      painter: SteelPlatePainter(color: BoilerColors.background),
      child: Column(
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
              'CONDUITS',
              style: BoilerTypography.oswald(
                fontSize: 13,
                color: sp.steamMuted,
              ),
            ),
          ),
          Container(height: 1, color: sp.borderColor),

          // Room list
          Expanded(
            child: roomsAsync.when(
              data: (rooms) => ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: BoilerSpacing.s1),
                itemCount: rooms.length,
                itemBuilder: (context, index) {
                  final room = rooms[index];
                  final isSelected = room.id == selectedRoomId;
                  return _RoomTile(
                    room: room,
                    isSelected: isSelected,
                    onTap: () {
                      ref.read(currentRoomIdProvider.notifier).select(room.id);
                      // Clear thread selection so auto-select kicks in.
                      ref
                          .read(threadSelectionProvider.notifier)
                          .remove(room.id);
                      ref.invalidate(threadsProvider);
                    },
                  );
                },
              ),
              loading: () => const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: BoilerColors.furnaceOrange,
                  ),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(BoilerSpacing.s3),
                child: Text(
                  'CONN ERR',
                  style: BoilerTypography.barlowCondensed(
                    fontSize: 11,
                    color: BoilerColors.furnaceRed,
                  ),
                ),
              ),
            ),
          ),

          // Logout
          Container(height: 1, color: sp.borderColor),
          InkWell(
            onTap: () {
              ref.read(currentRoomIdProvider.notifier).select(null);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: BoilerSpacing.s3,
                vertical: BoilerSpacing.s2,
              ),
              color: BoilerColors.surface,
              child: Row(
                children: [
                  Icon(
                    Icons.logout,
                    size: 14,
                    color: sp.steamMuted,
                  ),
                  const SizedBox(width: BoilerSpacing.s2),
                  Text(
                    'DISCONNECT',
                    style: BoilerTypography.barlowCondensed(
                      fontSize: 12,
                      color: sp.steamMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({
    required this.room,
    required this.isSelected,
    required this.onTap,
  });

  final dynamic room; // Room type from soliplex_client
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sp = SteampunkTheme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: BoilerSpacing.s3,
          vertical: BoilerSpacing.s1 + 2,
        ),
        color: isSelected ? BoilerColors.surface : Colors.transparent,
        child: Row(
          children: [
            Text(
              '#',
              style: BoilerTypography.sourceCodePro(
                fontSize: 13,
                color: isSelected ? sp.furnaceOrange : sp.iron,
              ),
            ),
            const SizedBox(width: BoilerSpacing.s1),
            Expanded(
              child: Text(
                (room as dynamic).name as String? ?? 'unnamed',
                style: BoilerTypography.sourceCodePro(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? sp.steamWhite : sp.steamMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
