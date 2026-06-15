/// Configurações globais do app cliente.
///
/// A URL base é resolvida em tempo de build/run via `--dart-define`, então o
/// mesmo binário aponta para Windows desktop, emulador Android ou um IP da rede
/// sem alterar código nem o backend.
class ApiConfig {
  const ApiConfig._();

  /// URL base do backend Flask.
  ///
  /// Sobrescreva com, por exemplo:
  /// `--dart-define=FASTDELIVERY_API_URL=http://10.0.2.2:5055` (emulador Android).
  static const String baseUrl = String.fromEnvironment(
    'FASTDELIVERY_API_URL',
    defaultValue: 'http://localhost:5055',
  );

  /// Cliente fixo de demonstração. Autenticação fica fora do escopo da Sprint 3;
  /// este id é usado para filtrar e criar entregas do cliente.
  static const String clienteIdDemo = 'cliente-demo-001';

  /// Intervalo do polling REST que reflete mudanças de status sem ação manual.
  static const Duration intervaloPolling = Duration(seconds: 5);
}
