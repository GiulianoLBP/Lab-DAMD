# FastDelivery - Sprint 3 - Specs do App Cliente

## Fonte dos requisitos

Estas specs foram derivadas de:

- `docs/Projeto_LAMD_60445_2026_1.pdf`, secao 3.4: Sprint 3 - Aplicativo Flutter para o Cliente.
- `docs/FastDelivery_Proposta_Sprint1.pdf`: dominio FastDelivery, perfis Cliente e Prestador, ciclo de vida da entrega.
- Contratos atuais do backend em `Code/server/`.
- Relatorio e evidencias da Sprint 2 em `docs/Sprint2/`.

## Objetivo da Sprint 3

Entregar um app Flutter funcional para o cliente do FastDelivery, integrado ao backend REST existente, com atualizacao assincrona de estado e interface simples, bonita e confiavel.

O app deve permitir que o cliente:

1. Crie uma solicitacao de entrega.
2. Liste suas entregas.
3. Veja os detalhes de uma entrega.
4. Acompanhe mudancas de status sem atualizar manualmente a tela.
5. Cancele uma entrega enquanto ela estiver pendente.

## Decisoes fechadas para manter simplicidade

| Pergunta de design | Decisao recomendada |
|---|---|
| Como implementar atualizacao assincrona na Sprint 3? | Polling REST com intervalo definido, usando `GET /entregas` na lista e `GET /entregas/<id>` nos detalhes. E simples, aceito pelo enunciado e evita acoplar o app cliente ao RabbitMQ. |
| Qual intervalo usar? | 5 segundos por padrao. E curto o bastante para demonstracao e simples de explicar. |
| O app cliente deve consumir RabbitMQ diretamente? | Nao na Sprint 3. O RabbitMQ continua no backend/worker. O cliente reflete o estado do servidor via polling REST. |
| Como simular aceite do prestador antes da Sprint 4? | Usar Postman/curl chamando `PATCH /entregas/<id>/status` com `aceito`, `em_transito` ou `concluido`; o app cliente deve atualizar sozinho. |
| Onde criar o app Flutter? | `Code/mobile/fastdelivery_cliente/`, deixando espaco natural para `Code/mobile/fastdelivery_entregador/` na Sprint 4. |
| Deve haver autenticacao? | Nao. Usar um `cliente_id` fixo de demonstracao, por exemplo `cliente-demo-001`, enquanto autenticacao fica fora do escopo. |
| Deve alterar o backend? | Evitar. A Sprint 3 deve consumir os endpoints existentes. Mudancas no backend so entram se forem pequenas, testadas e nao quebrarem Sprint 1/2. |

## Guardrails das Sprints anteriores

Nao quebrar estes contratos:

- `POST /entregas` cria entrega com `status = pendente` e publica `entrega.criada`.
- `GET /entregas` lista entregas e aceita filtro opcional `?status=...`.
- `GET /entregas/<id>` retorna a entrega ou `404`.
- `PATCH /entregas/<id>/status` altera status e publica `entrega.status_atualizado`.
- `GET /eventos` mostra historico persistente processado pelo consumidor.
- RabbitMQ continua sendo o barramento real padrao.
- `InMemoryEventBus` continua reservado apenas para testes.
- O backend deve seguir produtor puro por padrao, com `RUN_CONSUMER_IN_PROCESS=false`.
- O worker `consumer_worker.py` continua sendo processo independente.
- Respostas de erro continuam no formato `{"error": "mensagem"}`.

## Entregaveis da Sprint 3

1. App Flutter cliente em `Code/mobile/fastdelivery_cliente/`.
2. Minimo de 3 telas:
   - Listagem de entregas do cliente.
   - Detalhes da entrega.
   - Criacao de nova entrega.
3. Integracao com os endpoints REST existentes.
4. Atualizacao assincrona por polling, demonstravel sem toque manual do usuario.
5. Diagrama de arquitetura do app Flutter.
6. Testes automatizados e roteiro manual de demonstracao.
7. Evidencias em `docs/Sprint3/evidencias/` quando a implementacao for executada.

## Documentos desta pasta

- `spec_app_cliente.md`: escopo funcional, backlog de desenvolvimento e contratos REST.
- `arquitetura_app_cliente.md`: estrutura Flutter recomendada, fluxo de dados e diagrama.
- `plano_testes_e_aceite.md`: testes obrigatorios, roteiro de demo e criterios de aceite.

