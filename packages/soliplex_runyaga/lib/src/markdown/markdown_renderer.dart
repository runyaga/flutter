import 'package:flutter/widgets.dart';

import 'markdown_block_extension.dart';

/// Handler for link taps in markdown content.
typedef MarkdownLinkHandler = void Function(String href, String? title);

/// Handler for image taps in markdown content.
typedef MarkdownImageHandler = void Function(String src, String? alt);

/// Renders markdown text as Flutter widgets.
///
/// Forked from soliplex_frontend for steampunk customization.
abstract class MarkdownRenderer extends StatelessWidget {
  const MarkdownRenderer({
    required this.data,
    this.onLinkTap,
    this.onImageTap,
    this.blockExtensions = const {},
    super.key,
  });

  final String data;
  final MarkdownLinkHandler? onLinkTap;
  final MarkdownImageHandler? onImageTap;
  final Map<String, MarkdownBlockExtension> blockExtensions;
}
