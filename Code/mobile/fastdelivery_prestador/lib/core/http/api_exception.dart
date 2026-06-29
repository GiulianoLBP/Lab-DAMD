/// Erro de comunicação com a API, já traduzido para uma mensagem amigável.
///
/// Quando o backend responde no formato `{"error": "..."}`, [message] carrega
/// essa mensagem. Em falhas de rede (backend fora do ar), carrega um texto
/// genérico. A camada de UI só precisa exibir [message].
///
/// Cópia idêntica do app cliente: os dois apps compartilham o mesmo contrato de
/// erros do backend (decisão da Sprint 4 — apps independentes com core copiado).
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  /// Mensagem pronta para exibição.
  final String message;

  /// Código HTTP, quando houve resposta do servidor (null em falha de rede).
  final int? statusCode;

  @override
  String toString() => message;
}
