"""
Barramento de eventos (Event Bus).

Abstração sobre o mecanismo de publicação/assinatura (MOM).
Implementações disponíveis:
  - RabbitMQEventBus: broker real (produção). Filas duráveis, confirmação de
    publicação (publisher confirms), ack manual e Dead-Letter Queue.
  - InMemoryEventBus: alternativa explícita APENAS para testes (vive em um
    único processo).

Uso:
    bus = criar_barramento()
    bus.publicar('meu.topico', {'chave': 'valor'})
"""

from __future__ import annotations

import json
import logging
import os
import threading
import time
from abc import ABC, abstractmethod
from typing import Callable, Optional

logger = logging.getLogger(__name__)

# ─── Strategy: assinantes em memória (somente testes) ──────────────────

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
        """Nome do mecanismo subjacente (ex.: 'rabbitmq', 'in_memory')."""


# ─── Implementação In-Memory (somente testes) ──────────────────────────


class InMemoryEventBus(EventBus):
    """
    Barramento baseado em listas de callbacks em memória.

    ATENÇÃO: serve APENAS para testes unitários. Vive na memória de um único
    processo, não persiste mensagens e não cruza a fronteira de processos —
    não há desacoplamento temporal nem espacial. Para qualquer execução real,
    use o RabbitMQEventBus.
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
        logger.info('[InMemory] Barramento pronto (modo memória — só testes)')

    def parar(self) -> None:
        self._running = False
        logger.info('[InMemory] Barramento parado')

    @property
    def nome(self) -> str:
        return 'in_memory'


# ─── Implementação RabbitMQ (broker real) ──────────────────────────────


class RabbitMQEventBus(EventBus):
    """
    Barramento usando RabbitMQ (AMQP) via pika.

    Topologia (declarada de forma idempotente por produtor e consumidor):
      - exchange topic 'fastdelivery.events' (durável) — recebe os eventos.
      - queue 'fastdelivery.entregas' (durável) — ligada à exchange com a
        routing key '#' (captura TODOS os tópicos). É a fila que persiste o
        backlog até o consumidor processá-lo.
      - exchange direct 'fastdelivery.dlx' + queue 'fastdelivery.dlq' (durável):
        Dead-Letter Queue. Mensagens cujo handler falha são rejeitadas
        (basic_nack requeue=False) e roteadas para a DLQ — sem travar o consumo
        nem perder o evento.

    Garantias:
      - Desacoplamento temporal: a fila durável guarda o evento mesmo se o
        consumidor estiver offline. Ao voltar, ele processa o backlog.
      - Desacoplamento espacial: produtor (Flask) e consumidor
        (consumer_worker.py) são processos distintos; o único elo é o broker.
      - Sem perda silenciosa: a publicação usa publisher confirms + mandatory;
        se o broker não confirmar, a falha é logada e propagada (não engolida).
      - Persistência: mensagens são delivery_mode=2 (gravadas em disco) e as
        filas/exchanges são duráveis (sobrevivem ao restart do broker).
      - Entrega at-least-once: ack manual só após o handler concluir.
    """

    EXCHANGE = 'fastdelivery.events'
    EXCHANGE_DLX = 'fastdelivery.dlx'
    QUEUE = 'fastdelivery.entregas'
    QUEUE_DLQ = 'fastdelivery.dlq'
    ROUTING_KEY_DLQ = 'dead'
    PREFETCH = 10

    def __init__(
        self,
        host: str = 'localhost',
        port: int = 5672,
        user: str = 'guest',
        password: str = 'guest',
        vhost: str = '/',
        url: Optional[str] = None,
    ):
        import pika

        self._pika = pika
        if url:
            self._params = pika.URLParameters(url)
        else:
            self._params = pika.ConnectionParameters(
                host=host,
                port=port,
                virtual_host=vhost,
                credentials=pika.PlainCredentials(user, password),
                heartbeat=30,
                blocked_connection_timeout=30,
                connection_attempts=3,
                retry_delay=2,
            )

        self._callbacks: dict[str, list[Callable]] = {}
        self._running = False
        self._consume_thread: Optional[threading.Thread] = None
        # Conexão dedicada à publicação (pika não é thread-safe por canal;
        # o consumo usa uma conexão própria, na sua thread).
        self._pub_conn = None
        self._pub_channel = None
        self._pub_lock = threading.Lock()

    # — topologia —

    def _declarar_topologia(self, channel) -> None:
        """Declara exchanges, filas e bindings (idempotente)."""
        # Dead-Letter: exchange direta + fila
        channel.exchange_declare(
            self.EXCHANGE_DLX, exchange_type='direct', durable=True
        )
        channel.queue_declare(self.QUEUE_DLQ, durable=True)
        channel.queue_bind(
            self.QUEUE_DLQ, self.EXCHANGE_DLX, routing_key=self.ROUTING_KEY_DLQ
        )

        # Exchange principal (topic) + fila durável com DLX configurada
        channel.exchange_declare(
            self.EXCHANGE, exchange_type='topic', durable=True
        )
        channel.queue_declare(
            self.QUEUE,
            durable=True,
            arguments={
                'x-dead-letter-exchange': self.EXCHANGE_DLX,
                'x-dead-letter-routing-key': self.ROUTING_KEY_DLQ,
            },
        )
        # '#' captura todos os tópicos: garante que o evento é enfileirado
        # mesmo que o consumidor ainda não tenha registrado o handler.
        channel.queue_bind(self.QUEUE, self.EXCHANGE, routing_key='#')

    # — publicação —

    def _garantir_conexao_publish(self) -> None:
        if (
            self._pub_conn is not None
            and self._pub_conn.is_open
            and self._pub_channel is not None
            and self._pub_channel.is_open
        ):
            return
        self._fechar_publish()
        conn = None
        try:
            conn = self._pika.BlockingConnection(self._params)
            channel = conn.channel()
            self._declarar_topologia(channel)
            channel.confirm_delivery()  # publisher confirms
            self._pub_conn = conn
            self._pub_channel = channel
        except Exception:
            if conn is not None and conn.is_open:
                conn.close()
            raise

    def _fechar_publish(self) -> None:
        try:
            if self._pub_conn is not None and self._pub_conn.is_open:
                self._pub_conn.close()
        except Exception:
            pass
        self._pub_conn = None
        self._pub_channel = None

    def publicar(self, topico: str, payload: dict) -> None:
        payload_str = json.dumps(payload, ensure_ascii=False)
        with self._pub_lock:
            try:
                self._garantir_conexao_publish()
                self._pub_channel.basic_publish(
                    exchange=self.EXCHANGE,
                    routing_key=topico,
                    body=payload_str.encode('utf-8'),
                    properties=self._pika.BasicProperties(
                        delivery_mode=2,  # persistente (gravado em disco)
                        content_type='application/json',
                    ),
                    mandatory=True,  # com confirms, falha se não for roteável
                )
                logger.info('[RabbitMQ] Publicado em "%s": %s', topico, payload_str)
            except Exception:
                # Sem perda silenciosa: loga em ERROR, reseta a conexão e
                # propaga — o broker NÃO confirmou a mensagem.
                logger.exception(
                    '[RabbitMQ] FALHA ao publicar em "%s" — mensagem NÃO '
                    'confirmada pelo broker', topico
                )
                self._fechar_publish()
                raise

    # — assinatura / consumo —

    def assinar(self, topico: str, callback: Callable[[str], None]) -> None:
        self._callbacks.setdefault(topico, []).append(callback)
        logger.info('[RabbitMQ] Assinante registrado para "%s"', topico)

    def iniciar_consumo(self) -> None:
        # Garante a topologia já na subida (mesmo produtor puro), para que a
        # fila durável exista e capture eventos antes de qualquer consumidor.
        try:
            with self._pub_lock:
                self._garantir_conexao_publish()
        except Exception:
            with self._pub_lock:
                self._fechar_publish()
            logger.warning(
                '[RabbitMQ] Não foi possível conectar ao broker na inicialização '
                '— a topologia/publicação será tentada novamente no 1º publish.'
            )

        if not self._callbacks:
            logger.info(
                '[RabbitMQ] Cliente conectado apenas para publicação '
                '(nenhum consumidor registrado neste processo).'
            )
            return

        if self._consume_thread is not None and self._consume_thread.is_alive():
            logger.info('[RabbitMQ] Consumidor já está em execução')
            return

        self._running = True
        self._consume_thread = threading.Thread(target=self._loop, daemon=True)
        self._consume_thread.start()
        logger.info('[RabbitMQ] Consumidor iniciado em thread daemon')

    def _loop(self) -> None:
        while self._running:
            conn = None
            try:
                conn = self._pika.BlockingConnection(self._params)
                channel = conn.channel()
                self._declarar_topologia(channel)
                channel.basic_qos(prefetch_count=self.PREFETCH)
                logger.info(
                    '[RabbitMQ] Consumindo da fila "%s" (Ctrl+C para sair)',
                    self.QUEUE,
                )
                # inactivity_timeout permite checar self._running periodicamente.
                for method, _props, body in channel.consume(
                    self.QUEUE, inactivity_timeout=1
                ):
                    if not self._running:
                        break
                    if method is None:
                        continue  # timeout de inatividade, sem mensagens
                    self._processar(channel, method, body)
                try:
                    channel.cancel()
                except Exception:
                    pass
            except Exception:
                if self._running:
                    logger.exception(
                        '[RabbitMQ] Conexão de consumo caiu; reconectando em 3s'
                    )
                    time.sleep(3)
            finally:
                try:
                    if conn is not None and conn.is_open:
                        conn.close()
                except Exception:
                    pass

    def _processar(self, channel, method, body) -> None:
        topico = method.routing_key
        payload_str = body.decode('utf-8')
        logger.info('[RabbitMQ] Recebido de "%s": %s', topico, payload_str)
        try:
            callbacks = self._callbacks.get(topico, [])
            if not callbacks:
                raise ValueError(f'Nenhum handler registrado para "{topico}"')
            for cb in callbacks:
                cb(payload_str)
            channel.basic_ack(method.delivery_tag)
        except Exception:
            # Handler falhou: rejeita sem requeue → mensagem vai para a DLQ.
            logger.exception(
                '[RabbitMQ] Handler falhou em "%s" → enviando para a DLQ', topico
            )
            channel.basic_nack(method.delivery_tag, requeue=False)

    def parar(self) -> None:
        self._running = False
        if self._consume_thread is not None:
            self._consume_thread.join(timeout=3)
        with self._pub_lock:
            self._fechar_publish()
        logger.info('[RabbitMQ] Barramento parado')

    @property
    def nome(self) -> str:
        return 'rabbitmq'


# ─── Fábrica ───────────────────────────────────────────────────────────


def criar_barramento() -> EventBus:
    """
    Cria o barramento de eventos apropriado conforme configurado.

    Ordem de preferência:
      1. Se EVENT_BUS=in_memory → InMemoryEventBus (somente para testes)
      2. Caso contrário → RabbitMQEventBus (RABBITMQ_URL ou host/porta/cred)

    Não há fallback implícito para memória: esquecer a configuração não pode
    desativar silenciosamente o broker central.
    """
    event_bus = os.environ.get('EVENT_BUS', 'rabbitmq').strip().lower()
    rabbit_url = os.environ.get('RABBITMQ_URL')

    if event_bus == 'in_memory':
        logger.info('Barramento criado: InMemory (modo de teste explícito)')
        return InMemoryEventBus()

    if event_bus != 'rabbitmq':
        raise ValueError(
            f'EVENT_BUS inválido: "{event_bus}". Use "rabbitmq" ou "in_memory".'
        )

    if rabbit_url:
        logger.info('Barramento criado: RabbitMQ (via RABBITMQ_URL)')
        return RabbitMQEventBus(url=rabbit_url)

    bus = RabbitMQEventBus(
        host=os.environ.get('RABBITMQ_HOST', 'localhost'),
        port=int(os.environ.get('RABBITMQ_PORT', '5672')),
        user=os.environ.get('RABBITMQ_USER', 'guest'),
        password=os.environ.get('RABBITMQ_PASS', 'guest'),
        vhost=os.environ.get('RABBITMQ_VHOST', '/'),
    )
    logger.info('Barramento criado: RabbitMQ (via host/porta/credenciais)')
    return bus
