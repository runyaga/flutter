/// A single step in a showcase demo.
class ShowcaseDemoStep {
  /// Creates a demo step.
  const ShowcaseDemoStep({
    required this.title,
    required this.narration,
    required this.code,
    this.expectsError = false,
  });

  /// Human-readable step title, e.g. "Step 1: Create DataFrame".
  final String title;

  /// Narrator text explaining what this step demonstrates.
  final String narration;

  /// Python source code to execute.
  final String code;

  /// If `true`, the step is expected to produce an error.
  final bool expectsError;
}
