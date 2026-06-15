# Repository Guidelines

## Project Structure & Module Organization

This repository contains a Flask REST API for FastDelivery. Main backend code lives in `Code/server/`.

- `Code/server/main.py`: Flask entry point and error handlers.
- `Code/server/app/domain/`: domain entities and enums, such as `Entrega` and `StatusEntrega`.
- `Code/server/app/repositories/`: SQLite persistence logic.
- `Code/server/app/use_cases/`: business rules and validation.
- `Code/server/app/controllers/`: HTTP routes and JSON responses.
- `Code/server/app/mom/`: message-oriented middleware (event bus, producer, consumer, event catalog).
- `Code/server/consumer_worker.py`: standalone consumer process (no Flask), proves producer/consumer lifecycle independence.
- `Code/server/docker-compose.yml`: local RabbitMQ broker (AMQP 5672, management UI 15672).
- `Code/server/tests/`: automated tests for the MOM layer and API.
- `Code/mobile/fastdelivery_cliente/`: Flutter client app (Sprint 3) — list/detail/create + cancel of entregas over REST, with 5s polling. Layered: `core/`, `features/entregas/{domain,data,application,presentation}`.
- `docs/`: PDFs, architecture notes, Draw.io files, and endpoint screenshots.
- `docs/Sprint3/`: Sprint 3 specs, Flutter client architecture, tests, acceptance criteria, and future evidence.
- `specs/changes.md`: messaging analysis and the Redis→RabbitMQ migration record.
- `postman_collection.json`: manual API test collection.

## Messaging / Async (MOM)

The system uses **RabbitMQ** (AMQP, via `pika`) as the single central broker for
asynchronous communication. The producer publishes domain events and never calls
the consumer directly; the only link between them is the broker.

- Event bus lives behind the `EventBus` Strategy interface in `app/mom/barramento.py`.
  `RabbitMQEventBus` is the real implementation; `InMemoryEventBus` exists **only for tests**.
- Topology (declared idempotently on startup): topic exchange `fastdelivery.events`,
  durable queue `fastdelivery.entregas` (bound with `#`), and a Dead-Letter
  exchange/queue (`fastdelivery.dlx` / `fastdelivery.dlq`).
- Reliability: durable queues + persistent messages (`delivery_mode=2`), publisher
  confirms (no silent loss), one reconnect retry with the same idempotent event ID,
  manual ack, and `nack(requeue=False)` → DLQ on handler failure.
- Event handlers in `app/mom/consumer.py` must **not** swallow exceptions — letting
  them propagate is what routes poison messages to the DLQ.
- Events are emitted from `EntregaUseCases` (create + status change) through
  `EntregaEventProducer`; topics are defined in `app/mom/eventos.py`.
- Config via env (`.env`): `EVENT_BUS`, `RABBITMQ_HOST/PORT/USER/PASS` (or `RABBITMQ_URL`) and
  `RUN_CONSUMER_IN_PROCESS` (`false` = backend is producer-only, run `consumer_worker.py` separately).

## Sprint 3 / Flutter Client

Sprint 3 is scoped to the **client** Flutter app only. Follow the specs in
`docs/Sprint3/` before implementation. The recommended app location is
`Code/mobile/fastdelivery_cliente/`.

- Keep the client app integrated through the existing REST endpoints from Sprint 1.
- Use simple polling (default 5 seconds) for client-side asynchronous status refresh;
  do not connect the mobile client directly to RabbitMQ in Sprint 3.
- Preserve all Sprint 2 MOM behavior: RabbitMQ remains the real broker, the Flask
  backend remains producer-only by default, and `consumer_worker.py` remains the
  independent consumer.
- Use a fixed demo `cliente_id` until authentication is introduced in a future scope.
- Do not implement prestador/entregador workflows in the client app; those belong to Sprint 4.

## Build, Test, and Development Commands

Run commands from `Code/server/` unless noted otherwise.

```powershell
py -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
docker-compose up -d          # starts the RabbitMQ broker (skip for InMemory test fallback)
Copy-Item .env.example .env   # configure RABBITMQ_* (first run only)
py main.py                    # backend / producer
py consumer_worker.py         # consumer, in a separate terminal (when RUN_CONSUMER_IN_PROCESS=false)
```

`pip install -r requirements.txt` installs Flask and `pika`. `docker-compose up -d`
starts RabbitMQ (AMQP on 5672, management UI on http://localhost:15672, guest/guest).
`py main.py` initializes `entregas.db` automatically and starts the API at
`http://localhost:5055`. RabbitMQ is the default bus; `EVENT_BUS=in_memory`
enables the in-memory implementation explicitly for tests only.

There is no build step for this backend. For manual verification, import `postman_collection.json` into Postman or run curl requests from the README.

For the Flutter client, run from `Code/mobile/fastdelivery_cliente/`:

```powershell
flutter pub get
flutter analyze
flutter test
dart format .
flutter run --dart-define=FASTDELIVERY_API_URL=http://10.0.2.2:5055   # Android emulator -> backend local
```

The only runtime dependency is `http`. The API base URL is injected via
`--dart-define=FASTDELIVERY_API_URL` (default `http://localhost:5055`); do not
hardcode it or change the backend just for URLs.

This Windows environment reserves TCP ports `4940-5039`, which includes Flask's
traditional port `5000`. Keep the FastDelivery API default on
`FASTDELIVERY_API_PORT=5055`; Android emulator clients should use
`http://10.0.2.2:5055`.

## Coding Style & Naming Conventions

Use Python 3.8+ with 4-space indentation. Follow the existing layered architecture: controllers should stay thin, use cases should hold business logic, and repositories should handle SQLite access. Use `snake_case` for modules, functions, variables, and route handlers. Use `PascalCase` for dataclasses, enums, and exception classes. Keep JSON error responses in the existing format: `{'error': 'message'}`.

## Testing Guidelines

Add automated tests under `Code/server/tests/` using `test_*.py` filenames. Prefer Flask's test client for endpoint tests and isolate database state so tests do not depend on a developer's local `entregas.db`. Cover successful and error paths for `POST /entregas`, `GET /entregas`, `GET /entregas/<id>`, `PATCH /entregas/<id>/status`, and `GET /eventos`. For the MOM layer, use `InMemoryEventBus` (no broker required) to assert that producing an event reaches the registered consumer handler. Until an automated test runner is configured, document manual verification with Postman or curl.

## Commit & Pull Request Guidelines

Recent commits use short imperative subjects, sometimes with Conventional Commit prefixes, for example `feat: add input validation and error handling` or `docs: add README with setup instructions and schema documentation`. Prefer that style and keep commits focused.

Pull requests should include a concise summary, test evidence, and any API or schema changes. Link related issues when available. For user-visible endpoint behavior, include curl examples, Postman evidence, or screenshots under `docs/Image/`.

## Security & Configuration Tips

Do not commit local virtual environments, generated SQLite databases, secrets, or machine-specific configuration. Keep dependencies pinned in `Code/server/requirements.txt`.
