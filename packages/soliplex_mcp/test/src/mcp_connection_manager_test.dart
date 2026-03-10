import 'package:soliplex_mcp/soliplex_mcp.dart';
import 'package:test/test.dart';

void main() {
  group('McpConnectionManager', () {
    test('constructs with server configs', () {
      final manager = McpConnectionManager(
        serverConfigs: {
          'fs': const McpServerConfig.stdio(
            command: 'npx',
            args: ['-y', '@modelcontextprotocol/server-filesystem', '/tmp'],
          ),
          'api': const McpServerConfig.http(url: 'http://localhost:3000'),
        },
      );

      expect(manager.serverConfigs, hasLength(2));
    });

    test('listServers returns all configs with disconnected status', () async {
      final manager = McpConnectionManager(
        serverConfigs: {
          'fs': const McpServerConfig.stdio(command: 'node'),
          'api': const McpServerConfig.http(url: 'http://localhost:3000'),
        },
      );

      final servers = await manager.listServers();
      expect(servers, hasLength(2));

      final fs = servers.firstWhere((s) => s['id'] == 'fs');
      expect(fs['kind'], 'stdio');
      expect(fs['status'], 'disconnected');

      final api = servers.firstWhere((s) => s['id'] == 'api');
      expect(api['kind'], 'http');
      expect(api['status'], 'disconnected');
    });

    test('executeTool throws for unknown server', () async {
      final manager = McpConnectionManager(serverConfigs: {});

      expect(
        () => manager.executeTool('unknown', 'tool', {}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('listTools throws for unknown server', () async {
      final manager = McpConnectionManager(serverConfigs: {});

      expect(
        () => manager.listTools(serverId: 'unknown'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('dispose is safe on empty manager', () async {
      final manager = McpConnectionManager(serverConfigs: {});
      await manager.dispose();
    });
  });
}
