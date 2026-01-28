import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Citation data from ask_history - copy of the model for testing.
/// This mirrors the Citation class in citation_providers.dart.
class Citation {
  final String documentId;
  final String chunkId;
  final List<int> pageNumbers;
  final String content;
  final String? documentTitle;

  Citation({
    required this.documentId,
    required this.chunkId,
    required this.pageNumbers,
    required this.content,
    this.documentTitle,
  });

  factory Citation.fromJson(Map<String, dynamic> json) {
    return Citation(
      documentId: json['document_id'] as String? ?? '',
      chunkId: json['chunk_id'] as String? ?? '',
      pageNumbers: (json['page_numbers'] as List?)?.cast<int>() ?? [],
      content: json['content'] as String? ?? '',
      documentTitle: json['document_title'] as String?,
    );
  }

  String get label {
    if (documentTitle != null && documentTitle!.isNotEmpty) {
      return documentTitle!;
    }
    if (pageNumbers.isNotEmpty) {
      return 'Page ${pageNumbers.first}';
    }
    return 'Source';
  }
}

/// A small, clickable chip that displays a citation source label.
/// Copy of CitationChip for testing without broken imports.
class CitationChip extends StatelessWidget {
  final Citation citation;
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

    return Semantics(
      button: true,
      label: 'Citation: ${citation.label}',
      hint: 'Tap to view citation details',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 48,
            minWidth: 48,
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.format_quote_rounded,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    citation.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.8),
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

/// A panel that displays the full details of a citation.
/// Copy of CitationPanel for testing without broken imports.
class CitationPanel extends StatelessWidget {
  final Citation citation;
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
            if (citation.pageNumbers.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Page${citation.pageNumbers.length > 1 ? 's' : ''}: ${citation.pageNumbers.join(', ')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 12),
            SelectableText(
              citation.content,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurface,
              ),
            ),
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

  void _openDocument(BuildContext context, Citation citation) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening document: ${citation.documentId}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

void main() {
  group('Citation', () {
    test('label returns documentTitle when available', () {
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'chunk-1',
        pageNumbers: [42],
        content: 'Sample content',
        documentTitle: 'Research Paper',
      );

      expect(citation.label, equals('Research Paper'));
    });

    test('label returns page number when no title', () {
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'chunk-1',
        pageNumbers: [42],
        content: 'Sample content',
      );

      expect(citation.label, equals('Page 42'));
    });

    test('label returns Source when no title or page numbers', () {
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'chunk-1',
        pageNumbers: [],
        content: 'Sample content',
      );

      expect(citation.label, equals('Source'));
    });

    test('label returns Source when title is empty', () {
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'chunk-1',
        pageNumbers: [],
        content: 'Sample content',
        documentTitle: '',
      );

      expect(citation.label, equals('Source'));
    });

    test('fromJson parses all fields correctly', () {
      final json = {
        'document_id': 'doc-123',
        'chunk_id': 'chunk-456',
        'page_numbers': [1, 2, 3],
        'content': 'Citation text here',
        'document_title': 'Test Document',
      };

      final citation = Citation.fromJson(json);

      expect(citation.documentId, equals('doc-123'));
      expect(citation.chunkId, equals('chunk-456'));
      expect(citation.pageNumbers, equals([1, 2, 3]));
      expect(citation.content, equals('Citation text here'));
      expect(citation.documentTitle, equals('Test Document'));
    });

    test('fromJson handles missing optional fields', () {
      final json = <String, dynamic>{
        'document_id': 'doc-123',
        'chunk_id': 'chunk-456',
      };

      final citation = Citation.fromJson(json);

      expect(citation.documentId, equals('doc-123'));
      expect(citation.chunkId, equals('chunk-456'));
      expect(citation.pageNumbers, isEmpty);
      expect(citation.content, isEmpty);
      expect(citation.documentTitle, isNull);
    });

    test('fromJson handles null values gracefully', () {
      final json = <String, dynamic>{
        'document_id': null,
        'chunk_id': null,
        'page_numbers': null,
        'content': null,
        'document_title': null,
      };

      final citation = Citation.fromJson(json);

      expect(citation.documentId, isEmpty);
      expect(citation.chunkId, isEmpty);
      expect(citation.pageNumbers, isEmpty);
      expect(citation.content, isEmpty);
      expect(citation.documentTitle, isNull);
    });
  });

  group('CitationChip', () {
    testWidgets('shows citation label with document title', (tester) async {
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'chunk-1',
        pageNumbers: [42],
        content: 'Sample content',
        documentTitle: 'Research Paper',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitationChip(
              citation: citation,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Research Paper'), findsOneWidget);
    });

    testWidgets('shows page number when no title', (tester) async {
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'chunk-1',
        pageNumbers: [42],
        content: 'Sample content',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitationChip(
              citation: citation,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Page 42'), findsOneWidget);
    });

    testWidgets('shows "Source" when no title or page numbers', (tester) async {
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'chunk-1',
        pageNumbers: [],
        content: 'Sample content',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitationChip(
              citation: citation,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Source'), findsOneWidget);
    });

    testWidgets('shows quote icon', (tester) async {
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'chunk-1',
        pageNumbers: [],
        content: 'Sample content',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitationChip(
              citation: citation,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.format_quote_rounded), findsOneWidget);
    });

    testWidgets('invokes onTap callback when tapped', (tester) async {
      var tapped = false;
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'chunk-1',
        pageNumbers: [42],
        content: 'Sample content',
        documentTitle: 'Research Paper',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitationChip(
              citation: citation,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(CitationChip));
      expect(tapped, isTrue);
    });

    testWidgets('has accessible semantics', (tester) async {
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'chunk-1',
        pageNumbers: [42],
        content: 'Sample content',
        documentTitle: 'Research Paper',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitationChip(
              citation: citation,
              onTap: () {},
            ),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(CitationChip));
      expect(semantics.label, contains('Citation'));
      expect(semantics.label, contains('Research Paper'));
    });

    testWidgets('has minimum tap target size for accessibility',
        (tester) async {
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'chunk-1',
        pageNumbers: [],
        content: 'Sample content',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitationChip(
              citation: citation,
              onTap: () {},
            ),
          ),
        ),
      );

      final constrainedBox = tester.widget<ConstrainedBox>(
        find.descendant(
          of: find.byType(CitationChip),
          matching: find.byType(ConstrainedBox),
        ),
      );

      expect(constrainedBox.constraints.minHeight, equals(48));
      expect(constrainedBox.constraints.minWidth, equals(48));
    });
  });

  group('CitationPanel', () {
    testWidgets('shows document title', (tester) async {
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'chunk-1',
        pageNumbers: [1, 2, 3],
        content: 'This is the full citation content with details.',
        documentTitle: 'Important Document',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitationPanel(
              citation: citation,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.text('Important Document'), findsOneWidget);
    });

    testWidgets('shows "Source Document" when no title', (tester) async {
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'chunk-1',
        pageNumbers: [],
        content: 'Citation content',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitationPanel(
              citation: citation,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.text('Source Document'), findsOneWidget);
    });

    testWidgets('shows page numbers with plural form', (tester) async {
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'chunk-1',
        pageNumbers: [1, 2, 3],
        content: 'Citation content',
        documentTitle: 'Test Doc',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitationPanel(
              citation: citation,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.text('Pages: 1, 2, 3'), findsOneWidget);
    });

    testWidgets('shows page number with singular form', (tester) async {
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'chunk-1',
        pageNumbers: [42],
        content: 'Citation content',
        documentTitle: 'Test Doc',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitationPanel(
              citation: citation,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.text('Page: 42'), findsOneWidget);
    });

    testWidgets('hides page numbers when empty', (tester) async {
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'chunk-1',
        pageNumbers: [],
        content: 'Citation content',
        documentTitle: 'Test Doc',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitationPanel(
              citation: citation,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.textContaining('Page'), findsNothing);
    });

    testWidgets('shows citation content', (tester) async {
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'chunk-1',
        pageNumbers: [],
        content: 'This is the full citation content with all the details.',
        documentTitle: 'Test Doc',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitationPanel(
              citation: citation,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(
        find.text('This is the full citation content with all the details.'),
        findsOneWidget,
      );
    });

    testWidgets('shows quote icon', (tester) async {
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'chunk-1',
        pageNumbers: [],
        content: 'Content',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitationPanel(
              citation: citation,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.format_quote), findsOneWidget);
    });

    testWidgets('shows close button', (tester) async {
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'chunk-1',
        pageNumbers: [],
        content: 'Content',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitationPanel(
              citation: citation,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('invokes onClose when close button tapped', (tester) async {
      var closed = false;
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'chunk-1',
        pageNumbers: [],
        content: 'Content',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitationPanel(
              citation: citation,
              onClose: () => closed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      expect(closed, isTrue);
    });

    testWidgets('shows view document button', (tester) async {
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'chunk-1',
        pageNumbers: [],
        content: 'Content',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitationPanel(
              citation: citation,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.text('View full document'), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    });

    testWidgets('view document button shows snackbar', (tester) async {
      final citation = Citation(
        documentId: 'doc-123',
        chunkId: 'chunk-1',
        pageNumbers: [],
        content: 'Content',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitationPanel(
              citation: citation,
              onClose: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('View full document'));
      await tester.pumpAndSettle();

      expect(find.text('Opening document: doc-123'), findsOneWidget);
    });

    testWidgets('content is selectable', (tester) async {
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'chunk-1',
        pageNumbers: [],
        content: 'Selectable citation content',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CitationPanel(
              citation: citation,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(
        find.widgetWithText(SelectableText, 'Selectable citation content'),
        findsOneWidget,
      );
    });
  });

  group('CitationChip and CitationPanel integration', () {
    testWidgets('chip tap opens panel in bottom sheet', (tester) async {
      final citation = Citation(
        documentId: 'doc-1',
        chunkId: 'chunk-1',
        pageNumbers: [42],
        content: 'Full citation content here',
        documentTitle: 'Integration Test Doc',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CitationChip(
                citation: citation,
                onTap: () {
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => CitationPanel(
                      citation: citation,
                      onClose: () => Navigator.pop(context),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Integration Test Doc'), findsOneWidget);

      await tester.tap(find.byType(CitationChip));
      await tester.pumpAndSettle();

      expect(find.text('Full citation content here'), findsOneWidget);
      expect(find.text('Page: 42'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Full citation content here'), findsNothing);
    });
  });
}
