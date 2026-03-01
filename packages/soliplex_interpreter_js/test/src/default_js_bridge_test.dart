import 'package:soliplex_interpreter_js/soliplex_interpreter_js.dart';
import 'package:test/test.dart';

void main() {
  group('DefaultJsBridge', () {
    late DefaultJsBridge bridge;

    setUp(() {
      bridge = DefaultJsBridge();
    });

    tearDown(() {
      bridge.dispose();
    });

    group('lifecycle events', () {
      test('emits RunStarted and RunFinished for simple code', () async {
        final events = await bridge.execute('1 + 1').toList();

        expect(events.first, isA<BridgeRunStarted>());
        expect(events.last, isA<BridgeRunFinished>());
      });

      test('emits RunError on syntax error', () async {
        final events = await bridge.execute('function {').toList();

        expect(events.first, isA<BridgeRunStarted>());
        expect(events.last, isA<BridgeRunError>());
      });

      test('emits RunError on thrown error', () async {
        final events = await bridge.execute('throw new Error("boom")').toList();

        expect(events.first, isA<BridgeRunStarted>());
        expect(events.last, isA<BridgeRunError>());

        final error = events.last as BridgeRunError;
        expect(error.message, contains('boom'));
      });
    });

    group('output capture', () {
      test('captures console.log as text events', () async {
        final events = await bridge.execute('console.log("hello")').toList();

        final textStarts = events.whereType<BridgeTextStart>();
        final textContents = events.whereType<BridgeTextContent>();
        final textEnds = events.whereType<BridgeTextEnd>();

        expect(textStarts, hasLength(1));
        expect(textContents, hasLength(1));
        expect(textEnds, hasLength(1));

        expect(textContents.first.delta, contains('hello'));
      });

      test('captures multiple console.log calls', () async {
        final events =
            await bridge.execute('console.log("a"); console.log("b")').toList();

        final textContents = events.whereType<BridgeTextContent>();
        expect(textContents, hasLength(1));

        final delta = textContents.first.delta;
        expect(delta, contains('a'));
        expect(delta, contains('b'));
      });

      test('no text events when no console output', () async {
        final events = await bridge.execute('1 + 1').toList();

        expect(events.whereType<BridgeTextStart>(), isEmpty);
        expect(events.whereType<BridgeTextContent>(), isEmpty);
        expect(events.whereType<BridgeTextEnd>(), isEmpty);
      });
    });

    group('host function dispatch', () {
      test('calls host function and emits tool call events', () async {
        bridge.register(
          HostFunction(
            schema: const HostFunctionSchema(
              name: 'greet',
              description: 'Greets a person',
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

        final events = await bridge.execute('greet("World")').toList();

        final starts = events.whereType<BridgeToolCallStart>().toList();
        expect(starts, hasLength(1));
        expect(starts.first.toolCallName, 'greet');

        final results = events.whereType<BridgeToolCallResult>().toList();
        expect(results, hasLength(1));
        expect(results.first.content, 'Hello, World!');

        final steps = events.whereType<BridgeStepStarted>().toList();
        expect(steps, hasLength(1));
        expect(steps.first.stepName, 'greet');

        final stepEnds = events.whereType<BridgeStepFinished>().toList();
        expect(stepEnds, hasLength(1));
      });

      test('maps positional args to named params', () async {
        Map<String, Object?>? capturedArgs;

        bridge.register(
          HostFunction(
            schema: const HostFunctionSchema(
              name: 'add',
              description: 'Adds two numbers',
              params: [
                HostParam(name: 'a', type: HostParamType.number),
                HostParam(name: 'b', type: HostParamType.number),
              ],
            ),
            handler: (args) async {
              capturedArgs = args;
              return (args['a']! as num) + (args['b']! as num);
            },
          ),
        );

        await bridge.execute('add(3, 4)').toList();

        expect(capturedArgs, isNotNull);
        expect(capturedArgs!['a'], 3);
        expect(capturedArgs!['b'], 4);
      });

      test('emits tool call args as JSON', () async {
        bridge.register(
          HostFunction(
            schema: const HostFunctionSchema(
              name: 'echo',
              description: 'Echoes input',
              params: [
                HostParam(name: 'msg', type: HostParamType.string),
              ],
            ),
            handler: (args) async => args['msg'],
          ),
        );

        final events = await bridge.execute('echo("test")').toList();

        final toolCallArgs = events.whereType<BridgeToolCallArgs>().toList();
        expect(toolCallArgs, hasLength(1));
        expect(toolCallArgs.first.delta, contains('"msg"'));
        expect(toolCallArgs.first.delta, contains('"test"'));
      });

      test('handles host function error gracefully', () async {
        bridge.register(
          HostFunction(
            schema: const HostFunctionSchema(
              name: 'fail',
              description: 'Always fails',
              params: [
                HostParam(name: 'x', type: HostParamType.integer),
              ],
            ),
            handler: (args) async => throw Exception('handler error'),
          ),
        );

        // Passing a string where int is expected triggers validation error.
        final events = await bridge.execute('fail("not_an_int")').toList();

        final results = events.whereType<BridgeToolCallResult>().toList();
        expect(results, hasLength(1));
        expect(results.first.content, contains('Error'));
      });

      test('return value from host function is usable in JS', () async {
        bridge.register(
          HostFunction(
            schema: const HostFunctionSchema(
              name: 'get_value',
              description: 'Returns a number',
            ),
            handler: (args) async => 42,
          ),
        );

        final events = await bridge
            .execute('var x = get_value(); console.log(x)')
            .toList();

        final textContent = events.whereType<BridgeTextContent>();
        expect(textContent, hasLength(1));
        expect(textContent.first.delta, contains('42'));
      });
    });

    group('registration', () {
      test('schemas returns registered function schemas', () {
        bridge.register(
          HostFunction(
            schema: const HostFunctionSchema(
              name: 'foo',
              description: 'Foo',
            ),
            handler: (args) async => null,
          ),
        );

        expect(bridge.schemas, hasLength(1));
        expect(bridge.schemas.first.name, 'foo');
      });

      test('unregister removes function', () {
        bridge
          ..register(
            HostFunction(
              schema: const HostFunctionSchema(
                name: 'bar',
                description: 'Bar',
              ),
              handler: (args) async => null,
            ),
          )
          ..unregister('bar');
        expect(bridge.schemas, isEmpty);
      });

      test('throws StateError when registering after dispose', () {
        bridge.dispose();

        expect(
          () => bridge.register(
            HostFunction(
              schema: const HostFunctionSchema(
                name: 'x',
                description: 'x',
              ),
              handler: (args) async => null,
            ),
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('error propagation', () {
      test('reference error in JS emits RunError', () async {
        final events = await bridge.execute('nonExistentVar').toList();

        expect(events.last, isA<BridgeRunError>());
      });

      test('type error in JS emits RunError', () async {
        final events = await bridge.execute('null.property').toList();

        expect(events.last, isA<BridgeRunError>());
      });
    });
  });
}
