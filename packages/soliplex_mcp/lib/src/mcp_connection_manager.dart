import 'package:mcp_dart/mcp_dart.dart';
import 'package:soliplex_mcp/src/mcp_server_config.dart';

/// Manages lazy-initialized MCP client connections.
///
/// Each server is connected on first use and cached for the session lifetime.
/// Call [dispose] to close all active connections.
///
/// The [executeTool], [listTools], and [listServers] methods match the
/// `McpToolExecutor`, `McpToolLister`, and `McpServerLister` typedefs
/// in `soliplex_scripting`, so they can be passed directly:
///
/// ```dart
/// final manager = McpConnectionManager(serverConfigs: configs);
/// McpPlugin(
///   executor: manager.executeTool,
///   toolLister: manager.listTools,
///   serverLister: manager.listServers,
/// );
/// ```
class McpConnectionManager {
  McpConnectionManager({required this.serverConfigs});

  /// Server ID -> configuration.
  final Map<String, McpServerConfig> serverConfigs;

  final Map<String, McpClient> _activeClients = {};

  Future<McpClient> _getClient(String serverId) async {
    final existing = _activeClients[serverId];
    if (existing != null) return existing;

    final config = serverConfigs[serverId];
    if (config == null) {
      throw ArgumentError('Unknown MCP server: $serverId');
    }

    final client = McpClient(
      const Implementation(name: 'soliplex-mcp', version: '0.1.0'),
    );

    final transport = switch (config.kind) {
      McpTransportKind.stdio => StdioClientTransport(
          StdioServerParameters(
            command: config.command!,
            args: config.args,
          ),
        ),
      McpTransportKind.http => StreamableHttpClientTransport(
          Uri.parse(config.url!),
        ),
    };

    await client.connect(transport);
    _activeClients[serverId] = client;
    return client;
  }

  /// Execute a tool on the named MCP server.
  ///
  /// Matches the `McpToolExecutor` typedef signature.
  Future<Map<String, Object?>> executeTool(
    String serverId,
    String toolName,
    Map<String, Object?> args,
  ) async {
    final client = await _getClient(serverId);
    final result = await client.callTool(
      CallToolRequest(name: toolName, arguments: args),
    );
    return {
      'isError': result.isError,
      'content': result.content
          .map((c) => c is TextContent ? c.text : c.toString())
          .toList(),
    };
  }

  /// List available tools, optionally filtered by server.
  ///
  /// Matches the `McpToolLister` typedef signature.
  Future<List<Map<String, Object?>>> listTools({String? serverId}) async {
    final ids = serverId != null ? [serverId] : serverConfigs.keys.toList();
    final allTools = <Map<String, Object?>>[];
    for (final id in ids) {
      final client = await _getClient(id);
      final result = await client.listTools();
      for (final tool in result.tools) {
        allTools.add({
          'server': id,
          'name': tool.name,
          'description': tool.description ?? '',
        });
      }
    }
    return allTools;
  }

  /// List all configured MCP servers with connection status.
  ///
  /// Matches the `McpServerLister` typedef signature.
  Future<List<Map<String, Object?>>> listServers() async {
    return serverConfigs.entries
        .map(
          (e) => <String, Object?>{
            'id': e.key,
            'kind': e.value.kind.name,
            'status': _activeClients.containsKey(e.key)
                ? 'connected'
                : 'disconnected',
          },
        )
        .toList();
  }

  /// Close all active MCP client connections.
  Future<void> dispose() async {
    final clients = List.of(_activeClients.values);
    _activeClients.clear();
    for (final client in clients) {
      await client.close();
    }
  }
}
