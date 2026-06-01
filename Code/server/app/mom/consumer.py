"""
Serviço consumidor de eventos.

Roda em background e processa mensagens publicadas no barramento.
Demonstra a comunicação assíncrona: não há chamada REST entre produtor e consumidor.

Importante: os handlers NÃO engolem exceções. Se o processamento falhar, a
exceção propaga até o barramento, que rejeita a mensagem (basic_nack) e a
encaminha para a Dead-Letter Queue — sem perda lógica nem confirmação indevida.
"""

from __future__ import annotations

import hashlib
import json
import logging
from typing import Optional

from app.mom.barramento import EventBus
from app.repositories.evento_processado_repository import EventoProcessadoRepository

logger = logging.getLogger(__name__)

# ─── Histórico persistente de eventos processados (consulta via API) ───

MAX_HISTORICO = 100
_repository = EventoProcessadoRepository()


def obter_historico(ultimos: Optional[int] = None) -> list[dict]:
    """Retorna os eventos processados pelo consumidor."""
    return _repository.listar(ultimos)


def _registrar_processamento(
    payload_str: str,
    payload: dict,
    tipo: str,
    entrega_id: Optional[int],
    mensagem: str,
    dados: dict,
) -> bool:
    evento_id = payload.get('evento_id')
    if not evento_id:
        # Compatibilidade com mensagens publicadas antes da inclusão do ID.
        evento_id = hashlib.sha256(payload_str.encode('utf-8')).hexdigest()
    return _repository.registrar(
        evento_id=evento_id,
        tipo=tipo,
        entrega_id=entrega_id,
        mensagem=mensagem,
        payload=dados,
        limite=MAX_HISTORICO,
    )


# ─── Handlers de eventos ───────────────────────────────────────────────


def _ao_criar_entrega(payload_str: str) -> None:
    """
    Processa o evento 'entrega.criada'.
    Simula ações assíncronas como notificação, logging, etc.

    Não captura exceções: se algo falhar, o barramento encaminha a mensagem
    para a Dead-Letter Queue (at-least-once + DLQ).
    """
    payload = json.loads(payload_str)
    dados = payload.get('dados', {})
    entrega_id = dados.get('id')
    descricao = dados.get('descricao', 'sem descrição')
    cliente_id = dados.get('cliente_id', 'desconhecido')
    if not _registrar_processamento(
        payload_str,
        payload,
        tipo='entrega.criada',
        entrega_id=entrega_id,
        mensagem=f'Nova entrega criada: {descricao}',
        dados=dados,
    ):
        logger.info('Evento entrega.criada já processado; ignorando duplicata')
        return

    logger.info(
        '═══════════════════════════════════════════════'
    )
    logger.info('  CONSUMIDOR → Nova entrega criada!')
    logger.info('  ID: %s  |  Cliente: %s', entrega_id, cliente_id)
    logger.info('  Descrição: %s', descricao)
    logger.info('  Status inicial: pendente')
    logger.info('  [Simulação] Notificação enviada ao prestador')
    logger.info('  [Simulação] Evento registrado no histórico')
    logger.info('═══════════════════════════════════════════════')


def _ao_alterar_status(payload_str: str) -> None:
    """
    Processa o evento 'entrega.status_atualizado'.
    Simula ações assíncronas como notificação de status.

    Não captura exceções: falhas vão para a Dead-Letter Queue via o barramento.
    """
    payload = json.loads(payload_str)
    dados = payload.get('dados', {})
    entrega_id = dados.get('id')
    status_anterior = dados.get('status_anterior', '?')
    status_novo = dados.get('status_novo', '?')
    cliente_id = dados.get('cliente_id', 'desconhecido')
    if not _registrar_processamento(
        payload_str,
        payload,
        tipo='entrega.status_atualizado',
        entrega_id=entrega_id,
        mensagem=f'Status alterado: {status_anterior} → {status_novo}',
        dados=dados,
    ):
        logger.info(
            'Evento entrega.status_atualizado já processado; ignorando duplicata'
        )
        return

    logger.info(
        '═══════════════════════════════════════════════'
    )
    logger.info('  CONSUMIDOR → Status de entrega alterado!')
    logger.info('  ID: %s  |  Cliente: %s', entrega_id, cliente_id)
    logger.info('  Status: %s → %s', status_anterior, status_novo)
    logger.info('  [Simulação] Notificação de status enviada ao cliente')
    logger.info('  [Simulação] Evento registrado no histórico')
    logger.info('═══════════════════════════════════════════════')


# ─── Inicialização ─────────────────────────────────────────────────────


def registrar_consumidores(bus: EventBus) -> None:
    """Registra os callbacks de consumo no barramento."""
    from app.mom.eventos import (
        TOPICO_ENTREGA_CRIADA,
        TOPICO_ENTREGA_STATUS_ALTERADO,
    )

    bus.assinar(TOPICO_ENTREGA_CRIADA, _ao_criar_entrega)
    bus.assinar(TOPICO_ENTREGA_STATUS_ALTERADO, _ao_alterar_status)

    logger.info('Consumidores registrados no barramento')
    logger.info('  ↳ %s → handler ao_criar_entrega', TOPICO_ENTREGA_CRIADA)
    logger.info(
        '  ↳ %s → handler ao_alterar_status',
        TOPICO_ENTREGA_STATUS_ALTERADO,
    )
