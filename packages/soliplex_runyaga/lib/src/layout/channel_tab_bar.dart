import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens/colors.dart';
import '../design/tokens/spacing.dart';
import '../design/tokens/typography.dart';
import '../design/theme/steampunk_theme_extension.dart';
import '../providers/room_providers.dart';

/// Channel tabs styled as pipe segments.
///
/// ```
/// #GENERAL        [PIPE TAB] [PIPE TAB]
/// ```
class ChannelTabBar extends ConsumerWidget {
  const ChannelTabBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sp = SteampunkTheme.of(context);
    final roomId = ref.watch(currentRoomIdProvider);
    final threadsAsync =
        roomId != null ? ref.watch(threadsProvider(roomId)) : null;
    final selectedThreadId = ref.watch(currentThreadIdProvider);

    return Container(
      height: BoilerSpacing.tabBarHeight,
      color: BoilerColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: BoilerSpacing.s2),
      child: Row(
        children: [
          if (threadsAsync != null)
            threadsAsync.when(
              data: (threads) => Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: threads.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: BoilerSpacing.s1),
                  itemBuilder: (context, index) {
                    final thread = threads[index];
                    final isSelected = thread.id == selectedThreadId;
                    return _PipeTab(
                      label:
                          thread.hasName ? thread.name : 'Thread ${index + 1}',
                      isSelected: isSelected,
                      sp: sp,
                      onTap: () {
                        ref
                            .read(currentThreadIdProvider.notifier)
                            .select(thread.id);
                      },
                    );
                  },
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            )
          else
            Text(
              'NO CONDUIT SELECTED',
              style: BoilerTypography.barlowCondensed(
                fontSize: 12,
                color: sp.steamDim,
              ),
            ),
          const Spacer(),
          // New thread button
          if (roomId != null)
            _PipeTab(
              label: '+ NEW',
              isSelected: false,
              sp: sp,
              onTap: () {
                ref.read(currentThreadIdProvider.notifier).select(null);
              },
            ),
        ],
      ),
    );
  }
}

class _PipeTab extends StatelessWidget {
  const _PipeTab({
    required this.label,
    required this.isSelected,
    required this.sp,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final SteampunkTheme sp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: BoilerSpacing.s3,
            vertical: BoilerSpacing.s1,
          ),
          decoration: BoxDecoration(
            color: isSelected ? BoilerColors.surfaceHigh : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? BoilerColors.furnaceOrange
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: BoilerTypography.barlowCondensed(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? sp.furnaceOrange : sp.steamMuted,
            ),
          ),
        ),
      ),
    );
  }
}
