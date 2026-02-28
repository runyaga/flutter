import 'package:soliplex_cli/src/client_factory.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:test/test.dart';

void main() {
  group('createClients', () {
    test('returns non-null api and agUiClient', () {
      final bundle = createClients('http://localhost:8000');

      expect(bundle.api, isA<SoliplexApi>());
      expect(bundle.agUiClient, isA<AgUiClient>());
      expect(bundle.close, isA<void Function()>());

      bundle.close();
    });

    test('close can be called multiple times', () {
      final bundle = createClients('http://localhost:8000');

      bundle.close();
      // Second call should not throw.
      bundle.close();
    });
  });
}
