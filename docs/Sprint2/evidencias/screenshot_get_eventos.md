# Screenshot: GET /eventos (Histórico processado)

Este documento simula a resposta do endpoint `GET /eventos`, que demonstra que o consumidor (thread daemon) recebeu e registrou os eventos processados com sucesso.

```json
[
  {
    "dados": {
      "cliente_id": "cliente-123",
      "descricao": "Pacote Teste MOM",
      "id": 5,
      ...
    },
    "evento": "entrega.criada",
    "mensagem": "Nova entrega criada: Pacote Teste MOM",
    "processado_em": "2026-05-22T22:30:41",
    "tipo": "entrega.criada"
  },
  {
    "dados": {
      "id": 1,
      "status_novo": "aceito",
      ...
    },
    "evento": "entrega.status_atualizado",
    "mensagem": "Entrega #1 alterada para aceito",
    "processado_em": "2026-05-22T22:30:41",
    "tipo": "entrega.status_atualizado"
  }
]
```

**Timestamp:** 2026-05-22 22:30:41
**Endpoint:** `http://localhost:5000/eventos`
**Status:** 200 OK
