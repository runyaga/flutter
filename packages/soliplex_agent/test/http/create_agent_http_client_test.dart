import 'package:mocktail/mocktail.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_client/soliplex_client.dart'
    show DartHttpClient, ObservableHttpClient;
import 'package:test/test.dart';

class _MockHttpClient extends Mock implements SoliplexHttpClient {}

class _MockObserver extends Mock implements HttpObserver {}

void main() {
  group('createAgentHttpClient', () {
    test('no args returns a DartHttpClient', () {
      final client = createAgentHttpClient();
      addTearDown(client.close);
      expect(client, isA<DartHttpClient>());
    });

    test('with innerClient uses the provided client', () {
      final inner = _MockHttpClient();
      final client = createAgentHttpClient(innerClient: inner);
      expect(client, same(inner));
    });

    test('with observers wraps in ObservableHttpClient', () {
      final observer = _MockObserver();
      final client = createAgentHttpClient(observers: [observer]);
      addTearDown(client.close);
      expect(client, isA<ObservableHttpClient>());
    });

    test('with empty observers does not wrap', () {
      final client = createAgentHttpClient(observers: <HttpObserver>[]);
      addTearDown(client.close);
      expect(client, isA<DartHttpClient>());
    });

    test('with innerClient and observers wraps provided client', () {
      final inner = _MockHttpClient();
      final observer = _MockObserver();
      final client = createAgentHttpClient(
        innerClient: inner,
        observers: [observer],
      );
      addTearDown(client.close);
      expect(client, isA<ObservableHttpClient>());
    });

    test('close cascades through decorator stack', () {
      final inner = _MockHttpClient();
      createAgentHttpClient(
        innerClient: inner,
        observers: [_MockObserver()],
      ).close();
      verify(inner.close).called(1);
    });
  });
}
