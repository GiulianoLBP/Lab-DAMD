"""
Serviço consumidor de eventos.

Roda em background e processa mensagens publicadas no barramento.
Demonstra a comunicação assíncrona: não há chamada REST entre produtor e consumidor.
"""

import json
import logging
from datetime import datetime
from typing import Optional

from app.mom.barramento import EventBus

logger = logging.getLogger(__name__)

# ─── Histórico de eventos processados (para consulta via API) ──────────

_eventos_processados: list[dict] = []
MAX_HISTORICO = 100


def obter_historico(ultimos: Optional[int] = None) -> list[dict]:
    """Retorna os eventos processados pelo consumidor."""
    if ultimos:
        return _eventos_processados[-ultimos:]
    return list(_eventos_processados)


# ─── Handlers de eventos ───────────────────────────────────────────────


def _ao_criar_entrega(payload_str: str) -> None:
    """
    Processa o evento 'entrega.criada'.
    Simula ações assíncronas como notificação, logging, etc.
    """
    try:
        payload = json.loads(payload_str)
        dados = payload.get('dados', {})
        entrega_id = dados.get('id')
        descricao = dados.get('descricao', 'sem descrição')
        cliente_id = dados.get('cliente_id', 'desconhecido')

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

        _eventos_processados.append({
            'tipo': 'entrega.criada',
            'entrega_id': entrega_id,
            'mensagem': f'Nova entrega criada: {descricao}',
            'processado_em': datetime.now().strftime('%Y-%m-%dT%H:%M:%S'),
            'payload': dados,
        })
        # Mantém tamanho controlado
        while len(_eventos_processados) > MAX_HISTORICO:
            _eventos_processados.pop(0)

    except Exception:
        logger.exception('Erro ao processar evento entrega.criada')


def _ao_alterar_status(payload_str: str) -> None:
    """
    Processa o evento 'entrega.status_atualizado'.
    Simula ações assíncronas como notificação de status.
    """
    try:
        payload = json.loads(payload_str)
        dados = payload.get('dados', {})
        entrega_id = dados.get('id')
        status_anterior = dados.get('status_anterior', '?')
        status_novo = dados.get('status_novo', '?')
        cliente_id = dados.get('cliente_id', 'desconhecido')

        logger.info(
            '═══════════════════════════════════════════════'
        )
        logger.info('  CONSUMIDOR → Status de entrega alterado!')
        logger.info('  ID: %s  |  Cliente: %s', entrega_id, cliente_id)
        logger.info('  Status: %s → %s', status_anterior, status_novo)
        logger.info('  [Simulação] Notificação de status enviada ao cliente')
        logger.info('  [Simulação] Evento registrado no histórico')
        logger.info('═══════════════════════════════════════════════')

        _eventos_processados.append({
            'tipo': 'entrega.status_atualizado',
            'entrega_id': entrega_id,
            'mensagem': f'Status alterado: {status_anterior} → {status_novo}',
            'processado_em': datetime.now().strftime('%Y-%m-%dT%H:%M:%S'),
            'payload': dados,
        })
        while len(_eventos_processados) > MAX_HISTORICO:
            _eventos_processados.pop(0)

    except Exception:
        logger.exception('Erro ao processar evento entrega.status_atualizado')


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