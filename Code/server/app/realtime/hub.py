"""
Hub de assinantes em memória para distribuição de eventos em tempo real.

Cada conexão WebSocket aberta em ``/ws/eventos`` registra a própria fila
(``queue.Queue``). A ponte RabbitMQ (``bridge.py``) consome os eventos do broker
e chama :meth:`RealtimeHub.publish`, que enfileira uma cópia do evento para cada
assinante. O handler WebSocket bloqueia em ``Queue.get()`` e repassa ao cliente.

Esta camada é puramente em memória e desacopla o consumidor do broker (UMA única
conexão pika, na ponte) das N conexões WebSocket — sem ela, cada cliente exigiria
uma fila no RabbitMQ. É facilmente testável sem broker (ver tests/test_realtime).
"""

from __future__ import annotations

import logging
import queue
import threading
from typing import Any

logger = logging.getLogger(__name__)


class RealtimeHub:
    """Fan-out thread-safe de eventos para as conexões WebSocket assinantes."""

    def __init__(self, max_fila: int = 100) -> None:
        # set protegido por lock: subscribe/unsubscribe podem ocorrer em threads
        # diferentes (cada conexão WebSocket roda na sua própria thread).
        self._assinantes: set[queue.Queue] = set()
        self._lock = threading.Lock()
        self._max_fila = max_fila

    def subscribe(self) -> queue.Queue:
        """Registra um novo assinante e devolve a fila por onde ele recebe eventos."""
        fila: queue.Queue = queue.Queue(maxsize=self._max_fila)
        with self._lock:
            self._assinantes.add(fila)
        logger.info('[Realtime] Assinante WebSocket conectado (total=%d)', self.total)
        return fila

    def unsubscribe(self, fila: queue.Queue) -> None:
        """Remove um assinante (quando a conexão WebSocket fecha)."""
        with self._lock:
            self._assinantes.discard(fila)
        logger.info('[Realtime] Assinante WebSocket desconectado (total=%d)', self.total)

    def publish(self, evento: Any) -> None:
        """Entrega o evento a todos os assinantes ativos.

        Usa ``put_nowait``: se a fila de um cliente lento estiver cheia, o evento
        é descartado *só para ele* (e logado) em vez de travar o fan-out — o app
        faz re-sync via REST ao reconectar, então perdas pontuais são toleráveis.
        """
        with self._lock:
            assinantes = list(self._assinantes)
        for fila in assinantes:
            try:
                fila.put_nowait(evento)
            except queue.Full:
                logger.warning(
                    '[Realtime] Fila de assinante cheia; evento descartado para esse cliente'
                )

    @property
    def total(self) -> int:
        """Número de conexões WebSocket atualmente assinantes."""
        with self._lock:
            return len(self._assinantes)
