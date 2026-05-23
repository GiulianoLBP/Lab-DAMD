"""
Interface produtora de eventos.

Dispara eventos no barramento sempre que uma ação de negócio relevante ocorre.
O produtor não conhece os consumidores — a comunicação é totalmente assíncrona.
"""

import logging

from app.mom.barramento import EventBus
from app.mom.eventos import (
    TOPICO_ENTREGA_CRIADA,
    TOPICO_ENTREGA_STATUS_ALTERADO,
    obter_payload,
)

logger = logging.getLogger(__name__)


class EntregaEventProducer:
    """Produz eventos relacionados ao domínio de entregas."""

    def __init__(self, bus: EventBus):
        self._bus = bus

    def entrega_criada(self, entrega_id: int, dados: dict) -> None:
        """Publica evento quando uma nova entrega é criada."""
        payload = obter_payload(TOPICO_ENTREGA_CRIADA, {
            'id': entrega_id,
            'descricao': dados.get('descricao'),
            'origem': dados.get('origem'),
            'destino': dados.get('destino'),
            'status': dados.get('status', 'pendente'),
            'cliente_id': dados.get('cliente_id'),
        })
        self._bus.publicar(TOPICO_ENTREGA_CRIADA, payload)
        logger.info('Evento publicado: %s (entrega #%s)', TOPICO_ENTREGA_CRIADA, entrega_id)

    def status_alterado(
        self,
        entrega_id: int,
        status_anterior: str,
        status_novo: str,
        cliente_id: str,
    ) -> None:
        """Publica evento quando o status de uma entrega muda."""
        payload = obter_payload(TOPICO_ENTREGA_STATUS_ALTERADO, {
            'id': entrega_id,
            'status_anterior': status_anterior,
            'status_novo': status_novo,
            'cliente_id': cliente_id,
        })
        self._bus.publicar(TOPICO_ENTREGA_STATUS_ALTERADO, payload)
        logger.info(
            'Evento publicado: %s (entrega #%s: %s → %s)',
            TOPICO_ENTREGA_STATUS_ALTERADO,
            entrega_id,
            status_anterior,
            status_novo,
        )