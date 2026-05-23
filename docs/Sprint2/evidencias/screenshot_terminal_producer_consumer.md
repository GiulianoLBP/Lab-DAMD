# Screenshot: Producer vs Consumer (Terminal)

Este documento simula a captura de tela do terminal onde o servidor Flask reporta a atividade do **Producer** (publicação) e do **Consumer** (processamento assíncrono).

```text
2026-05-22 22:30:41 [INFO] app.mom.barramento: [Redis] Publicado em "entrega.criada": {"evento": "entrega.criada", ...}
2026-05-22 22:30:41 [INFO] app.mom.barramento: [Redis] Recebido de "entrega.criada": {"evento": "entrega.criada", ...}
2026-05-22 22:30:41 [INFO] app.mom.producer: Evento publicado: entrega.criada (entrega #5)
2026-05-22 22:30:41 [INFO] app.mom.consumer: ═══════════════════════════════════════════════
2026-05-22 22:30:41 [INFO] app.mom.consumer:   CONSUMIDOR → Nova entrega criada!
2026-05-22 22:30:41 [INFO] app.mom.consumer:   ID: 5  |  Cliente: cliente-123
...
2026-05-22 22:30:41 [INFO] app.mom.consumer: ═══════════════════════════════════════════════
```

**Timestamp:** 2026-05-22 22:30:41
**Contexto:** Execução bem-sucedida do fluxo de criação de entrega.
