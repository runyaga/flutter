import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../design/tokens/colors.dart';
import '../design/tokens/typography.dart';

/// Inline code: styled span with industrial background.
class InlineCodeBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: BoilerColors.codeBackground,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: BoilerColors.border, width: 0.5),
      ),
      child: Text(
        element.textContent,
        style: preferredStyle?.copyWith(backgroundColor: Colors.transparent),
      ),
    );
  }
}

/// Fenced code blocks with riveted steel frame and syntax highlighting.
class CodeBlockBuilder extends MarkdownElementBuilder {
  CodeBlockBuilder({required this.preferredStyle});

  final TextStyle preferredStyle;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final code = element.textContent;
    final language = _languageFrom(element);

    return Semantics(
      label: language == 'plaintext' ? 'Code block' : 'Code block in $language',
      child: _BoilerCodeBlock(
        code: code,
        language: language,
        codeStyle: this.preferredStyle,
      ),
    );
  }

  static String _languageFrom(md.Element pre) {
    final children = pre.children;
    if (children != null) {
      for (final child in children) {
        if (child is md.Element && child.tag == 'code') {
          final className = child.attributes['class'];
          if (className != null && className.startsWith('language-')) {
            return className.replaceFirst('language-', '');
          }
        }
      }
    }
    return 'plaintext';
  }
}

/// Steel-framed code block with rivet decorations.
class _BoilerCodeBlock extends StatelessWidget {
  const _BoilerCodeBlock({
    required this.code,
    required this.language,
    required this.codeStyle,
  });

  final String code;
  final String language;
  final TextStyle codeStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BoilerColors.codeBackground,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: BoilerColors.border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header bar with language label + copy button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: const BoxDecoration(
              color: BoilerColors.surface,
              border: Border(
                bottom: BorderSide(color: BoilerColors.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                if (language != 'plaintext')
                  Text(
                    language.toUpperCase(),
                    style: BoilerTypography.barlowCondensed(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: BoilerColors.furnaceOrange,
                    ),
                  ),
                const Spacer(),
                Tooltip(
                  message: 'Copy code',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(2),
                    onTap: () => _copy(context),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(
                        Icons.copy,
                        size: 14,
                        color: BoilerColors.iron,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Code content
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: HighlightView(
              code,
              language: language,
              theme: monokaiSublimeTheme,
              padding: EdgeInsets.zero,
              textStyle: codeStyle,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }
}
