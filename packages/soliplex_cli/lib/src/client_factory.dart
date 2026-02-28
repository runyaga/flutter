import 'package:soliplex_client/soliplex_client.dart';

typedef ClientBundle = ({
  SoliplexApi api,
  AgUiClient agUiClient,
  void Function() close,
});

ClientBundle createClients(String host) {
  final baseUrl = '$host/api/v1';

  final apiHttpClient = DartHttpClient();
  final sseHttpClient = DartHttpClient();

  final transport = HttpTransport(client: apiHttpClient);
  final urlBuilder = UrlBuilder(baseUrl);

  final api = SoliplexApi(
    transport: transport,
    urlBuilder: urlBuilder,
  );

  final agUiClient = AgUiClient(
    config: AgUiClientConfig(baseUrl: baseUrl),
    httpClient: HttpClientAdapter(client: sseHttpClient),
  );

  return (
    api: api,
    agUiClient: agUiClient,
    close: () {
      apiHttpClient.close();
      sseHttpClient.close();
    },
  );
}
