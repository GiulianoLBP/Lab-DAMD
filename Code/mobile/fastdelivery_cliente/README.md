# FastDelivery — App Cliente (Sprint 3)

App Flutter do **perfil Cliente** do FastDelivery. Permite criar, listar,
detalhar e cancelar entregas, consumindo a API REST do backend Flask
(`Code/server/`). O acompanhamento de status é assíncrono por **polling REST a
cada 5 segundos** — o app reflete mudanças feitas no servidor sem o usuário
tocar na tela e **sem conectar ao RabbitMQ** (isso continua no backend/worker).

> Escopo da Sprint 3: somente o Cliente. Telas e ações do prestador/entregador
> são da Sprint 4.

## Telas

1. **Lista de entregas** — carrega ao abrir, atualiza por polling, com estados de
   carregamento, vazio e erro (com "tentar novamente").
2. **Detalhes da entrega** — todos os campos, linha de progresso do status
   (`pendente → aceito → em_transito → concluido`, com `cancelado` à parte),
   atualização automática e botão **Cancelar** apenas quando `pendente`.
3. **Nova entrega** — formulário com validação (`descricao`, `origem`, `destino`);
   `cliente_id` é fixo (`cliente-demo-001`) e o `status` não é enviado (o backend
   define `pendente`).

## Pré-requisitos

- Flutter 3.44+ (Dart 3.12+). Confira com `flutter --version`.
- Backend FastDelivery em execução (veja `Code/server/`):
  ```powershell
  cd ../../server
  docker compose up -d        # RabbitMQ
  py main.py                  # API em http://localhost:5055
  py consumer_worker.py       # worker (outro terminal) — necessário p/ GET /eventos
  ```

## Configuração da URL da API

A URL base é injetada em build/run via `--dart-define` (sem alterar código nem
backend). Padrão: `http://localhost:5055`.

| Ambiente | URL recomendada |
|---|---|
| Emulador Android | `http://10.0.2.2:5055` |
| Dispositivo físico (mesma rede) | `http://<IP-DA-MAQUINA>:5055` |
| Flutter Web (Chrome) | `http://localhost:5055` — exige CORS no backend (fora do escopo) |

## Como rodar

```powershell
flutter pub get

# Emulador Android (caminho recomendado para a demo):
flutter run --dart-define=FASTDELIVERY_API_URL=http://10.0.2.2:5055

# Desktop/local apontando para o backend local:
flutter run --dart-define=FASTDELIVERY_API_URL=http://localhost:5055
```

## Testes e qualidade

```powershell
flutter analyze
flutter test
dart format .
```

## Demonstração da atualização assíncrona

1. No app, crie uma entrega (fica `pendente`).
2. Abra os detalhes dela.
3. **Sem tocar no app**, simule o prestador via curl/Postman:
   ```powershell
   Invoke-RestMethod -Method Patch `
     -Uri "http://localhost:5055/entregas/<ID>/status" `
     -ContentType "application/json" `
     -Body '{"status":"aceito"}'
   ```
4. Em até 5 segundos a tela passa para `aceito` sozinha. Repita para
   `em_transito` e `concluido`.

## Arquitetura (camadas)

```text
lib/
  main.dart                      # bootstrap
  app.dart                       # MaterialApp, tema, injeta o EntregaApiService
  core/
    config/api_config.dart       # baseUrl (dart-define), cliente demo, intervalo
    http/api_exception.dart      # erro de API já traduzido para mensagem amigável
  features/entregas/
    domain/                      # Entrega, StatusEntrega (puro, sem Flutter)
    data/entrega_api_service.dart# REST: listar / buscarPorId / criar / cancelar
    application/                 # EntregaListController, EntregaDetailController
                                 #   (ChangeNotifier + polling, sem libs de estado)
    presentation/
      screens/                   # list, detail, form
      widgets/                   # status_badge, entrega_card, loading/error/empty
```

Fluxo: `screens → controller → service → API REST`. Dependência externa única:
`http`. Estado com `ChangeNotifier` + `ListenableBuilder` (sem Bloc/Riverpod/GetX,
sem geração de código). O diagrama completo está em
`docs/Sprint3/arquitetura_app_cliente.md`.

## Decisões de escopo

- Atualização assíncrona = **polling REST** (5s), não conexão direta ao broker.
- `cliente_id` fixo (`cliente-demo-001`); sem login/autenticação.
- O cliente só altera status para **`cancelado`** (e somente quando `pendente`).
  Aceitar/transitar/concluir são ações do prestador (Sprint 4).
- Sem mapa, pagamento, chat ou push real.
