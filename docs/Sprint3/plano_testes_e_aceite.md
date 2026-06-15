# Plano de Testes e Criterios de Aceite - Sprint 3

## Comandos obrigatorios

Backend, em `Code/server/`:

```powershell
py -m unittest discover -s tests -v
```

Flutter, em `Code/mobile/fastdelivery_cliente/`:

```powershell
flutter analyze
flutter test
```

Formatacao:

```powershell
dart format .
```

## Testes automatizados recomendados

### Backend REST

Antes ou durante a Sprint 3, substituir o placeholder `Code/server/tests/test_entregas.py` por testes reais. Isso protege o app contra regressao nos contratos que ele consome.

Cobrir:

| ID | Cenario | Esperado |
|---|---|---|
| API01 | `POST /entregas` com payload valido | `201`, status `pendente`, campos completos. |
| API02 | `POST /entregas` sem campo obrigatorio | `400` com `error`. |
| API03 | `GET /entregas` | `200` array. |
| API04 | `GET /entregas?status=pendente` | `200` apenas pendentes. |
| API05 | `GET /entregas?status=invalido` | `400` com `Status invalido`. |
| API06 | `GET /entregas/<id>` existente | `200` entrega correta. |
| API07 | `GET /entregas/<id>` inexistente | `404` com `error`. |
| API08 | `PATCH /entregas/<id>/status` valido | `200`, status atualizado, evento publicado. |
| API09 | `PATCH /entregas/<id>/status` invalido | `400` com `Status invalido`. |
| API10 | `GET /eventos` | `200` array de eventos processados. |

Usar banco temporario via `DATABASE_PATH` para nao depender do `entregas.db` local.

### Flutter

| ID | Tipo | Cenario | Esperado |
|---|---|---|---|
| FL01 | Unitario | `Entrega.fromJson` com JSON completo | Model correto. |
| FL02 | Unitario | `Entrega.fromJson` com campo ausente inesperado | Erro tratado ou fallback claro. |
| FL03 | Unitario | Service lista entregas com HTTP 200 | Retorna lista. |
| FL04 | Unitario | Service recebe `{"error": "..."}` | Lanca/retorna erro com mensagem. |
| FL05 | Widget | Formulario vazio | Mostra validacoes e nao envia. |
| FL06 | Widget | Formulario valido | Chama criacao e mostra estado de carregamento. |
| FL07 | Widget | Badge de status | Renderiza label correto para todos os status. |
| FL08 | Widget | Lista vazia | Mostra estado vazio. |

## Roteiro manual de demonstracao

### Preparacao

Em `Code/server/`:

```powershell
Copy-Item .env.example .env -ErrorAction SilentlyContinue
docker compose up -d
py main.py
```

Em outro terminal:

```powershell
cd Code/server
py consumer_worker.py
```

Em `Code/mobile/fastdelivery_cliente/`:

```powershell
flutter run --dart-define=FASTDELIVERY_API_URL=http://localhost:5055
```

Para Android emulator, trocar a URL por:

```powershell
flutter run --dart-define=FASTDELIVERY_API_URL=http://10.0.2.2:5055
```

### Demo principal

| Passo | Acao | Evidencia esperada |
|---|---|---|
| D01 | Abrir o app | Lista carrega sem erro. |
| D02 | Criar nova entrega pelo app | Tela mostra entrega com status `pendente`; backend retorna `201`. |
| D03 | Abrir detalhes da entrega | Todos os campos aparecem. |
| D04 | Sem tocar no app, alterar status por curl/Postman para `aceito` | Em ate 5 segundos, tela muda para `aceito`. |
| D05 | Alterar status para `em_transito` | Tela atualiza sozinha. |
| D06 | Alterar status para `concluido` | Tela mostra estado final. |
| D07 | Consultar `GET /eventos` | Historico mostra eventos `entrega.criada` e `entrega.status_atualizado`. |

Comando de simulacao do prestador:

```powershell
Invoke-RestMethod `
  -Method Patch `
  -Uri "http://localhost:5055/entregas/<ID>/status" `
  -ContentType "application/json" `
  -Body '{"status":"aceito"}'
```

## Criterios de aceite por requisito da Sprint 3

| Requisito do enunciado | Criterio de aceite |
|---|---|
| App Flutter funcional para o cliente | App abre, navega entre lista/detalhe/formulario e cria entrega real no backend. |
| Minimo de 3 telas | Lista, Detalhes e Nova Entrega implementadas e acessiveis. |
| Integracao com backend REST | App usa `POST /entregas`, `GET /entregas`, `GET /entregas/<id>` e `PATCH /entregas/<id>/status` para cancelamento. |
| Atualizacao assincrona de estado | Status alterado fora do app aparece automaticamente em ate 5 segundos. |
| Arquitetura documentada | `arquitetura_app_cliente.md` representa camadas, pastas e fluxo de polling. |
| App executavel | `flutter run` funciona com API local documentada. |

## Rubrica de aceite alinhada aos 20 pontos

| Criterio oficial | Peso | Como comprovar |
|---|---:|---|
| Funcionalidade do app | 6,0 | Criar, listar, detalhar e cancelar entrega pelo app. |
| Integracao REST correta | 5,0 | Prints/logs de chamadas reais ao Flask e dados persistidos no SQLite. |
| Atualizacao assincrona | 4,0 | Video/print sequencial mostrando status mudando sem refresh manual. |
| Organizacao Flutter | 3,0 | Pastas por camada, models/services/screens/widgets separados, testes passando. |
| Qualidade da interface | 2,0 | UI clara, responsiva, estados de erro/vazio/carregamento bem resolvidos. |

## Evidencias a guardar

Criar `docs/Sprint3/evidencias/` durante a implementacao e salvar:

- Print da lista de entregas.
- Print do formulario preenchido.
- Print dos detalhes em `pendente`.
- Print dos detalhes apos status mudar para `aceito` sem acao manual.
- Print ou log do backend recebendo requests.
- Print ou log do worker processando eventos.
- Saida de `flutter analyze`.
- Saida de `flutter test`.
- Saida de `py -m unittest discover -s tests -v`.

## Nao aceitar como pronto

- App com telas mockadas sem chamar o backend.
- Atualizacao feita somente por botao manual.
- Polling que continua rodando apos sair da tela.
- Cliente aceitando/concluindo entrega como se fosse prestador.
- Backend com RabbitMQ removido, desativado ou substituido por memoria em execucao real.
- Documentacao de Sprint 3 fora de `docs/Sprint3/`.
