"""
Testes de integração dos endpoints REST consumidos pelo app Flutter (Sprint 3).

Cada teste sobe um app Flask isolado, com banco SQLite temporário
(via DATABASE_PATH) e um barramento de eventos falso e síncrono — sem broker
nem threads — para não depender de RabbitMQ nem do entregas.db local.

Cobre a matriz API01–API10 do plano de testes da Sprint 3, mais o fluxo de
cancelamento pelo cliente, que é a única escrita de status feita pelo app.
"""

import os
import tempfile
import unittest
from unittest.mock import patch

from flask import Flask

from app.controllers.entrega_controller import entrega_bp, init_use_cases
from app.database import init_db
from app.mom.producer import EntregaEventProducer
from app.repositories.entrega_repository import EntregaRepository
from app.use_cases.entrega_use_cases import EntregaUseCases


class _FakeBus:
    """Barramento de teste: registra publicações de forma síncrona, sem broker."""

    def __init__(self):
        self.publicados = []

    def publicar(self, topico, payload):
        self.publicados.append((topico, payload))


class EntregaApiTests(unittest.TestCase):

    def setUp(self):
        # Banco temporário isolado do entregas.db do desenvolvedor.
        self.temp_dir = tempfile.TemporaryDirectory()
        self.db_path = os.path.join(self.temp_dir.name, 'test.db')
        self.database_env = patch.dict(
            os.environ, {'DATABASE_PATH': self.db_path}
        )
        self.database_env.start()
        init_db()

        # Casos de uso reais + barramento falso (assert de evento publicado).
        self.bus = _FakeBus()
        use_cases = EntregaUseCases(
            repository=EntregaRepository(),
            event_producer=EntregaEventProducer(self.bus),
        )
        init_use_cases(use_cases)

        app = Flask(__name__)
        app.register_blueprint(entrega_bp)
        app.testing = True
        self.client = app.test_client()

    def tearDown(self):
        self.database_env.stop()
        self.temp_dir.cleanup()

    # ─── helpers ───────────────────────────────────────────────────────

    def _criar(self, **overrides):
        payload = {
            'descricao': 'Pacote pequeno',
            'origem': 'Rua A, 100',
            'destino': 'Rua B, 200',
            'cliente_id': 'cliente-demo-001',
        }
        payload.update(overrides)
        return self.client.post('/entregas', json=payload)

    def _topicos_publicados(self):
        return [topico for topico, _ in self.bus.publicados]

    # ─── API01: POST válido ────────────────────────────────────────────

    def test_api01_criar_entrega_valida(self):
        resp = self._criar()

        self.assertEqual(201, resp.status_code)
        data = resp.get_json()
        self.assertEqual('pendente', data['status'])
        self.assertIsInstance(data['id'], int)
        for campo in (
            'id', 'descricao', 'origem', 'destino',
            'status', 'cliente_id', 'criado_em', 'atualizado_em',
        ):
            self.assertIn(campo, data)
        # O backend continua emitindo o evento de criação (Sprint 2 preservada).
        self.assertIn('entrega.criada', self._topicos_publicados())

    def test_post_ignora_status_enviado_pelo_cliente(self):
        # Mesmo que o cliente envie status, o backend força 'pendente'.
        resp = self._criar(status='concluido')

        self.assertEqual(201, resp.status_code)
        self.assertEqual('pendente', resp.get_json()['status'])

    # ─── API02: POST inválido ──────────────────────────────────────────

    def test_api02_criar_sem_campo_obrigatorio(self):
        resp = self.client.post(
            '/entregas', json={'descricao': 'x', 'origem': 'y'}
        )

        self.assertEqual(400, resp.status_code)
        self.assertIn('error', resp.get_json())

    def test_api02_criar_campo_em_branco(self):
        resp = self._criar(descricao='   ')

        self.assertEqual(400, resp.status_code)
        self.assertIn('error', resp.get_json())

    def test_api02_criar_sem_body(self):
        resp = self.client.post('/entregas')

        self.assertEqual(400, resp.status_code)
        self.assertIn('error', resp.get_json())

    # ─── API03 / API04 / API05: GET lista ──────────────────────────────

    def test_api03_listar_retorna_array(self):
        self._criar()
        resp = self.client.get('/entregas')

        self.assertEqual(200, resp.status_code)
        self.assertIsInstance(resp.get_json(), list)

    def test_api04_listar_filtra_por_status(self):
        self._criar()  # permanece pendente
        outra = self._criar().get_json()
        self.client.patch(
            f"/entregas/{outra['id']}/status", json={'status': 'aceito'}
        )

        resp = self.client.get('/entregas?status=pendente')

        self.assertEqual(200, resp.status_code)
        statuses = {e['status'] for e in resp.get_json()}
        self.assertEqual({'pendente'}, statuses)

    def test_api05_listar_status_invalido(self):
        resp = self.client.get('/entregas?status=teleportando')

        self.assertEqual(400, resp.status_code)
        self.assertIn('Status inválido', resp.get_json()['error'])

    # ─── API06 / API07: GET por id ─────────────────────────────────────

    def test_api06_obter_existente(self):
        criada = self._criar().get_json()
        resp = self.client.get(f"/entregas/{criada['id']}")

        self.assertEqual(200, resp.status_code)
        self.assertEqual(criada['id'], resp.get_json()['id'])

    def test_api07_obter_inexistente(self):
        resp = self.client.get('/entregas/999999')

        self.assertEqual(404, resp.status_code)
        self.assertIn('error', resp.get_json())

    # ─── API08 / API09: PATCH status ───────────────────────────────────

    def test_api08_atualizar_status_valido_publica_evento(self):
        criada = self._criar().get_json()
        self.bus.publicados.clear()

        resp = self.client.patch(
            f"/entregas/{criada['id']}/status", json={'status': 'aceito'}
        )

        self.assertEqual(200, resp.status_code)
        self.assertEqual('aceito', resp.get_json()['status'])
        self.assertIn('entrega.status_atualizado', self._topicos_publicados())

    def test_api09_atualizar_status_invalido(self):
        criada = self._criar().get_json()
        resp = self.client.patch(
            f"/entregas/{criada['id']}/status", json={'status': 'voando'}
        )

        self.assertEqual(400, resp.status_code)
        self.assertIn('Status inválido', resp.get_json()['error'])

    def test_atualizar_status_sem_campo(self):
        criada = self._criar().get_json()
        resp = self.client.patch(f"/entregas/{criada['id']}/status", json={})

        self.assertEqual(400, resp.status_code)
        self.assertIn('error', resp.get_json())

    def test_atualizar_status_inexistente(self):
        resp = self.client.patch(
            '/entregas/999999/status', json={'status': 'aceito'}
        )

        self.assertEqual(404, resp.status_code)
        self.assertIn('error', resp.get_json())

    # ─── Cancelamento pelo cliente (fluxo do app Sprint 3) ─────────────

    def test_cliente_cancela_entrega_pendente(self):
        criada = self._criar().get_json()

        resp = self.client.patch(
            f"/entregas/{criada['id']}/status", json={'status': 'cancelado'}
        )

        self.assertEqual(200, resp.status_code)
        self.assertEqual('cancelado', resp.get_json()['status'])
        self.assertIn('entrega.status_atualizado', self._topicos_publicados())

    # ─── API10: GET /eventos ───────────────────────────────────────────

    def test_api10_listar_eventos(self):
        resp = self.client.get('/eventos')

        self.assertEqual(200, resp.status_code)
        self.assertIsInstance(resp.get_json(), list)


if __name__ == '__main__':
    unittest.main()
