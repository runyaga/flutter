import 'dart:convert';

import 'package:soliplex_agent/soliplex_agent.dart';

ToolRegistry buildDemoToolRegistry() {
  return const ToolRegistry()
      .register(
        const ClientTool(
          definition: Tool(
            name: 'secret_number',
            description: 'Returns the secret number.',
            parameters: <String, dynamic>{
              'type': 'object',
              'properties': <String, dynamic>{},
            },
          ),
          executor: _secretNumber,
        ),
      )
      .register(
        const ClientTool(
          definition: Tool(
            name: 'echo',
            description: 'Echoes back the text argument.',
            parameters: <String, dynamic>{
              'type': 'object',
              'properties': <String, dynamic>{
                'text': <String, dynamic>{
                  'type': 'string',
                  'description': 'The text to echo back.',
                },
              },
              'required': <String>['text'],
            },
          ),
          executor: _echo,
        ),
      );
}

Future<String> _secretNumber(ToolCallInfo toolCall, _) async => '42';

Future<String> _echo(ToolCallInfo toolCall, _) async {
  if (!toolCall.hasArguments) return '';
  final args = jsonDecode(toolCall.arguments) as Map<String, dynamic>;
  return (args['text'] as String?) ?? '';
}
