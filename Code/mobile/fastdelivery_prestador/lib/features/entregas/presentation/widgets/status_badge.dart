import 'package:flutter/material.dart';

import '../../domain/status_entrega.dart';

/// Selo colorido do status, com cor e rótulo derivados do domínio.
///
/// Cópia do widget do app cliente (mesma identidade visual de status). Recebe o
/// status como texto (valor cru da API) e resolve cor/rótulo; um status
/// desconhecido cai num estilo neutro, sem quebrar a tela.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final statusEnum = StatusEntrega.fromValor(status);
    final cores = _cores(statusEnum);
    final rotulo =
        statusEnum?.rotulo ?? (status.isEmpty ? 'Desconhecido' : status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cores.fundo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        rotulo,
        style: TextStyle(
          color: cores.texto,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Par (fundo, texto) para cada status, em tons suaves conforme o guia visual.
  ({Color fundo, Color texto}) _cores(StatusEntrega? status) {
    switch (status) {
      case StatusEntrega.pendente:
        return (fundo: const Color(0xFFFFF3CD), texto: const Color(0xFF8A6D00));
      case StatusEntrega.aceito:
        return (fundo: const Color(0xFFD6E4FF), texto: const Color(0xFF1D4ED8));
      case StatusEntrega.emTransito:
        return (fundo: const Color(0xFFE9DBFF), texto: const Color(0xFF6B21A8));
      case StatusEntrega.concluido:
        return (fundo: const Color(0xFFD9F5E3), texto: const Color(0xFF12784A));
      case StatusEntrega.cancelado:
        return (fundo: const Color(0xFFFCE0E0), texto: const Color(0xFF9B1C1C));
      case null:
        return (fundo: const Color(0xFFE6E8EB), texto: const Color(0xFF4B5563));
    }
  }
}
