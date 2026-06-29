# fastdelivery_prestador

App Flutter do **prestador** (Sprint 4 do FastDelivery — LDAMD/PUC Minas). Recebe
solicitações de entrega **em tempo real** (WebSocket sobre o MOM), permite
**aceitar/recusar** e **acompanhar** as entregas em andamento. É um app
independente do app do cliente, reutilizando os mesmos contratos REST do backend.

## Telas

1. **Pendentes** — lista de solicitações `pendente`; novas chegam ao vivo (com aviso).
2. **Detalhe** — dados da solicitação + ações: Aceitar / Recusar e avanço de status
   (Iniciar trânsito → Concluir).
3. **Em andamento** — solicitações `aceito`/`em_transito` sob responsabilidade do prestador.

## Arquitetura

Clean Architecture (igual ao app cliente):

```
lib/
├── main.dart · app.dart
├── core/          config (baseUrl + wsUrl) · http (ApiException)
└── features/entregas/
    ├── domain/        Entrega · StatusEntrega (+ ações do prestador)
    ├── data/          EntregaApiService (REST) · EventosRealtimeService (WebSocket)
    ├── application/    PendentesController · DetalheController · AndamentoController
    └── presentation/   screens · widgets
```

A notificação assíncrona usa o WebSocket `/ws/eventos` do backend (driver
`web_socket_channel`), com reconexão automática e re-sincronização via REST.

## Como executar

Requer o backend + RabbitMQ no ar (ver README na raiz do repositório).

```powershell
flutter pub get
flutter analyze
flutter test
flutter run `
  --dart-define=FASTDELIVERY_API_URL=http://10.0.2.2:5055 `
  --dart-define=FASTDELIVERY_WS_URL=ws://10.0.2.2:5055/ws/eventos
```

- **Emulador Android:** `10.0.2.2`. **Desktop/web:** use `127.0.0.1` (evita o
  `localhost`→IPv6 em algumas máquinas). Se `FASTDELIVERY_WS_URL` não for passada,
  ela é derivada de `FASTDELIVERY_API_URL`.

## Dependências

- `http` — chamadas REST (mesmos endpoints do app cliente).
- `web_socket_channel` — conexão de tempo real com `/ws/eventos`.
