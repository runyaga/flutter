import 'package:flutter/material.dart';
import 'package:soliplex_frontend/core/providers/citation_providers.dart';

/// A panel that displays the full details of a citation.
///
/// Shows the document title, page numbers, full content, and optionally
/// a link to view the full source document.
class CitationPanel extends StatelessWidget {
  /// The citation data to display.
  final Citation citation;

  /// Callback when the panel should close.
  final VoidCallback onClose;

  const CitationPanel({
    required this.citation,
    required this.onClose,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row with icon, title, and close button
            Row(
              children: [
                Icon(
                  Icons.format_quote,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    citation.documentTitle ?? 'Source Document',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: onClose,
                  tooltip: 'Close',
                ),
              ],
            ),

            // Page numbers (if available)
            if (citation.pageNumbers != null &&
                citation.pageNumbers!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Page${citation.pageNumbers!.length > 1 ? 's' : ''}: '
                '${citation.pageNumbers!.join(', ')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            // Divider and content
            const SizedBox(height: 12),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 12),

            // Citation content (selectable for copy/paste)
            SelectableText(
              citation.content,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurface,
              ),
            ),

            // View document link
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => _openDocument(context, citation),
              icon: Icon(
                Icons.open_in_new,
                size: 16,
                color: colorScheme.primary,
              ),
              label: Text(
                'View full document',
                style: TextStyle(color: colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the source document for the citation.
  ///
  /// Implementation depends on document storage and navigation setup.
  /// Could navigate to an in-app document viewer or open an external link.
  void _openDocument(BuildContext context, Citation citation) {
    // TODO: Implement document navigation based on document storage
    // Options:
    // - Navigate to document viewer route with documentId
    // - Open external URL if available
    // - Show snackbar if document unavailable
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening document: ${citation.documentId}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
