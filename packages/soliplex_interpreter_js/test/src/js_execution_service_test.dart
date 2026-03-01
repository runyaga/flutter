import 'package:soliplex_interpreter_js/soliplex_interpreter_js.dart';
import 'package:test/test.dart';

void main() {
  group('JsExecutionService', () {
    late JsExecutionService service;

    setUp(() {
      service = JsExecutionService();
    });

    tearDown(() {
      service.dispose();
    });

    test('executes simple expression and returns value', () async {
      final events = await service.execute('1 + 2').toList();

      expect(events, hasLength(1));
      expect(events.last, isA<ConsoleComplete>());

      final complete = events.last as ConsoleComplete;
      expect(complete.value, '3');
      expect(complete.output, isEmpty);
    });

    test('captures console.log output', () async {
      final events =
          await service.execute('console.log("hello world")').toList();

      expect(events.whereType<ConsoleOutput>(), hasLength(1));

      final output = events.whereType<ConsoleOutput>().first;
      expect(output.text, 'hello world\n');

      final complete = events.whereType<ConsoleComplete>().first;
      expect(complete.output, 'hello world\n');
    });

    test('captures multiple console.log calls', () async {
      final events = await service
          .execute('console.log("a"); console.log("b"); console.log("c")')
          .toList();

      final outputs = events.whereType<ConsoleOutput>().toList();
      expect(outputs, hasLength(3));
      expect(outputs[0].text, 'a\n');
      expect(outputs[1].text, 'b\n');
      expect(outputs[2].text, 'c\n');

      final complete = events.whereType<ConsoleComplete>().first;
      expect(complete.output, 'a\nb\nc\n');
    });

    test('emits ConsoleError on syntax error', () async {
      final events = await service.execute('function {').toList();

      expect(events.last, isA<ConsoleError>());
    });

    test('emits ConsoleError on runtime error', () async {
      final events = await service.execute('throw new Error("boom")').toList();

      expect(events.last, isA<ConsoleError>());
      final error = events.last as ConsoleError;
      expect(error.message, contains('boom'));
    });

    test('throws StateError when disposed', () {
      service.dispose();

      expect(
        () => service.execute('1'),
        throwsA(isA<StateError>()),
      );
    });

    test('throws StateError on concurrent execution', () async {
      // Start first execution (don't await).
      service.execute('1 + 1');

      expect(
        () => service.execute('2 + 2'),
        throwsA(isA<StateError>()),
      );
    });

    test('allows sequential executions', () async {
      final events1 = await service.execute('1 + 1').toList();
      expect(events1.last, isA<ConsoleComplete>());

      final events2 = await service.execute('2 + 2').toList();
      expect(events2.last, isA<ConsoleComplete>());

      final complete = events2.last as ConsoleComplete;
      expect(complete.value, '4');
    });

    test('handles undefined result', () async {
      final events = await service.execute('var x = 5;').toList();

      expect(events.last, isA<ConsoleComplete>());
    });
  });
}
