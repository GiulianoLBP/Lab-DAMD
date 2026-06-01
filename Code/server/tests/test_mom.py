import json
import os
import tempfile
import threading
import unittest
from types import SimpleNamespace
from unittest.mock import Mock, patch

from app.database import init_db
from app.mom.barramento import (
    InMemoryEventBus,
    RabbitMQEventBus,
    criar_barramento,
)
from app.mom.consumer import _ao_criar_entrega, obter_historico
from app.mom.eventos import obter_payload


class FactoryTests(unittest.TestCase):

    def test_in_memory_requires_explicit_configuration(self):
        with patch.dict(os.environ, {'EVENT_BUS': 'in_memory'}, clear=True):
            bus = criar_barramento()

        self.assertIsInstance(bus, InMemoryEventBus)

    def test_rabbitmq_is_the_default_bus(self):
        with (
            patch.dict(os.environ, {}, clear=True),
            patch('app.mom.barramento.RabbitMQEventBus') as rabbitmq_bus,
        ):
            bus = criar_barramento()

        rabbitmq_bus.assert_called_once_with(
            host='localhost',
            port=5672,
            user='guest',
            password='guest',
            vhost='/',
        )
        self.assertIs(bus, rabbitmq_bus.return_value)


class RabbitMQProcessingTests(unittest.TestCase):

    def setUp(self):
        self.bus = object.__new__(RabbitMQEventBus)
        self.bus._callbacks = {}
        self.channel = Mock()
        self.method = SimpleNamespace(routing_key='entrega.criada', delivery_tag=7)

    def test_acknowledges_message_after_successful_handler(self):
        callback = Mock()
        self.bus._callbacks['entrega.criada'] = [callback]

        self.bus._processar(self.channel, self.method, b'{"dados": {}}')

        callback.assert_called_once_with('{"dados": {}}')
        self.channel.basic_ack.assert_called_once_with(7)
        self.channel.basic_nack.assert_not_called()

    def test_sends_message_to_dlq_when_handler_fails(self):
        self.bus._callbacks['entrega.criada'] = [Mock(side_effect=ValueError)]

        self.bus._processar(self.channel, self.method, b'{"dados": {}}')

        self.channel.basic_ack.assert_not_called()
        self.channel.basic_nack.assert_called_once_with(7, requeue=False)

    def test_sends_unknown_topic_to_dlq(self):
        self.method.routing_key = 'entrega.desconhecida'

        self.bus._processar(self.channel, self.method, b'{"dados": {}}')

        self.channel.basic_ack.assert_not_called()
        self.channel.basic_nack.assert_called_once_with(7, requeue=False)

    def test_replaces_connection_when_publish_channel_is_closed(self):
        stale_conn = Mock(is_open=True)
        stale_channel = Mock(is_open=False)
        fresh_conn = Mock(is_open=True)
        fresh_channel = Mock(is_open=True)
        fresh_conn.channel.return_value = fresh_channel
        self.bus._pub_conn = stale_conn
        self.bus._pub_channel = stale_channel
        self.bus._params = object()
        self.bus._pika = Mock()
        self.bus._pika.BlockingConnection.return_value = fresh_conn
        self.bus._declarar_topologia = Mock()

        self.bus._garantir_conexao_publish()

        stale_conn.close.assert_called_once_with()
        self.bus._declarar_topologia.assert_called_once_with(fresh_channel)
        fresh_channel.confirm_delivery.assert_called_once_with()
        self.assertIs(self.bus._pub_conn, fresh_conn)
        self.assertIs(self.bus._pub_channel, fresh_channel)

    def test_retries_publish_once_after_connection_failure(self):
        self.bus._pub_lock = threading.Lock()
        self.bus._publicar_confirmado = Mock(
            side_effect=[ConnectionError('stale connection'), None]
        )
        self.bus._fechar_publish = Mock()

        self.bus.publicar('entrega.criada', {'evento_id': 'evento-1'})

        self.assertEqual(2, self.bus._publicar_confirmado.call_count)
        self.bus._fechar_publish.assert_called_once_with()


class ProcessedEventHistoryTests(unittest.TestCase):

    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.db_path = os.path.join(self.temp_dir.name, 'test.db')
        self.database_env = patch.dict(
            os.environ,
            {'DATABASE_PATH': self.db_path},
        )
        self.database_env.start()
        init_db()

    def tearDown(self):
        self.database_env.stop()
        self.temp_dir.cleanup()

    def test_history_is_persistent_and_idempotent(self):
        payload = obter_payload(
            'entrega.criada',
            {
                'id': 1,
                'descricao': 'Pacote',
                'cliente_id': 'cliente-1',
            },
        )
        payload_str = json.dumps(payload, ensure_ascii=False)

        _ao_criar_entrega(payload_str)
        _ao_criar_entrega(payload_str)

        historico = obter_historico()
        self.assertEqual(1, len(historico))
        self.assertEqual(payload['evento_id'], historico[0]['evento_id'])
        self.assertEqual('entrega.criada', historico[0]['tipo'])


if __name__ == '__main__':
    unittest.main()
