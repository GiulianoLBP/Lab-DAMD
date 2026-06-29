/// Configurações globais do app prestador.
///
/// A URL base é resolvida em tempo de build/run via `--dart-define`, como no app
/// cliente, então o mesmo binário aponta para Windows desktop, emulador Android
/// ou um IP da rede sem alterar código.
class ApiConfig {
  const ApiConfig._();

  /// URL base do backend Flask (REST).
  ///
  /// Sobrescreva com, por exemplo:
  /// `--dart-define=FASTDELIVERY_API_URL=http://10.0.2.2:5055` (emulador Android).
  static const String baseUrl = String.fromEnvironment(
    'FASTDELIVERY_API_URL',
    defaultValue: 'http://localhost:5055',
  );

  /// URL do WebSocket de eventos em tempo real (`/ws/eventos`).
  ///
  /// Pode ser informada explicitamente via
  /// `--dart-define=FASTDELIVERY_WS_URL=ws://10.0.2.2:5055/ws/eventos`; se vazia,
  /// é derivada da [baseUrl] (http→ws, https→wss) + caminho `/ws/eventos`.
  static String get wsUrl {
    const explicito = String.fromEnvironment(
      'FASTDELIVERY_WS_URL',
      defaultValue: '',
    );
    if (explicito.isNotEmpty) {
      return explicito;
    }
    final base = Uri.parse(baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(scheme: scheme, path: '/ws/eventos').toString();
  }

  /// Intervalo entre tentativas de reconexão do WebSocket (após queda).
  static const Duration intervaloReconexao = Duration(seconds: 3);
}
