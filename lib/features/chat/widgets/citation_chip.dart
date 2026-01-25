import 'package:flutter/material.dart';
import 'package:soliplex_frontend/core/providers/citation_providers.dart';

/// A small, clickable chip that displays a citation source label.
///
/// Designed with accessibility and usability in mind:
/// - Subtle styling that doesn't dominate the UI
/// - Theme-consistent colors via [ColorScheme]
/// - Touch-friendly: minimum 48dp tap target (Material guidelines)
/// - Accessible: meets WCAG contrast ratios via theme colors
///
/// Tapping the chip invokes [onTap], which should show the full citation details
/// (typically via [CitationPanel]).
class CitationChip extends StatelessWidget {
  /// The citation data to display.
  final Citation citation;

  /// Callback when the chip is tapped.
  final VoidCallback onTap;

  const CitationChip({
    required this.citation,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Use semantics for screen readers
    return Semantics(
      button: true,
      label: 'Citation: ${citation.label}',
      hint: 'Tap to view citation details',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        // Ensure minimum 48dp touch target per Material guidelines
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 48,
            minWidth: 48,
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                // Subtle background that works in both light and dark themes
                color: colorScheme.surfaceContainerHighest.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  // Subtle border for definition without being dominant
                  color: colorScheme.outlineVariant.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.format_quote_rounded,
                    size: 14,
                    // Use onSurfaceVariant for subtle, accessible color
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    citation.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      // onSurface provides good contrast in both themes
                      color: colorScheme.onSurface.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
