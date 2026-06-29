"""Camada de notificação em tempo real (ponte RabbitMQ → WebSocket).

Consome os eventos de domínio publicados no MOM e os repassa às conexões
WebSocket abertas pelo app do prestador, permitindo notificação assíncrona
*sem polling*. Veja `hub.py`, `bridge.py` e `ws_routes.py`.
"""
