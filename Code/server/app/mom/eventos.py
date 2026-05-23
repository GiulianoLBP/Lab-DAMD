"""
Definição dos eventos do domínio de entregas.

Cada evento representa um fato ocorrido no sistema e carrega
o payload necessário para que consumidores assíncronos processem.
"""


# ─── Nomes dos tópicos (canais Pub/Sub) ────────────────────────────────

TOPICO_ENTREGA_CRIADA = 'entrega.criada'
"""Publicado quando uma nova solicitação de entrega é criada."""

TOPICO_ENTREGA_STATUS_ALTERADO = 'entrega.status_atualizado'
"""Publicado quando o status de uma entrega existente é alterado."""


# ─── Estrutura dos eventos ─────────────────────────────────────────────

EVENTOS = {
    TOPICO_ENTREGA_CRIADA: {
        'descricao': 'Nova solicitação de entrega criada',
        'produtor': 'EntregaUseCases.criar_entrega()',
        'consumidor': 'ConsumerService (background thread)',
        'topico': TOPICO_ENTREGA_CRIADA,
        'payload_exemplo': {
            'evento': 'entrega.criada',
            'dados': {
                'id': 1,
                'descricao': 'Buscar encomenda',
                'origem': 'Rua A, 100',
                'destino': 'Rua B, 200',
                'status': 'pendente',
                'cliente_id': 'cliente-uuid-123',
            },
            'timestamp': '2026-05-16T10:00:00',
        },
    },
    TOPICO_ENTREGA_STATUS_ALTERADO: {
        'descricao': 'Status de uma entrega atualizado',
        'produtor': 'EntregaUseCases.atualizar_status()',
        'consumidor': 'ConsumerService (background thread)',
        'topico': TOPICO_ENTREGA_STATUS_ALTERADO,
        'payload_exemplo': {
            'evento': 'entrega.status_atualizado',
            'dados': {
                'id': 1,
                'status_anterior': 'pendente',
                'status_novo': 'aceito',
                'cliente_id': 'cliente-uuid-123',
            },
            'timestamp': '2026-05-16T10:05:00',
        },
    },
}


def obter_payload(evento: str, dados: dict) -> dict:
    """Constrói o payload padronizado de um evento."""
    from datetime import datetime
    return {
        'evento': evento,
        'dados': dados,
        'timestamp': datetime.now().strftime('%Y-%m-%dT%H:%M:%S'),
    }