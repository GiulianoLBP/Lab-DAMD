# FastDelivery

Plataforma de delivery generalista desenvolvida como **Projeto Integrador de LDAMD**
(Laboratório de Desenvolvimento de Aplicações Móveis e Distribuídas — PUC Minas).

O sistema conecta **clientes** (que solicitam entregas) e **prestadores/entregadores**
(que aceitam e executam), com **backend REST em Flask**, **comunicação assíncrona via
MOM (RabbitMQ)** e **dois aplicativos Flutter** independentes (cliente e prestador).

## 🎥 Vídeo de apresentação

**▶️ https://youtu.be/nA9eXRoObc4** — demonstração do fluxo completo de ponta a ponta
(cliente cria → prestador é notificado em tempo real → aceita → cliente é atualizado).

---

## 📋 Visão geral

| Componente | Tecnologia | Pasta |
|---|---|---|
| Backend REST + MOM | Flask (Python), SQLite, RabbitMQ (pika), flask-sock | `Code/server/` |
| App do cliente | Flutter/Dart (`http`, `ChangeNotifier`) | `Code/mobile/fastdelivery_cliente/` |
| App do prestador | Flutter/Dart (`http`, `web_socket_channel`) | `Code/mobile/fastdelivery_prestador/` |
| Broker (MOM) | RabbitMQ (Docker) | `Code/server/docker-compose.yml` |

```
                 REST (HTTP)                 REST (HTTP) + WebSocket
   ┌───────────────┐   ┌───────────────────────────┐   ┌────────────────┐
   │  App Cliente  │──►│        Backend Flask        │◄──│ App Prestador  │
   │  (Flutter)    │   │  REST + Producer + Ponte WS │   │  (Flutter)     │
   │ polling 5s    │◄──│                             │──►│ tempo real     │
   └───────────────┘   └─────────────┬───────────────┘   └────────────────┘
                                      │ publica/consome (AMQP)
                                ┌─────▼──────┐
                                │  RabbitMQ  │  exchange topic: fastdelivery.events
                                │   (MOM)    │  filas: fastdelivery.entregas (worker),
                                └─────┬──────┘         fastdelivery.realtime (ponte WS), DLQ
                                      │ consome (histórico)
                              ┌───────▼─────────┐
                              │ consumer_worker │  grava histórico → GET /eventos
                              └─────────────────┘
```

---

## 🧭 Decisões de arquitetura

1. **Clean Architecture** no backend e nos dois apps — camadas `domain` (entidades/regra
   pura), `data`/`repositories` (acesso externo), `use_cases`/`application` (lógica) e
   `controllers`/`presentation` (entrada/UI). Controllers/telas ficam finos.
2. **Arquitetura orientada a eventos (EDA) com MOM (RabbitMQ)** — o backend publica
   eventos de domínio (`entrega.criada`, `entrega.status_atualizado`) num **exchange topic**
   (`fastdelivery.events`). Produtor e consumidor são **desacoplados** (ligados só pelo
   broker). Garantias: fila **durável**, **publisher confirms**, **ack manual**,
   **Dead-Letter Queue** e **idempotência** por `evento_id`.
3. **Cliente por polling, prestador em tempo real** — o app do cliente reflete mudanças
   por **polling REST (5s)** e nunca fala direto com o broker (simples e robusto). O app do
   prestador precisa de **notificação assíncrona real**: o backend sobe uma **ponte
   WebSocket** (`flask-sock`, rota `/ws/eventos`) que consome o RabbitMQ e empurra os
   eventos ao app, sem polling.
4. **Fila dedicada para a ponte** — a ponte consome `fastdelivery.realtime` (fila própria,
   ligada ao mesmo exchange topic), e **não** a `fastdelivery.entregas` do
   `consumer_worker.py`. Assim não há *competing consumers*: cada consumidor recebe sua
   cópia de cada evento via fan-out do exchange, sem interferir no histórico.
5. **Broker privado** — nenhum app fala AMQP diretamente; o RabbitMQ fica atrás do backend.
6. **"Recusar" reaproveita o status `cancelado`** — o contrato REST não tem um status
   "recusado"; a recusa do prestador é `PATCH status=cancelado`, evitando inventar um novo
   status (sem mudança em backend/schema).
7. **Dois apps independentes com core copiado** — cada app é executável por conta própria
   (`applicationId` distinto), compartilhando o mesmo *contrato* REST/MOM; os pequenos
   arquivos de domínio/dados são copiados, mantendo os apps desacoplados.
8. **Tema central (`AppTheme`)** — identidade visual única (paleta, tipografia, tokens de
   espaçamento/raio, estilos de componentes) compartilhada pelos dois apps.
9. **CORS habilitado** (`flask-cors`) para permitir os apps Flutter Web conversarem com o
   backend durante o desenvolvimento.

---

## 🗂️ O que foi feito em cada Sprint

### Sprint 1 — Backend REST (Clean Architecture)
API REST em Flask + SQLite, em camadas, com validação e tratamento de erros padronizado
(`{"error": "..."}`).

- [x] Clean Architecture (`domain`, `repositories`, `use_cases`, `controllers`)
- [x] SQLite com schema e inicialização automática
- [x] `Entrega` + enum `StatusEntrega`
- [x] Endpoints `POST /entregas`, `GET /entregas`, `GET /entregas/<id>`, `PATCH /entregas/<id>/status`
- [x] Validação e erros JSON; coleção Postman; README

### Sprint 2 — Integração com MOM (RabbitMQ)
Padrão **Publish-Subscribe** para eventos de entrega de forma assíncrona e confiável.

- [x] Barramento abstrato (`EventBus`) com `RabbitMQEventBus` (real) e `InMemoryEventBus` (testes)
- [x] Docker Compose do RabbitMQ; exchange topic + fila durável + DLQ
- [x] Produtor integrado aos use cases (`entrega.criada`, `entrega.status_atualizado`)
- [x] **Consumidor standalone** (`consumer_worker.py`) com histórico persistente e idempotente
- [x] Endpoint `GET /eventos`; publisher confirms, ack manual, reconexão; diagrama C4 e relatório

### Sprint 3 — App Flutter do Cliente
App do cliente em Clean Architecture (`http` + `ChangeNotifier`), atualização por **polling
REST de 5s** (sem acoplar o cliente ao broker).

- [x] Telas: lista, detalhe (com timeline de status) e formulário de nova entrega
- [x] Criar, listar, detalhar e **cancelar** (único status escrito pelo cliente)
- [x] Estados de carregando/erro/vazio reutilizáveis; testes de widget e de serviço
- [x] URL da API via `--dart-define` (sem hardcode)

### Sprint 4 — App Flutter do Prestador + tempo real + entrega final
App do prestador (separado) e **notificação assíncrona real** via MOM, fechando o fluxo
ponta a ponta. Refino visual dos dois apps.

- [x] App do prestador com **3 telas**: pendentes, detalhe (Aceitar/Recusar) e em andamento
- [x] **Ponte RabbitMQ → WebSocket** (`/ws/eventos`, fila `fastdelivery.realtime`): prestador
      notificado em tempo real, sem polling
- [x] Fluxo ponta a ponta: cliente cria → prestador notificado → aceita → cliente atualizado
- [x] Tema central aplicado aos dois apps (coerência visual)
- [x] [Relatório técnico](docs/Sprint4/Relatorio_Sprint4_FastDelivery.pdf), [roteiro do vídeo](docs/Sprint4/roteiro.md) e [vídeo](https://youtu.be/nA9eXRoObc4)

---

## 🧱 Estrutura do repositório

```
Lab-DAMD/
├── Code/
│   ├── server/                              # Backend Flask + MOM
│   │   ├── app/
│   │   │   ├── domain/        models.py     # Entrega, StatusEntrega
│   │   │   ├── repositories/                # SQLite (entregas + eventos_processados)
│   │   │   ├── use_cases/                   # Regra de negócio + publicação de eventos
│   │   │   ├── controllers/                 # Rotas REST (thin)
│   │   │   ├── mom/                         # EventBus (RabbitMQ/InMemory), producer, consumer, eventos
│   │   │   └── realtime/                    # Ponte RabbitMQ→WebSocket (hub, bridge, ws_routes)
│   │   ├── main.py                          # Entry point (REST + producer + ponte WS)
│   │   ├── consumer_worker.py               # Consumidor standalone (histórico)
│   │   ├── docker-compose.yml               # RabbitMQ
│   │   ├── requirements.txt                 # Flask, pika, flask-sock, flask-cors, python-dotenv
│   │   └── tests/                           # Testes (API, MOM, realtime)
│   └── mobile/
│       ├── fastdelivery_cliente/            # App Flutter do cliente (Sprint 3)
│       └── fastdelivery_prestador/          # App Flutter do prestador (Sprint 4)
├── docs/
│   ├── Sprint2/                             # MOM: eventos, relatório, evidências
│   ├── Sprint3/                             # Specs e arquitetura do app cliente
│   └── Sprint4/                             # Plano, relatório, roteiro do vídeo e evidências
├── postman_collection.json                  # Coleção de testes da API
└── README.md                                # Este arquivo
```

---

## ▶️ Como rodar

### Pré-requisitos
- Python 3.10+ (testado em 3.14) e Docker/Docker Compose
- Flutter 3.x / Dart 3.12+ (alvo: emulador Android **ou** Chrome/web)
- Windows: use `py` (Python Launcher)

### 1) Backend + MOM (3 terminais em `Code/server`)

```powershell
# Terminal 1 — RabbitMQ (MOM)
cd Code\server
docker compose up -d

# Terminal 2 — Backend (REST + producer + ponte WebSocket)
py -m venv .venv
.\.venv\Scripts\Activate.ps1            # macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
Copy-Item .env.example .env             # 1ª vez
python main.py                          # confirme no log: "Tempo real....: WS  /ws/eventos"

# Terminal 3 — Consumidor de histórico (opcional; necessário só para o GET /eventos)
python consumer_worker.py
```

O backend sobe em `http://localhost:5055`. RabbitMQ Management: `http://localhost:15672`
(`guest`/`guest`).

> O `consumer_worker.py` é **opcional** para o fluxo de tempo real (a ponte WebSocket é
> independente). Ele alimenta o histórico do `GET /eventos`. Alternativa: subir o backend
> com `RUN_CONSUMER_IN_PROCESS=true` para consumir no próprio processo.

### 2) Apps Flutter (1 terminal cada)

```powershell
# App do CLIENTE
cd Code\mobile\fastdelivery_cliente
flutter pub get
flutter run -d chrome --dart-define=FASTDELIVERY_API_URL=http://localhost:5055
# Emulador Android: flutter run --dart-define=FASTDELIVERY_API_URL=http://10.0.2.2:5055

# App do PRESTADOR
cd ..\fastdelivery_prestador
flutter pub get
flutter run -d chrome `
  --dart-define=FASTDELIVERY_API_URL=http://localhost:5055 `
  --dart-define=FASTDELIVERY_WS_URL=ws://localhost:5055/ws/eventos
# Emulador Android: troque por http://10.0.2.2:5055 e ws://10.0.2.2:5055/ws/eventos
```

> **Endereços:** emulador Android usa `10.0.2.2` (alias do host). Em desktop, se `localhost`
> falhar (resolve para IPv6 antes do IPv4), use `127.0.0.1`. Se `FASTDELIVERY_WS_URL` não for
> passada, ela é derivada de `FASTDELIVERY_API_URL`.

**Fluxo ponta a ponta:** crie uma entrega no app do cliente → ela aparece **na hora** no
app do prestador (MOM → WebSocket) → aceite no prestador → o cliente reflete o status em
até ~5s (polling).

### Variáveis de ambiente (backend)
- `EVENT_BUS=rabbitmq` (padrão) | `in_memory` (apenas testes)
- `RABBITMQ_HOST/PORT/USER/PASS` ou `RABBITMQ_URL`
- `RUN_CONSUMER_IN_PROCESS=false` (padrão; consumidor é o `consumer_worker.py`)
- `FASTDELIVERY_API_HOST/PORT` (padrão `0.0.0.0:5055`)

---

## 🔌 API REST + WebSocket

| Método | Rota | Descrição |
|---|---|---|
| `POST` | `/entregas` | Cria uma solicitação (status inicial `pendente`) |
| `GET` | `/entregas` | Lista entregas (filtro opcional `?status=`) |
| `GET` | `/entregas/<id>` | Detalha uma entrega |
| `PATCH` | `/entregas/<id>/status` | Atualiza o status (`aceito`/`em_transito`/`concluido`/`cancelado`) |
| `GET` | `/eventos` | Histórico de eventos processados pelo consumidor (`?ultimos=N`) |
| `WS` | `/ws/eventos` | Stream de eventos do MOM em tempo real (usado pelo app do prestador) |

```bash
# Criar
curl -X POST http://localhost:5055/entregas -H "Content-Type: application/json" \
  -d '{"descricao":"Buscar encomenda","origem":"Rua A, 100","destino":"Rua B, 200","cliente_id":"cliente-uuid-123"}'

# Listar (com filtro) / detalhar
curl "http://localhost:5055/entregas?status=pendente"
curl http://localhost:5055/entregas/1

# Atualizar status (aceitar)
curl -X PATCH http://localhost:5055/entregas/1/status \
  -H "Content-Type: application/json" -d '{"status":"aceito"}'

# Histórico de eventos do MOM
curl http://localhost:5055/eventos
```

Resposta de uma entrega:
```json
{
  "id": 1, "descricao": "Buscar encomenda", "origem": "Rua A, 100",
  "destino": "Rua B, 200", "status": "pendente", "cliente_id": "cliente-uuid-123",
  "criado_em": "2026-05-11T10:00:00", "atualizado_em": "2026-05-11T10:00:00"
}
```

Erros sempre em JSON: `{"error": "..."}` (400 validação, 404 não encontrado).

### Eventos do MOM
- `entrega.criada` — publicado ao criar uma entrega.
- `entrega.status_atualizado` — publicado ao alterar o status.

Topologia: exchange topic `fastdelivery.events` → filas `fastdelivery.entregas` (durável,
worker de histórico) e `fastdelivery.realtime` (ponte WebSocket) + DLQ.

---

## 📊 Schema do banco (SQLite)

**`entregas`**

| Campo | Tipo | Restrições |
|-------|------|-----------|
| `id` | INTEGER | PK, AUTOINCREMENT |
| `descricao` / `origem` / `destino` | TEXT | NOT NULL |
| `status` | TEXT | NOT NULL, DEFAULT `pendente` |
| `cliente_id` | TEXT | NOT NULL |
| `criado_em` / `atualizado_em` | TEXT | NOT NULL (ISO 8601) |

Valores de `status`: `pendente` → `aceito` → `em_transito` → `concluido`, e `cancelado`
(estado final alternativo).

**`eventos_processados`** — histórico persistente do consumidor (chave `evento_id` garante
idempotência em caso de redelivery); base do `GET /eventos`.

---

## 🧪 Testes

```powershell
# Backend (em Code/server, com a venv ativa)
python -m unittest discover -s tests

# Apps Flutter (em cada pasta do app)
flutter analyze
flutter test
```

A API também pode ser testada importando `postman_collection.json` no Postman/Insomnia.
Evidências de execução: `docs/Image/` (endpoints da Sprint 1) e
`docs/Sprint4/evidencias/` (fluxo ponta a ponta).

---

## 📚 Documentação por sprint

- **Sprint 2:** [eventos/tópicos](docs/Sprint2/eventos.md) · [relatório](docs/Sprint2/Relatorio_Sprint2_RabbitMQ.md) · [evidências](docs/Sprint2/evidencias/)
- **Sprint 3:** [relatório de atendimento](docs/Sprint3/relatorio_atendimento_sprint3.md) · [evidências (analyze/test)](docs/Sprint3/evidencias/)
- **Sprint 4:** [plano e arquitetura](docs/Sprint4/plano_sprint4.md) · [relatório técnico](docs/Sprint4/Relatorio_Sprint4_FastDelivery.pdf) · [roteiro do vídeo](docs/Sprint4/roteiro.md)

---

## 🛠️ Tecnologias

- **Backend:** Flask, pika (AMQP), flask-sock (WebSocket), flask-cors, python-dotenv, SQLite
- **MOM:** RabbitMQ (Docker)
- **Mobile:** Flutter/Dart — `http`, `web_socket_channel`, `ChangeNotifier`

---

**Desenvolvido para:** Laboratório de Desenvolvimento de Aplicações Móveis e Distribuídas
(LDAMD) — PUC Minas.
