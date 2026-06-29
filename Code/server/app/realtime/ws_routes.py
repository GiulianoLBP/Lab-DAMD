"""
Rota WebSocket de eventos em tempo real (``/ws/eventos``), via flask-sock.

Cada conexão registra a própria fila no :class:`RealtimeHub` e repassa os eventos
recebidos do broker (pela ponte) ao cliente como JSON. É aqui que o prestador é
notificado: o app abre esta conexão e recebe ``entrega.criada`` /
``entrega.status_atualizado`` em tempo real, sem polling.

Mensagens de ``keepalive`` são enviadas em janelas ociosas — elas mantêm a
conexão viva atrás de proxies e, principalmente, detectam o cliente desconectado
(o ``send`` falha), permitindo liberar o assinante. O app ignora esses pacotes.
"""

from __future__ import annotations

import json
import logging
import queue

from flask import Flask
from flask_sock import Sock

from app.realtime.hub import RealtimeHub

logger = logging.getLogger(__name__)

# Janela máxima de espera antes de enviar um keepalive (também detecta disconnect).
_KEEPALIVE_SEGUNDOS = 25


def registrar_websocket(app: Flask, hub: RealtimeHub) -> Sock:
    """Registra a rota ``/ws/eventos`` no app Flask, ligada ao ``hub`` informado."""
    sock = Sock(app)

    @sock.route('/ws/eventos')
    def eventos(ws):  # noqa: ANN001 — assinatura definida pelo flask-sock
        fila = hub.subscribe()
        try:
            while True:
                try:
                    evento = fila.get(timeout=_KEEPALIVE_SEGUNDOS)
                except queue.Empty:
                    # Sem eventos na janela: envia keepalive. Se o cliente caiu,
                    # o send levanta exceção e caímos no finally (unsubscribe).
                    ws.send(json.dumps({'evento': 'keepalive'}))
                    continue
                ws.send(json.dumps(evento))
        except Exception:
            # ConnectionClosed (cliente saiu) ou falha de envio: encerra a conexão.
            logger.info('[Realtime] Conexão WebSocket encerrada')
        finally:
            hub.unsubscribe(fila)

    return sock
