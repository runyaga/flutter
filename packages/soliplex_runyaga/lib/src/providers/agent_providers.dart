import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client_native/soliplex_client_native.dart';

/// Base URL for the backend, set on connect.
final baseUrlProvider = NotifierProvider<_BaseUrl, String>(_BaseUrl.new);

class _BaseUrl extends Notifier<String> {
  @override
  String build() => 'https://demo.toughserv.com';

  void set(String url) => state = url;
}

/// Raw HTTP client (platform-specific, no auth needed).
final httpClientProvider = Provider<http.Client>((ref) {
  final client = HttpClientAdapter(client: createPlatformClient());
  ref.onDispose(client.close);
  return client;
});

/// HTTP transport layer.
final httpTransportProvider = Provider<HttpTransport>((ref) {
  final client = createPlatformClient();
  ref.onDispose(client.close);
  return HttpTransport(client: client);
});

/// URL builder derived from base URL.
final urlBuilderProvider = Provider<UrlBuilder>((ref) {
  final baseUrl = ref.watch(baseUrlProvider);
  return UrlBuilder('$baseUrl/api/v1');
});

/// The SoliplexApi instance — main communication interface.
final apiProvider = Provider<SoliplexApi>((ref) {
  final transport = ref.watch(httpTransportProvider);
  final urlBuilder = ref.watch(urlBuilderProvider);
  return SoliplexApi(transport: transport, urlBuilder: urlBuilder);
});

/// AG-UI client for streaming events.
final agUiClientProvider = Provider<AgUiClient>((ref) {
  final httpClient = ref.watch(httpClientProvider);
  final baseUrl = ref.watch(baseUrlProvider);
  final client = AgUiClient(
    config: AgUiClientConfig(
      baseUrl: '$baseUrl/api/v1',
      requestTimeout: const Duration(seconds: 600),
      connectionTimeout: const Duration(seconds: 600),
    ),
    httpClient: httpClient,
  );
  ref.onDispose(client.close);
  return client;
});
