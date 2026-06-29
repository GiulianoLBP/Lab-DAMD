/// Status possíveis de uma entrega, espelhando o enum do backend.
///
/// Camada de domínio pura: sem dependência de Flutter. As cores de cada status
/// vivem na apresentação (widget `StatusBadge`). Em relação ao app cliente, esta
/// cópia adiciona helpers das AÇÕES DO PRESTADOR (aceitar/recusar/avançar).
enum StatusEntrega {
  pendente('pendente', 'Pendente'),
  aceito('aceito', 'Aceito'),
  emTransito('em_transito', 'Em trânsito'),
  concluido('concluido', 'Concluído'),
  cancelado('cancelado', 'Cancelado');

  const StatusEntrega(this.valor, this.rotulo);

  /// Valor trocado com a API (ex.: `em_transito`).
  final String valor;

  /// Rótulo legível para a interface (ex.: `Em trânsito`).
  final String rotulo;

  /// Resolve o enum a partir do valor textual da API; `null` se desconhecido.
  static StatusEntrega? fromValor(String? valor) {
    for (final status in StatusEntrega.values) {
      if (status.valor == valor) {
        return status;
      }
    }
    return null;
  }

  /// Sequência linear do progresso. `cancelado` é estado final alternativo,
  /// fora desta lista.
  static const List<StatusEntrega> fluxoPrincipal = <StatusEntrega>[
    StatusEntrega.pendente,
    StatusEntrega.aceito,
    StatusEntrega.emTransito,
    StatusEntrega.concluido,
  ];

  // ─── Ações do prestador ────────────────────────────────────────────

  /// O prestador decide (aceitar/recusar) enquanto a entrega está pendente.
  bool get podeDecidir => this == StatusEntrega.pendente;

  /// Status considerado "em andamento" (responsabilidade ativa do prestador).
  bool get emAndamento =>
      this == StatusEntrega.aceito || this == StatusEntrega.emTransito;

  /// Próximo status no fluxo do prestador após o aceite (`null` se terminal).
  /// aceito → em_transito → concluido.
  StatusEntrega? get proximoStatus {
    switch (this) {
      case StatusEntrega.aceito:
        return StatusEntrega.emTransito;
      case StatusEntrega.emTransito:
        return StatusEntrega.concluido;
      default:
        return null;
    }
  }

  /// Rótulo do botão que leva ao [proximoStatus] (`null` se não há avanço).
  String? get rotuloAvancar {
    switch (this) {
      case StatusEntrega.aceito:
        return 'Iniciar trânsito';
      case StatusEntrega.emTransito:
        return 'Concluir entrega';
      default:
        return null;
    }
  }
}
