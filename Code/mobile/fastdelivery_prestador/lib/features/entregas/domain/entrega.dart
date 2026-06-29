import 'status_entrega.dart';

/// Entrega retornada pelo backend.
///
/// Cópia idêntica do modelo do app cliente (mesmo contrato REST). O parsing é
/// defensivo (nunca quebra a tela por JSON inesperado): campos textuais ausentes
/// viram string vazia. Um `id` ausente/inválido é violação de contrato, então
/// lança [FormatException] em vez de produzir um modelo inconsistente.
class Entrega {
  const Entrega({
    required this.id,
    required this.descricao,
    required this.origem,
    required this.destino,
    required this.status,
    required this.clienteId,
    this.criadoEm,
    this.atualizadoEm,
  });

  final int id;
  final String descricao;
  final String origem;
  final String destino;
  final String status;
  final String clienteId;
  final String? criadoEm;
  final String? atualizadoEm;

  factory Entrega.fromJson(Map<String, dynamic> json) {
    final dynamic rawId = json['id'];
    final int? id = rawId is int ? rawId : int.tryParse('$rawId');
    if (id == null) {
      throw const FormatException('Entrega sem campo "id" válido');
    }
    return Entrega(
      id: id,
      descricao: _texto(json['descricao']),
      origem: _texto(json['origem']),
      destino: _texto(json['destino']),
      status: _texto(json['status']),
      clienteId: _texto(json['cliente_id']),
      criadoEm: _textoOuNulo(json['criado_em']),
      atualizadoEm: _textoOuNulo(json['atualizado_em']),
    );
  }

  /// Enum de status, ou `null` se o backend enviar um valor desconhecido.
  StatusEntrega? get statusEnum => StatusEntrega.fromValor(status);

  static String _texto(dynamic valor) => valor?.toString() ?? '';

  static String? _textoOuNulo(dynamic valor) => valor?.toString();
}
