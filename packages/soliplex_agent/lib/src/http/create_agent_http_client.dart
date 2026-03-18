import 'package:soliplex_client/soliplex_client.dart';

/// Creates an HTTP client for agent connections with optional observability.
///
/// When [observers] is non-null and non-empty, wraps the client in an
/// observable layer that notifies each observer of HTTP activity.
///
/// [innerClient] defaults to a [DartHttpClient] when not provided.
/// For platform-specific clients, pass one from `soliplex_client_native`.
///
/// The caller owns the returned client and must call `close()` when done.
/// Closing cascades through the entire decorator stack.
SoliplexHttpClient createAgentHttpClient({
  SoliplexHttpClient? innerClient,
  List<HttpObserver>? observers,
}) {
  final client = innerClient ?? DartHttpClient();

  if (observers != null && observers.isNotEmpty) {
    return ObservableHttpClient(client: client, observers: observers);
  }

  return client;
}
