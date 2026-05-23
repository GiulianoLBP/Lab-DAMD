"""
FastDelivery — Backend REST com MOM (Redis Pub/Sub ou InMemory)

Entry point do servidor Flask.
Inicializa o banco, o barramento de eventos e o consumidor assíncrono.
"""

import logging
import threading

from flask import Flask, jsonify
from app.database import init_db
from app.repositories.entrega_repository import EntregaRepository
from app.use_cases.entrega_use_cases import EntregaUseCases
from app.controllers.entrega_controller import entrega_bp, init_use_cases
from app.mom.barramento import criar_barramento
from app.mom.consumer import registrar_consumidores
from app.mom.producer import EntregaEventProducer

# ─── Configuração de logging ──────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S',
)
logger = logging.getLogger('FastDelivery')

# ─── Aplicação Flask ──────────────────────────────────────────────────

app = Flask(__name__)
app.register_blueprint(entrega_bp)


@app.errorhandler(404)
def not_found(_e):
    return jsonify({'error': 'Recurso não encontrado'}), 404


@app.errorhandler(405)
def method_not_allowed(_e):
    return jsonify({'error': 'Método não permitido'}), 405


@app.errorhandler(500)
def internal_error(_e):
    return jsonify({'error': 'Erro interno do servidor'}), 500


# ─── MOM: barramento de eventos ───────────────────────────────────────

barramento = criar_barramento()
event_producer = EntregaEventProducer(barramento)

# Conecta o produtor aos casos de uso
repository = EntregaRepository()
use_cases = EntregaUseCases(repository=repository, event_producer=event_producer)
init_use_cases(use_cases)


# ─── Consumidor de eventos (thread em background) ─────────────────────

def _iniciar_mom():
    """Registra consumidores e inicia o loop de escuta."""
    registrar_consumidores(barramento)
    barramento.iniciar_consumo()
    logger.info('MOM inicializado (mecanismo: %s)', barramento.nome)


# ─── Entry point ──────────────────────────────────────────────────────

if __name__ == '__main__':

    # 1. Banco de dados
    init_db()
    logger.info('Banco SQLite inicializado')

    # 2. MOM em background (antes do Flask, para não perder eventos)
    if barramento.nome == 'redis':
        # Redis: inicia síncrono (a thread de consumo é daemon)
        _iniciar_mom()
    else:
        # InMemory: inicia em thread separada
        mom_thread = threading.Thread(target=_iniciar_mom, daemon=True)
        mom_thread.start()

    logger.info('╔══════════════════════════════════════════════╗')
    logger.info('║       FastDelivery — Backend REST + MOM      ║')
    logger.info('║  Mecanismo MOM.: %-26s ║', barramento.nome)
    logger.info('║  Endpoint......: http://localhost:5000       ║')
    logger.info('║  Eventos MOM...: GET /eventos                ║')
    logger.info('╚══════════════════════════════════════════════╝')

    app.run(debug=True, use_reloader=False)
    # use_reloader=False evita que threads MOM sejam duplicadas no reload