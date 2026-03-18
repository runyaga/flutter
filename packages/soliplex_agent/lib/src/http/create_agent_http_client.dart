import 'package:soliplex_client/soliplex_client.dart';

/// Creates an HTTP client for agent connections with optional observability
/// and authentication.
///
/// Layers are applied inside-out in this order:
/// 1. [innerClient] (or `DartHttpClient()` by default)
/// 2. [ObservableHttpClient] — when [observers] is non-empty
/// 3. [AuthenticatedHttpClient] — when [getToken] is provided
/// 4. [RefreshingHttpClient] — when [tokenRefresher] is provided
///
/// Observer is innermost so the network inspector sees what actually hits
/// the wire, including Bearer headers and retried requests after refresh.
///
/// [innerClient] defaults to a [DartHttpClient] when not provided.
/// For platform-specific clients, pass one from `soliplex_client_native`.
///
/// [tokenRefresher] requires [getToken] — without token injection, refresh
/// retries go out unauthenticated.
///
/// The caller owns the returned client and must call `close()` when done.
/// Closing cascades through the entire decorator stack.
SoliplexHttpClient createAgentHttpClient({
  SoliplexHttpClient? innerClient,
  List<HttpObserver>? observers,
  String? Function()? getToken,
  TokenRefresher? tokenRefresher,
}) {
  assert(
    tokenRefresher == null || getToken != null,
    'tokenRefresher requires getToken to inject refreshed tokens',
  );

  var client = innerClient ?? DartHttpClient();

  if (observers != null && observers.isNotEmpty) {
    client = ObservableHttpClient(client: client, observers: observers);
  }

  if (getToken != null) {
    client = AuthenticatedHttpClient(client, getToken);
  }

  if (tokenRefresher != null) {
    client = RefreshingHttpClient(inner: client, refresher: tokenRefresher);
  }

  return client;
}
