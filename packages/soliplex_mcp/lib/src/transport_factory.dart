import 'package:mcp_dart/mcp_dart.dart';
import 'package:soliplex_mcp/src/mcp_server_config.dart';

import 'package:soliplex_mcp/src/transport_factory_native.dart'
    if (dart.library.js_interop) 'package:soliplex_mcp/src/transport_factory_web.dart'
    as platform;

/// Creates an MCP transport for the given server config.
///
/// On native platforms, both stdio and HTTP transports are available.
/// On web/WASM, only HTTP transport is supported — stdio throws
/// [UnsupportedError].
Transport createTransport(McpServerConfig config) =>
    platform.createTransport(config);
