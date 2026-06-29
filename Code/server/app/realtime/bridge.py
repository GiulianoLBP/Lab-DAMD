"""
Ponte RabbitMQ → Hub em tempo real.

Uma thread daemon consome os eventos de domínio do exchange
``fastdelivery.events`` por uma fila DEDICADA (``fastdelivery.realtime``) e os
repassa ao :class:`RealtimeHub`, que distribui para as conexões WebSocket abertas
pelo app do prestador.

Por que uma fila dedicada (e não a ``fastdelivery.entregas``):
o exchange é *topic* e faz fan-out por routing key. A fila
``fastdelivery.entregas`` já é consumida pelo ``consumer_worker.py`` (histórico);
compartilhá-la criaria *competing consumers* — cada evento iria para apenas um dos
consumidores. Uma fila própria garante que a ponte receba a própria CÓPIA de cada
evento, sem interferir no worker.

A fila é não-durável e ``auto_delete``: notificação ao vivo não precisa de backlog
persistente — o app faz re-sync via REST ao (re)conectar. Assim, eventos
publicados enquanto nenhum prestador está conectado simplesmente não são
notificados ao vivo (e são recuperados na próxima carga REST).
"""

from __future__ import annotations

import json
import logging
import os
import threading
import time
from typing import Optional

from app.mom.barramento import RabbitMQEventBus
from app.mom.eventos import TOPICO_ENTREGA_CRIADA, TOPICO_ENTREGA_STATUS_ALTERADO
from app.realtime.hub import RealtimeHub

logger = logging.getLogger(__name__)

FILA_REALTIME = 'fastdelivery.realtime'
ROUTING_KEYS = (TOPICO_ENTREGA_CRIADA, TOPICO_ENTREGA_STATUS_ALTERADO)


def _parametros_pika():
    """Parâmetros de conexão pika a partir das MESMAS env vars do ``barramento.py``."""
    import pika

    url = os.environ.get('RABBITMQ_URL')
    if url:
        return pika.URLParameters(url)
    return pika.ConnectionParameters(
        host=os.environ.get('RABBITMQ_HOST', 'localhost'),
        port=int(os.environ.get('RABBITMQ_PORT', '5672')),
        virtual_host=os.environ.get('RABBITMQ_VHOST', '/'),
        credentials=pika.PlainCredentials(
            os.environ.get('RABBITMQ_USER', 'guest'),
            os.environ.get('RABBITMQ_PASS', 'guest'),
        ),
        heartbeat=30,
        blocked_connection_timeout=30,
        connection_attempts=3,
        retry_delay=2,
    )


class PonteRealtime:
    """Consumidor RabbitMQ que alimenta o :class:`RealtimeHub` em thread daemon."""

    def __init__(self, hub: RealtimeHub) -> None:
        self._hub = hub
        self._running = False
        self._thread: Optional[threading.Thread] = None

    def iniciar(self) -> None:
        if self._thread is not None and self._thread.is_alive():
            return
        self._running = True
        self._thread = threading.Thread(
            target=self._loop, name='ponte-realtime', daemon=True
        )
        self._thread.start()
        logger.info('[Realtime] Ponte RabbitMQ→WebSocket iniciada (thread daemon)')

    def parar(self) -> None:
        self._running = False
        if self._thread is not None:
            self._thread.join(timeout=3)

    def _loop(self) -> None:
        import pika

        while self._running:
            conn = None
            try:
                conn = pika.BlockingConnection(_parametros_pika())
                channel = conn.channel()
                # Declarações idempotentes; mesmo nome/tipo do exchange do barramento.
                channel.exchange_declare(
                    RabbitMQEventBus.EXCHANGE, exchange_type='topic', durable=True
                )
                channel.queue_declare(
                    FILA_REALTIME, durable=False, auto_delete=True
                )
                for rk in ROUTING_KEYS:
                    channel.queue_bind(
                        FILA_REALTIME, RabbitMQEventBus.EXCHANGE, routing_key=rk
                    )
                channel.basic_qos(prefetch_count=20)
                logger.info(
                    '[Realtime] Consumindo de "%s" (routing keys=%s)',
                    FILA_REALTIME, list(ROUTING_KEYS),
                )

                # inactivity_timeout permite reavaliar self._running periodicamente.
                for method, _props, body in channel.consume(
                    FILA_REALTIME, inactivity_timeout=1
                ):
                    if not self._running:
                        break
                    if method is None:
                        continue  # timeout sem mensagens
                    self._repassar(body)
                    channel.basic_ack(method.delivery_tag)
                try:
                    channel.cancel()
                except Exception:
                    pass
            except Exception:
                if self._running:
                    logger.warning(
                        '[Realtime] Conexão da ponte caiu; reconectando em 3s',
                        exc_info=True,
                    )
                    time.sleep(3)
            finally:
                try:
                    if conn is not None and conn.is_open:
                        conn.close()
                except Exception:
                    pass

    def _repassar(self, body: bytes) -> None:
        try:
            evento = json.loads(body.decode('utf-8'))
        except (UnicodeDecodeError, json.JSONDecodeError):
            logger.warning('[Realtime] Mensagem ignorada (JSON inválido)')
            return
        self._hub.publish(evento)
        logger.info('[Realtime] Evento repassado ao hub: %s', evento.get('evento'))


def iniciar_ponte(hub: RealtimeHub) -> PonteRealtime:
    """Cria e inicia a ponte; devolve a instância (para parada, se necessário)."""
    ponte = PonteRealtime(hub)
    ponte.iniciar()
    return ponte
