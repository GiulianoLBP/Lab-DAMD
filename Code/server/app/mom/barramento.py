"""
Barramento de eventos (Event Bus).

Abstração sobre o mecanismo de publicação/assinatura.
Suporta Redis Pub/Sub (produção) e fallback em memória (desenvolvimento/testes).

Uso:
    bus = criar_barramento()
    bus.publicar('meu.topico', {'chave': 'valor'})
"""

import json
import logging
import os
import threading
from abc import ABC, abstractmethod
from typing import Callable, Optional

logger = logging.getLogger(__name__)

# ─── Strategy: assinantes em memória ───────────────────────────────────

_subscribers_memory: dict[str, list[Callable]] = {}
_lock = threading.Lock()


def _notify_subscribers(topic: str, payload_str: str) -> None:
    """Notifica assinantes em memória em uma thread separada."""
    with _lock:
        callbacks = list(_subscribers_memory.get(topic, []))

    for cb in callbacks:
        try:
            cb(payload_str)
        except Exception:
            logger.exception('Erro em callback do tópico %s', topic)


# ─── Interfaces ────────────────────────────────────────────────────────


class EventBus(ABC):
    """Contrato que qualquer barramento de eventos deve implementar."""

    @abstractmethod
    def publicar(self, topico: str, payload: dict) -> None:
        """Publica um evento no tópico informado."""

    @abstractmethod
    def assinar(self, topico: str, callback: Callable[[str], None]) -> None:
        """Registra um callback para um tópico."""

    @abstractmethod
    def iniciar_consumo(self) -> None:
        """Inicia o loop de consumo de mensagens (se aplicável)."""

    @abstractmethod
    def parar(self) -> None:
        """Para o barramento e libera recursos."""

    @property
    @abstractmethod
    def nome(self) -> str:
        """Nome do mecanismo subjacente (ex.: 'redis', 'in_memory')."""


# ─── Implementação In-Memory ───────────────────────────────────────────


class InMemoryEventBus(EventBus):
    """
    Barramento baseado em listas de callbacks em memória.
    Ideal para desenvolvimento sem dependências externas.
    """

    def __init__(self):
        self._running = False

    def publicar(self, topico: str, payload: dict) -> None:
        payload_str = json.dumps(payload, ensure_ascii=False)
        logger.info('[InMemory] Publicado em "%s": %s', topico, payload_str)
        # Dispara notificações em background
        threading.Thread(
            target=_notify_subscribers,
            args=(topico, payload_str),
            daemon=True,
        ).start()

    def assinar(self, topico: str, callback: Callable[[str], None]) -> None:
        with _lock:
            _subscribers_memory.setdefault(topico, []).append(callback)
        logger.info('[InMemory] Assinante registrado para "%s"', topico)

    def iniciar_consumo(self) -> None:
        self._running = True
        logger.info('[InMemory] Barramento pronto (modo memória)')

    def parar(self) -> None:
        self._running = False
        logger.info('[InMemory] Barramento parado')

    @property
    def nome(self) -> str:
        return 'in_memory'


# ─── Implementação Redis ───────────────────────────────────────────────


class RedisEventBus(EventBus):
    """
    Barramento real usando Redis Pub/Sub.
    O consumidor roda em uma thread daemon escutando mensagens.
    """

    def __init__(self, host: str = 'localhost', port: int = 6379, db: int = 0):
        import redis as redis_client

        self._host = host
        self._port = port
        self._db = db
        self._running = False
        self._pubsub: Optional[redis_client.client.PubSub] = None
        self._thread: Optional[threading.Thread] = None
        self._client: Optional[redis_client.Redis] = None
        self._callbacks: dict[str, list[Callable]] = {}

    def publicar(self, topico: str, payload: dict) -> None:
        if not self._client:
            return  # não conectado
        payload_str = json.dumps(payload, ensure_ascii=False)
        try:
            self._client.publish(topico, payload_str)
            logger.info('[Redis] Publicado em "%s": %s', topico, payload_str)
        except Exception:
            logger.exception('[Redis] Erro ao publicar em "%s"', topico)

    def assinar(self, topico: str, callback: Callable[[str], None]) -> None:
        self._callbacks.setdefault(topico, []).append(callback)
        if self._pubsub:
            self._pubsub.subscribe(topico)
        logger.info('[Redis] Assinante registrado para "%s"', topico)

    def iniciar_consumo(self) -> None:
        import redis as redis_client

        try:
            self._client = redis_client.Redis(
                host=self._host,
                port=self._port,
                db=self._db,
                decode_responses=True,
                socket_connect_timeout=2,
            )
            self._client.ping()
        except Exception:
            logger.warning(
                '[Redis] Não foi possível conectar em %s:%s — '
                'o barramento não publicará eventos reais.',
                self._host,
                self._port,
            )
            self._client = None
            return

        self._pubsub = self._client.pubsub()
        for topico in self._callbacks:
            self._pubsub.subscribe(topico)

        self._running = True
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._thread.start()
        logger.info('[Redis] Consumidor iniciado em thread daemon')

    def _loop(self) -> None:
        if not self._pubsub:
            return
        try:
            for mensagem in self._pubsub.listen():
                if not self._running:
                    break
                if mensagem['type'] == 'message':
                    topico = mensagem['channel']
                    payload_str = mensagem['data']
                    logger.info(
                        '[Redis] Recebido de "%s": %s', topico, payload_str
                    )
                    for cb in self._callbacks.get(topico, []):
                        try:
                            cb(payload_str)
                        except Exception:
                            logger.exception(
                                'Erro em callback Redis de "%s"', topico
                            )
        except Exception:
            logger.exception('[Redis] Erro no loop de consumo')

    def parar(self) -> None:
        self._running = False
        if self._pubsub:
            try:
                self._pubsub.unsubscribe()
                self._pubsub.close()
            except Exception:
                pass
        if self._client:
            try:
                self._client.close()
            except Exception:
                pass
        logger.info('[Redis] Barramento parado')

    @property
    def nome(self) -> str:
        return 'redis'


# ─── Fábrica ───────────────────────────────────────────────────────────


def criar_barramento() -> EventBus:
    """
    Cria o barramento de eventos apropriado conforme configurado.

    Ordem de preferência:
      1. Se REDIS_URL estiver definida → RedisEventBus
      2. Se REDIS_HOST estiver definida → RedisEventBus
      3. Caso contrário → InMemoryEventBus
    """
    redis_url = os.environ.get('REDIS_URL')
    redis_host = os.environ.get('REDIS_HOST')

    if redis_url:
        # suporta redis://host:port
        parts = redis_url.replace('redis://', '').split(':')
        host = parts[0]
        port = int(parts[1]) if len(parts) > 1 else 6379
        bus = RedisEventBus(host=host, port=port)
        logger.info('Barramento criado: Redis (via REDIS_URL)')
        return bus

    if redis_host:
        port = int(os.environ.get('REDIS_PORT', '6379'))
        bus = RedisEventBus(host=redis_host, port=port)
        logger.info('Barramento criado: Redis (via REDIS_HOST)')
        return bus

    logger.info('Barramento criado: InMemory (fallback) — Redis não configurado')
    return InMemoryEventBus()