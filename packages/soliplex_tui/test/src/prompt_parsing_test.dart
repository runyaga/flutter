import 'package:args/args.dart';
import 'package:test/test.dart';

/// Mirrors the parser config in bin/soliplex_tui.dart for the --prompt option.
ArgParser _buildParser() => ArgParser()
  ..addMultiOption(
    'prompt',
    abbr: 'p',
    splitCommas: false,
    help: 'Send message(s) headless, print each response, and exit. '
        'Repeatable for multi-turn conversations. '
        'Use -p "value" form for multi-line content '
        '(--prompt=value may drop newlines).',
  );

void main() {
  group('prompt flag parsing', () {
    late ArgParser parser;

    setUp(() {
      parser = _buildParser();
    });

    test('single -p produces one prompt', () {
      final results = parser.parse(['-p', 'hello']);
      expect(results.multiOption('prompt'), ['hello']);
    });

    test('multiple -p produces multiple turns', () {
      final results = parser.parse(['-p', 'msg1', '-p', 'msg2']);
      expect(results.multiOption('prompt'), ['msg1', 'msg2']);
    });

    test('commas in -p value are preserved (not split)', () {
      final results = parser.parse(['-p', 'def foo(a, b):']);
      expect(results.multiOption('prompt'), ['def foo(a, b):']);
    });

    test('newlines in -p value are preserved', () {
      final results = parser.parse(['-p', 'line1\nline2\nline3']);
      final prompts = results.multiOption('prompt');
      expect(prompts, hasLength(1));
      expect(prompts.first, contains('\n'));
    });

    test('multi-line code with commas stays as single prompt', () {
      const code = 'def foo(a, b):\n    return a + b\n\nprint(foo(1, 2))';
      final results = parser.parse(['-p', code]);
      final prompts = results.multiOption('prompt');
      expect(prompts, hasLength(1));
      expect(prompts.first, code);
    });

    test('--prompt=value with commas is not split', () {
      final results = parser.parse(['--prompt=a,b,c']);
      expect(results.multiOption('prompt'), ['a,b,c']);
    });
  });
}
