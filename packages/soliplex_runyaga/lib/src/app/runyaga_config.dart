/// Configuration for the Boiler Room client.
class RunyagaConfig {
  const RunyagaConfig({
    this.defaultBaseUrl = 'https://demo.toughserv.com',
    this.appTitle = 'THE BOILER ROOM',
  });

  /// Default backend URL (no auth mode).
  final String defaultBaseUrl;

  /// Title shown in the header.
  final String appTitle;
}
