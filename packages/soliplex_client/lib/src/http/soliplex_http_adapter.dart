import 'package:http/http.dart' as http;
import 'package:soliplex_client/src/http/soliplex_http_client.dart';

/// Bridges [SoliplexHttpClient] to [http.BaseClient] so that third-party
/// packages (like `open_responses`) can use the full Soliplex HTTP
/// decorator chain (logging, auth, platform adapters, cancellation).
class SoliplexHttpAdapter extends http.BaseClient {
  /// Creates an adapter wrapping the given client.
  SoliplexHttpAdapter(this._client);

  final SoliplexHttpClient _client;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bodyBytes = await request.finalize().toBytes();
    final body = bodyBytes.isNotEmpty ? bodyBytes : null;

    final response = await _client.requestStream(
      request.method,
      request.url,
      headers: request.headers,
      body: body,
    );

    return http.StreamedResponse(
      response.body,
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}
