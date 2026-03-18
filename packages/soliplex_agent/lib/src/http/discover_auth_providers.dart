import 'package:soliplex_client/soliplex_client.dart';

/// Fetches available authentication providers from a Soliplex server.
///
/// Wraps the underlying discovery call so consumers don't need to create
/// an [HttpTransport] directly.
///
/// [serverUrl] is the backend base URL (e.g., `https://api.example.com`).
/// [httpClient] should come from `createAgentHttpClient` — valid with or
/// without auth parameters.
Future<List<AuthProviderConfig>> discoverAuthProviders({
  required Uri serverUrl,
  required SoliplexHttpClient httpClient,
}) {
  final transport = HttpTransport(client: httpClient);
  return fetchAuthProviders(transport: transport, baseUrl: serverUrl);
}
