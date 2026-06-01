"""
Worker consumidor STANDALONE — roda em um processo separado do backend Flask.

Objetivo: provar que produtor e consumidor têm CICLOS DE VIDA INDEPENDENTES.
O único elo entre eles é o broker (RabbitMQ). Este processo:
  - não importa o Flask;
  - não expõe nenhuma rota REST;
  - apenas assina os tópicos no RabbitMQ e processa o que chegar.

Como isso prova o desacoplamento de ciclo de vida:
  1. Suba este worker SEM o backend rodando (ou suba o backend primeiro,
     crie entregas com o worker desligado e depois ligue o worker).
  2. Como a fila 'fastdelivery.entregas' é durável, os eventos publicados
     enquanto o worker estava fora ficam acumulados no broker.
  3. Ao subir, o worker processa o backlog — porque o produtor e o consumidor
     não dependem um do outro, só do broker.

Uso:
    cd Code/server
    $env:RABBITMQ_HOST = "localhost"   # ou via .env
    py consumer_worker.py
"""

import logging
import time

# Carrega o .env (RABBITMQ_HOST etc.) antes de qualquer leitura de variável de ambiente.
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

from app.mom.barramento import criar_barramento
from app.mom.consumer import registrar_consumidores
from app.database import init_db

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S',
)
logger = logging.getLogger('ConsumerWorker')


if __name__ == '__main__':
    bus = criar_barramento()

    if bus.nome != 'rabbitmq':
        logger.error(
            'Mecanismo atual: %s. O worker standalone só faz sentido com RabbitMQ, '
            'pois o InMemoryEventBus vive na memória de UM processo e não cruza '
            'a fronteira de processos. Use EVENT_BUS=rabbitmq.',
            bus.nome,
        )
        raise SystemExit(1)

    init_db()
    registrar_consumidores(bus)
    bus.iniciar_consumo()

    logger.info('╔══════════════════════════════════════════════════════╗')
    logger.info('║  WORKER CONSUMIDOR STANDALONE (processo independente) ║')
    logger.info('║  Mecanismo: %-40s ║', bus.nome)
    logger.info('║  Sem Flask, sem REST — apenas escutando o broker.     ║')
    logger.info('║  Aguardando eventos... (Ctrl+C para encerrar)         ║')
    logger.info('╚══════════════════════════════════════════════════════╝')

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        bus.parar()
        logger.info('Worker encerrado.')
