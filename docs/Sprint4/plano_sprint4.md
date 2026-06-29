# Sprint 4 — App do Prestador + Integração Final (real-time via MOM)

> Documento de planejamento e arquitetura da Sprint 4 do projeto **FastDelivery**
> (LDAMD — PUC Minas). Define o app Flutter do **prestador**, a **notificação
> assíncrona real** consumindo da fila do MOM e o refino visual dos dois apps.

## 1. Objetivo

Completar o sistema com o **aplicativo Flutter do prestador de serviços**, garantindo o
funcionamento do **fluxo completo de ponta a ponta** — da solicitação do cliente até a
conclusão pelo prestador — com **comunicação assíncrona via MOM** (RabbitMQ).

Estado anterior (Sprints 1–3, concluídas):

- **Backend** Flask REST (`Code/server/`) em Clean Architecture, SQLite, 5 endpoints.
- **MOM** RabbitMQ: exchange topic `fastdelivery.events`, fila durável
  `fastdelivery.entregas`, DLQ; eventos `entrega.criada` e `entrega.status_atualizado`
  publicados pelo `EntregaUseCases` e consumidos pelo `consumer_worker.py`.
- **App do cliente** (`Code/mobile/fastdelivery_cliente/`) em Clean Architecture
  (`http` + `ChangeNotifier`), atualização por **polling REST de 5s**; o cliente **não**
  fala direto com o RabbitMQ (convenção de `AGENTS.md`).

## 2. Critérios de avaliação do edital (seção 3.5 — 20 pts) → checklist

| Critério | Peso | Pts |
|---|---|---|
| Funcionalidade do app do prestador | 25% | 5,0 |
| Fluxo completo de ponta a ponta funcionando | 30% | 6,0 |
| Notificação assíncrona ao prestador via MOM/evento | 20% | 4,0 |
| Qualidade e clareza do screencast | 10% | 2,0 |
| Relatório técnico final (profundidade + referências) | 15% | 3,0 |

Checklist de entrega:

- [ ] App do prestador com **≥3 telas**: (a) lista de pendentes; (b) detalhe com
      **Aceitar/Recusar**; (c) acompanhamento das solicitações em andamento.
- [ ] Integração com os endpoints REST existentes (consultar, aceitar/recusar, status).
- [ ] **Notificação assíncrona**: ao criar uma solicitação no cliente, o app do prestador
      é notificado **sem atualização manual da tela**.
- [ ] **Fluxo ponta a ponta**: cliente cria → backend publica evento no MOM → prestador é
      notificado → prestador aceita → cliente é notificado da atualização.
- [ ] Screencast 3–5 min com os dois apps rodando simultaneamente.
- [ ] Relatório técnico ≥4 páginas com ≥3 referências (EDA, MOM, Clean Architecture, REST).
- [ ] Repositório com **commits incrementais** (regra 5.3: commit único = −20%).
- [ ] README com instruções de execução dos dois apps + backend + MOM.

## 3. Decisões de arquitetura

1. **Assincronismo real consumindo da fila (não polling).** Mecanismo escolhido pela
   simplicidade e robustez: **ponte WebSocket no backend**. Um consumidor RabbitMQ dentro
   do Flask lê os eventos do broker e os repassa ao app do prestador via WebSocket
   (`flask-sock` no backend; `web_socket_channel` no app). A notificação **trafega de fato
   pelo MOM**; o broker permanece privado (não exposto ao app — boa prática, coerente com
   a convenção da Sprint 3).
2. **App independente com cópia do core.** Novo projeto `fastdelivery_prestador` com sua
   própria cópia dos arquivos pequenos de `domain/`, `data/` e `core/`. O app do cliente
   (já testado) **não é alterado** na Fase 1. Os dois apps são executáveis de forma
   independente e têm `applicationId` distinto (instaláveis lado a lado no mesmo emulador).
3. **"Recusar" → status `cancelado`.** Reutiliza o contrato `PATCH /entregas/<id>/status`
   sem inventar novo status; nada muda no backend, schema ou enum.

### Por que a ponte usa uma fila NOVA

O exchange `fastdelivery.events` é do tipo **topic** e faz *fan-out* para múltiplas filas.
A fila durável `fastdelivery.entregas` já é consumida pelo `consumer_worker.py`. Se a ponte
consumisse a **mesma** fila, viraria *competing consumer* (cada evento iria para apenas um
dos consumidores). Por isso a ponte declara a própria fila **`fastdelivery.realtime`**
(não durável, auto-delete) ligada ao mesmo exchange — recebe a própria cópia de cada
evento, **sem interferir** no worker de histórico.

```
cliente (POST /entregas)
        │
        ▼
backend Flask  ──publica──►  exchange topic  fastdelivery.events
 (EntregaUseCases)                  │  (fan-out por routing key)
                                    ├──► fila fastdelivery.entregas ──► consumer_worker.py (histórico/DLQ)
                                    └──► fila fastdelivery.realtime ──► ponte (Flask) ──WebSocket──► app do prestador
                                                                                                 (tela atualiza sozinha)
```

## 4. Contratos reutilizados (sem inventar novos)

| Ação no prestador | Endpoint | Corpo |
|---|---|---|
| Listar pendentes | `GET /entregas?status=pendente` | — |
| Listar em andamento | `GET /entregas?status=aceito` e `?status=em_transito` | — |
| Detalhe | `GET /entregas/<id>` | — |
| Aceitar | `PATCH /entregas/<id>/status` | `{"status":"aceito"}` |
| Recusar | `PATCH /entregas/<id>/status` | `{"status":"cancelado"}` |
| Iniciar trânsito | `PATCH /entregas/<id>/status` | `{"status":"em_transito"}` |
| Concluir | `PATCH /entregas/<id>/status` | `{"status":"concluido"}` |
| Stream de eventos (novo, real-time) | `WS /ws/eventos` | recebe os payloads dos eventos MOM |

Eventos consumidos pela ponte (payload já definido em `app/mom/eventos.py`):
`entrega.criada` e `entrega.status_atualizado`.

> O prestador vê **todas** as entregas (não há `prestador_id` no schema; autenticação/
> atribuição estão fora do escopo, como o `cliente_id` de demonstração do cliente).

## 5. Implementação

### 5.1 Backend — ponte de eventos em tempo real (aditivo)

Módulo isolado `Code/server/app/realtime/`:

- `hub.py` — `RealtimeHub`: registro thread-safe de assinantes em memória (uma
  `queue.Queue` por conexão WS). `subscribe()→Queue`, `unsubscribe(q)`,
  `publish(evento: dict)`.
- `bridge.py` — `iniciar_ponte(hub)`: thread daemon com conexão pika própria (mesmos
  env vars do `barramento.py`), declara `fastdelivery.realtime` ligada a
  `fastdelivery.events` (routing keys `entrega.criada`, `entrega.status_atualizado`),
  consome e chama `hub.publish(...)`. Reconexão em loop; tolera broker fora do ar no boot.
- `ws_routes.py` — `flask-sock`, rota `@sock.route('/ws/eventos')`: registra a fila no hub
  no connect e envia cada evento ao cliente; remove no disconnect.

Modificações mínimas: `requirements.txt` (+ `flask-sock`), `main.py` (instancia hub, `Sock(app)`
+ rota no módulo, inicia a ponte só no `__main__`, `threaded=True`), `.env.example`.

> Os testes que importam `app` não são afetados: a ponte só sobe no `__main__` e
> `Sock(app)` apenas registra a rota.

### 5.2 App do prestador — `Code/mobile/fastdelivery_prestador/`

Clean Architecture espelhando o cliente:

```
lib/
├── main.dart · app.dart
├── core/config/api_config.dart (baseUrl + wsUrl) · core/http/api_exception.dart
└── features/entregas/
    ├── domain/   entrega.dart · status_entrega.dart (+ helpers do prestador)
    ├── data/     entrega_api_service.dart (+ transições) · eventos_realtime_service.dart (WS)
    ├── application/  pendentes_controller · detalhe_controller · andamento_controller
    └── presentation/ screens (home/pendentes/detalhe/andamento) · widgets (cópia)
```

- `EventosRealtimeService`: conecta `ws://<host>:5055/ws/eventos`, expõe `Stream` broadcast,
  com **reconexão automática** e **re-sync REST** a cada (re)conexão.
- `PendentesController`: carga inicial `GET ?status=pendente`; em `entrega.criada` insere na
  lista e dispara um **aviso visual** ("Nova solicitação recebida!"); em
  `entrega.status_atualizado` com `status_novo != pendente` remove da lista.
- `AndamentoController`: análogo para `aceito`/`em_transito`.

## 6. Critério de aceite — fluxo ponta a ponta (30%)

Com RabbitMQ + backend + `consumer_worker.py` + **os dois apps** rodando:
cliente cria solicitação → backend publica `entrega.criada` no RabbitMQ → ponte consome de
`fastdelivery.realtime` → push WebSocket → **prestador vê na hora** → prestador Aceita
(`PATCH aceito`) → backend publica `entrega.status_atualizado` → o **polling do cliente
(5s)** reflete "aceito". (O cliente segue em polling; apenas o prestador é real-time — a
Fase 2 não altera regra de negócio do cliente.)

## 7. Fase 2 — Refino visual (após a Fase 1 revisada)

Tema central `ThemeData` (paleta, tipografia, espaçamento, cantos, elevação), componentes
reutilizáveis (cards, botões, estados loading/erro/vazio), aplicados de forma consistente
nos **dois** apps. Amostra em **uma** tela antes de propagar. Sem alterar regras de negócio.

## 8. Como executar (resumo)

```powershell
# 1. MOM
cd Code\server; docker compose up -d
# 2. Backend (producer + ponte WebSocket)
py main.py
# 3. Consumidor de histórico (processo separado)
py consumer_worker.py
# 4. App do cliente
cd ..\mobile\fastdelivery_cliente; flutter run --dart-define=FASTDELIVERY_API_URL=http://10.0.2.2:5055
# 5. App do prestador
cd ..\fastdelivery_prestador; flutter run `
  --dart-define=FASTDELIVERY_API_URL=http://10.0.2.2:5055 `
  --dart-define=FASTDELIVERY_WS_URL=ws://10.0.2.2:5055/ws/eventos
```

## 9. Itens não-código da Sprint 4 (lembrete)

Screencast 3–5 min (10%) e relatório técnico ≥4 págs com ≥3 referências (15%) — produzidos
após a Fase 1/2, reaproveitando os diagramas e decisões deste documento.
