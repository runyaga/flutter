import 'package:mcp_dart/mcp_dart.dart';
import 'package:soliplex_mcp/src/mcp_server_config.dart';

/// Web transport factory — only HTTP is supported.
Transport createTransport(McpServerConfig config) {
  return switch (config.kind) {
    McpTransportKind.stdio => throw UnsupportedError(
        'Stdio MCP transport is not available on web/WASM. '
        'Use McpTransportKind.http instead.',
      ),
    McpTransportKind.http => StreamableHttpClientTransport(
        Uri.parse(config.url!),
      ),
  };
}
