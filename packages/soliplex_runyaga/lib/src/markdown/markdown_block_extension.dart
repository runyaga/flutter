import 'package:flutter/widgets.dart';

/// Defines a custom markdown block type that renders as a native widget.
///
/// Forked from soliplex_frontend for steampunk customization.
class MarkdownBlockExtension {
  const MarkdownBlockExtension({
    required this.pattern,
    required this.tag,
    required this.builder,
    this.endPattern,
  });

  final RegExp pattern;
  final RegExp? endPattern;
  final String tag;
  final Widget Function(String content, Map<String, String> attributes) builder;
}
