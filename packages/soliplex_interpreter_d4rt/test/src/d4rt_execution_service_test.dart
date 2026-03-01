import 'package:soliplex_interpreter_d4rt/soliplex_interpreter_d4rt.dart';
import 'package:test/test.dart';

void main() {
  group('D4rtExecutionService', () {
    late D4rtExecutionService service;

    setUp(() {
      service = D4rtExecutionService();
    });

    tearDown(() => service.dispose());

    test('executes simple expression and returns result', () async {
      final events = await service.execute('''
            int add(int a, int b) => a + b;
            main() {
              return add(2, 3);
            }
          ''').toList();

      expect(events, hasLength(1));
      expect(events.last, isA<ConsoleComplete>());
      final complete = events.last as ConsoleComplete;
      expect(complete.value, '5');
    });

    test('captures print output as ConsoleOutput events', () async {
      final events = await service.execute('''
            main() {
              print('hello');
              print('world');
            }
          ''').toList();

      // Two ConsoleOutput events + one ConsoleComplete.
      final outputs =
          events.whereType<ConsoleOutput>().map((e) => e.text).toList();
      expect(outputs, hasLength(2));
      expect(outputs[0], contains('hello'));
      expect(outputs[1], contains('world'));

      final complete = events.whereType<ConsoleComplete>().single;
      expect(complete.output, contains('hello'));
      expect(complete.output, contains('world'));
    });

    test('emits ConsoleError on syntax error', () async {
      final events = await service.execute('main() { @@@ }').toList();

      expect(events.last, isA<ConsoleError>());
    });

    test('emits ConsoleError on runtime error', () async {
      final events = await service.execute('''
            main() {
              throw Exception('boom');
            }
          ''').toList();

      expect(events.last, isA<ConsoleError>());
      final error = events.last as ConsoleError;
      expect(error.message, contains('boom'));
    });

    test('wraps code without main in a main function', () async {
      final events = await service.execute('''
            print('auto-wrapped');
          ''').toList();

      final outputs = events.whereType<ConsoleOutput>().toList();
      expect(outputs, isNotEmpty);
      expect(outputs.first.text, contains('auto-wrapped'));
    });

    test('throws StateError when executing while already running', () {
      // Start an execution (it runs async internally).
      service.execute('main() {}');

      expect(
        () => service.execute('main() {}'),
        throwsStateError,
      );
    });

    test('throws StateError after dispose', () {
      service.dispose();

      expect(
        () => service.execute('main() {}'),
        throwsStateError,
      );
    });
  });
}
