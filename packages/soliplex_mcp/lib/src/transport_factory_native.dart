import 'package:mcp_dart/mcp_dart.dart';
import 'package:soliplex_mcp/src/mcp_server_config.dart';

/// Native transport factory — supports both stdio and HTTP.
Transport createTransport(McpServerConfig config) {
  return switch (config.kind) {
    McpTransportKind.stdio => StdioClientTransport(
        StdioServerParameters(
          command: config.command!,
          args: config.args,
          environment: config.environment,
        ),
      ),
    McpTransportKind.http => StreamableHttpClientTransport(
        Uri.parse(config.url!),
      ),
  };
}
