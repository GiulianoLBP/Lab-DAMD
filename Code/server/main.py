"""
FastDelivery — Backend REST com MOM (RabbitMQ)

Entry point do servidor Flask.
Inicializa o banco, o barramento de eventos e o consumidor assíncrono.
"""

import logging
import os

# Carrega variáveis do arquivo .env (ex.: RABBITMQ_HOST) antes de qualquer leitura de os.environ.
# O try/except garante que o servidor sobe mesmo se python-dotenv não estiver instalado.
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

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

# Por padrão o backend é um PRODUTOR PURO: ele publica eventos, e o consumo
# fica no consumer_worker.py (processo separado, ciclo de vida independente).
# RUN_CONSUMER_IN_PROCESS=true existe apenas como conveniência local.
RUN_CONSUMER_IN_PROCESS = os.environ.get(
    'RUN_CONSUMER_IN_PROCESS', 'false'
).strip().lower() not in ('false', '0', 'no')


def _iniciar_mom():
    """Inicia o barramento; registra o consumidor in-process apenas se habilitado."""
    if barramento.nome == 'in_memory' and not RUN_CONSUMER_IN_PROCESS:
        raise RuntimeError(
            'EVENT_BUS=in_memory exige RUN_CONSUMER_IN_PROCESS=true, pois o '
            'barramento de teste não cruza processos.'
        )
    if RUN_CONSUMER_IN_PROCESS:
        registrar_consumidores(barramento)
    else:
        logger.info(
            'Consumidor in-process DESLIGADO (RUN_CONSUMER_IN_PROCESS=false) — '
            'rode consumer_worker.py em um processo separado para consumir.'
        )
    barramento.iniciar_consumo()
    logger.info('MOM inicializado (mecanismo: %s)', barramento.nome)


# ─── Entry point ──────────────────────────────────────────────────────

if __name__ == '__main__':

    # 1. Banco de dados
    init_db()
    logger.info('Banco SQLite inicializado')

    # 2. MOM em background (antes do Flask, para não perder eventos).
    # A thread de consumo do barramento já é daemon; iniciar_consumo() não
    # bloqueia, então a inicialização é uniforme para qualquer mecanismo.
    _iniciar_mom()

    logger.info('╔══════════════════════════════════════════════╗')
    logger.info('║       FastDelivery — Backend REST + MOM      ║')
    logger.info('║  Mecanismo MOM.: %-26s ║', barramento.nome)
    logger.info('║  Endpoint......: http://localhost:5000       ║')
    logger.info('║  Eventos MOM...: GET /eventos                ║')
    logger.info('╚══════════════════════════════════════════════╝')
    logger.info(
        'Consumidor in-process: %s',
        'ON' if RUN_CONSUMER_IN_PROCESS else 'OFF (use consumer_worker.py)',
    )

    app.run(debug=True, use_reloader=False)
    # use_reloader=False evita que threads MOM sejam duplicadas no reload
