import 'package:soliplex_showcase/soliplex_showcase.dart';
import 'package:test/test.dart';

void main() {
  group('ShowcaseDemoRegistry', () {
    test('has exactly 12 demos', () {
      expect(ShowcaseDemoRegistry.demos, hasLength(12));
    });

    test('all demos have non-empty steps', () {
      for (final demo in ShowcaseDemoRegistry.demos) {
        expect(
          demo.steps,
          isNotEmpty,
          reason: '${demo.name} should have steps',
        );
      }
    });

    test('all steps have non-empty code', () {
      for (final demo in ShowcaseDemoRegistry.demos) {
        for (final step in demo.steps) {
          expect(
            step.code.trim(),
            isNotEmpty,
            reason: '${demo.name} > ${step.title} should have code',
          );
        }
      }
    });

    test('all demos have non-empty name and description', () {
      for (final demo in ShowcaseDemoRegistry.demos) {
        expect(demo.name, isNotEmpty);
        expect(demo.description, isNotEmpty);
      }
    });

    test('all steps have non-empty title and narration', () {
      for (final demo in ShowcaseDemoRegistry.demos) {
        for (final step in demo.steps) {
          expect(
            step.title,
            isNotEmpty,
            reason: '${demo.name} step should have title',
          );
          expect(
            step.narration,
            isNotEmpty,
            reason: '${demo.name} step should have narration',
          );
        }
      }
    });

    test('demo names match expected list', () {
      final names = ShowcaseDemoRegistry.demos.map((d) => d.name).toList();
      expect(names, [
        'Error Recovery',
        'DataFrame → Chart',
        'Scatter Plot',
        'Multi-Step Analysis',
        'Fake Streaming Gauges',
        'Stream Gauges',
        'Pie Chart',
        'Radar Chart',
        'Heatmap',
        'Drawing Recognition',
        'Form Validation',
        'Tic-Tac-Toe',
      ]);
    });
  });
}
