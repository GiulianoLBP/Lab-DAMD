/// Status possíveis de uma entrega, espelhando o enum do backend.
///
/// Camada de domínio pura: sem dependência de Flutter. As cores de cada status
/// vivem na apresentação (widget `StatusBadge`).
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

  /// O cliente só pode cancelar enquanto a entrega está pendente.
  /// Aceitar, iniciar trânsito e concluir são ações do prestador (Sprint 4).
  bool get podeCancelar => this == StatusEntrega.pendente;

  /// Sequência linear do progresso. `cancelado` é estado final alternativo,
  /// fora desta lista.
  static const List<StatusEntrega> fluxoPrincipal = <StatusEntrega>[
    StatusEntrega.pendente,
    StatusEntrega.aceito,
    StatusEntrega.emTransito,
    StatusEntrega.concluido,
  ];
}
