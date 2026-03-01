import 'package:soliplex_interpreter_d4rt/soliplex_interpreter_d4rt.dart';
import 'package:test/test.dart';

void main() {
  group('DefaultD4rtBridge', () {
    late DefaultD4rtBridge bridge;

    setUp(() {
      bridge = DefaultD4rtBridge();
    });

    tearDown(() => bridge.dispose());

    group('basic execution', () {
      test('emits RunStarted and RunFinished for simple code', () async {
        final events = await bridge.execute('''
              main() {
                return 42;
              }
            ''').toList();

        expect(events.first, isA<BridgeRunStarted>());
        expect(events.last, isA<BridgeRunFinished>());
      });

      test('captures print output as text events', () async {
        final events = await bridge.execute('''
              main() {
                print('hello from d4rt');
              }
            ''').toList();

        final textContents = events.whereType<BridgeTextContent>().toList();
        expect(textContents, isNotEmpty);
        expect(textContents.first.delta, contains('hello from d4rt'));

        // Text events should be wrapped in Start/End.
        final textStarts = events.whereType<BridgeTextStart>().toList();
        final textEnds = events.whereType<BridgeTextEnd>().toList();
        expect(textStarts, hasLength(1));
        expect(textEnds, hasLength(1));
      });

      test('emits RunError on syntax error', () async {
        final events = await bridge.execute('main() { @@@ }').toList();

        expect(events.first, isA<BridgeRunStarted>());
        expect(events.last, isA<BridgeRunError>());
      });

      test('emits RunError on runtime exception', () async {
        final events = await bridge.execute('''
              main() {
                throw Exception('kaboom');
              }
            ''').toList();

        final error = events.whereType<BridgeRunError>().single;
        expect(error.message, contains('kaboom'));
      });
    });

    group('host function dispatch', () {
      test('dispatches host function call and buffers tool events', () async {
        bridge.register(
          HostFunction(
            schema: const HostFunctionSchema(
              name: 'greet',
              description: 'Returns a greeting',
              params: [
                HostParam(
                  name: 'name',
                  type: HostParamType.string,
                ),
              ],
            ),
            handler: (args) async => 'Hello, ${args['name']}!',
          ),
        );

        final events = await bridge.execute('''
              main() {
                greet('World');
              }
            ''').toList();

        // Should contain tool call event sequence.
        final stepStarts = events.whereType<BridgeStepStarted>().toList();
        final toolStarts = events.whereType<BridgeToolCallStart>().toList();
        final toolArgs = events.whereType<BridgeToolCallArgs>().toList();
        final toolEnds = events.whereType<BridgeToolCallEnd>().toList();
        final toolResults = events.whereType<BridgeToolCallResult>().toList();
        final stepFinishes = events.whereType<BridgeStepFinished>().toList();

        expect(stepStarts, hasLength(1));
        expect(toolStarts, hasLength(1));
        expect(toolArgs, hasLength(1));
        expect(toolEnds, hasLength(1));
        expect(toolResults, hasLength(1));
        expect(stepFinishes, hasLength(1));

        expect(toolStarts.first.toolCallName, 'greet');
        expect(toolArgs.first.delta, contains('World'));
      });

      test('handles multiple host function calls', () async {
        bridge
          ..register(
            HostFunction(
              schema: const HostFunctionSchema(
                name: 'add',
                description: 'Adds two numbers',
                params: [
                  HostParam(name: 'a', type: HostParamType.integer),
                  HostParam(name: 'b', type: HostParamType.integer),
                ],
              ),
              handler: (args) async {
                final a = args['a']! as int;
                final b = args['b']! as int;

                return a + b;
              },
            ),
          )
          ..register(
            HostFunction(
              schema: const HostFunctionSchema(
                name: 'multiply',
                description: 'Multiplies two numbers',
                params: [
                  HostParam(name: 'a', type: HostParamType.integer),
                  HostParam(name: 'b', type: HostParamType.integer),
                ],
              ),
              handler: (args) async {
                final a = args['a']! as int;
                final b = args['b']! as int;

                return a * b;
              },
            ),
          );

        final events = await bridge.execute('''
              main() {
                add(2, 3);
                multiply(4, 5);
              }
            ''').toList();

        final toolStarts = events.whereType<BridgeToolCallStart>().toList();
        expect(toolStarts, hasLength(2));
        expect(toolStarts[0].toolCallName, 'add');
        expect(toolStarts[1].toolCallName, 'multiply');
      });

      test(
        'emits error tool result on param validation failure',
        () async {
          bridge.register(
            HostFunction(
              schema: const HostFunctionSchema(
                name: 'strict_fn',
                description: 'Requires a string',
                params: [
                  HostParam(name: 'value', type: HostParamType.string),
                ],
              ),
              handler: (args) async => args['value'],
            ),
          );

          // Calling with an int instead of a string.
          final events = await bridge.execute('''
                main() {
                  strict_fn(42);
                }
              ''').toList();

          final results = events.whereType<BridgeToolCallResult>().toList();
          expect(results, hasLength(1));
          expect(results.first.content, contains('Error'));
        },
      );
    });

    group('register / unregister', () {
      test('schemas returns registered function schemas', () {
        bridge.register(
          HostFunction(
            schema: const HostFunctionSchema(
              name: 'test_fn',
              description: 'A test function',
            ),
            handler: (args) async => null,
          ),
        );

        expect(bridge.schemas, hasLength(1));
        expect(bridge.schemas.first.name, 'test_fn');
      });

      test('unregister removes function from schemas', () {
        bridge
          ..register(
            HostFunction(
              schema: const HostFunctionSchema(
                name: 'removable',
                description: 'Will be removed',
              ),
              handler: (args) async => null,
            ),
          )
          ..unregister('removable');
        expect(bridge.schemas, isEmpty);
      });

      test('throws StateError after dispose', () {
        bridge.dispose();

        expect(
          () => bridge.register(
            HostFunction(
              schema: const HostFunctionSchema(
                name: 'fn',
                description: 'fn',
              ),
              handler: (args) async => null,
            ),
          ),
          throwsStateError,
        );
      });
    });

    group('error propagation', () {
      test('wraps interpreter exceptions in BridgeRunError', () async {
        final events = await bridge.execute('''
              main() {
                var x = null;
                x.nonExistentMethod();
              }
            ''').toList();

        expect(events.first, isA<BridgeRunStarted>());
        expect(events.last, isA<BridgeRunError>());
      });
    });
  });
}
