# Relatorio de Atendimento - Sprint 3

Auditoria realizada em 2026-06-15 sobre o repositorio `Lab-DAMD`.

## Fonte dos requisitos

O criterio usado nesta verificacao foi o PDF `docs/Projeto_LAMD_60445_2026_1.pdf`,
secao 3.4, "Sprint 3 - Aplicativo Flutter para o Cliente".

A Sprint 3 exige:

- App Flutter funcional para o perfil Cliente, com minimo de 3 telas.
- Integracao com o backend REST das sprints anteriores.
- Atualizacao assincrona de estado por MOM ou mecanismo equivalente, como polling.
- Arquitetura do app documentada em camadas.
- Codigo-fonte executavel ou APK.

## Resultado geral

Status: Sprint 3 atendida.

Nao foram encontrados erros de atendimento aos requisitos oficiais da Sprint 3
durante esta auditoria. Por isso, nenhum `erro.md` foi criado.

## Matriz de atendimento

| Requisito oficial da Sprint 3 | Situacao | Evidencia encontrada |
|---|---|---|
| App Flutter funcional para o cliente | Atendido | Projeto em `Code/mobile/fastdelivery_cliente/`, com Material 3 e escopo restrito ao perfil Cliente. |
| Minimo de 3 telas | Atendido | Telas `entrega_list_screen.dart`, `entrega_detail_screen.dart` e `entrega_form_screen.dart`. |
| Integracao com backend REST | Atendido | `EntregaApiService` consome `POST /entregas`, `GET /entregas`, `GET /entregas/<id>` e `PATCH /entregas/<id>/status`. |
| Atualizacao assincrona de estado | Atendido | Polling REST a cada 5 segundos em lista e detalhes, usando `Timer.periodic` e parando em `dispose`. |
| Arquitetura do app documentada | Atendido | `docs/Sprint3/arquitetura_app_cliente.md` descreve camadas, estrutura de pastas e fluxos. |
| Codigo-fonte executavel | Atendido | Projeto Flutter completo com `pubspec.yaml`, Android configurado, README de execucao e testes automatizados. |

## O que foi implementado na Sprint 3

### 1. App Flutter do Cliente

O app foi criado em `Code/mobile/fastdelivery_cliente/` e representa apenas o
usuario Cliente, como exigido para a Sprint 3. O app permite:

- Listar entregas do cliente de demonstracao.
- Criar nova entrega.
- Consultar detalhes de uma entrega.
- Cancelar entrega ainda pendente.
- Acompanhar mudancas de status sem acao manual.

O `cliente_id` fixo usado na Sprint 3 e `cliente-demo-001`, mantendo login e
autenticacao fora do escopo atual.

### 2. Telas entregues

| Tela | Arquivo | Funcao |
|---|---|---|
| Lista de entregas | `lib/features/entregas/presentation/screens/entrega_list_screen.dart` | Tela inicial, estado vazio, erro, carregamento, lista e acao de criar entrega. |
| Detalhes da entrega | `lib/features/entregas/presentation/screens/entrega_detail_screen.dart` | Mostra campos completos, status, progresso e botao de cancelar apenas quando pendente. |
| Nova entrega | `lib/features/entregas/presentation/screens/entrega_form_screen.dart` | Formulario com `descricao`, `origem`, `destino`, validacao e envio para o backend. |

### 3. Integracao REST

A integracao com o backend fica em:

`Code/mobile/fastdelivery_cliente/lib/features/entregas/data/entrega_api_service.dart`

Rotas consumidas:

| Funcao no app | Metodo e rota | Observacao |
|---|---|---|
| Criar entrega | `POST /entregas` | Envia `descricao`, `origem`, `destino` e `cliente_id`; o backend define `status = pendente`. |
| Listar entregas | `GET /entregas` | O app filtra localmente pelo `cliente_id` de demonstracao. |
| Buscar detalhes | `GET /entregas/<id>` | Usado na tela de detalhes e no polling. |
| Cancelar entrega | `PATCH /entregas/<id>/status` | Envia apenas `{"status":"cancelado"}`. |

O backend preserva os contratos anteriores em `Code/server/app/controllers/` e os
casos de uso seguem publicando eventos de dominio em criacao e mudanca de status.

### 4. Atualizacao assincrona por polling

A Sprint 3 permite MOM direto, WebSockets ou polling. A decisao implementada foi
polling REST a cada 5 segundos, documentada como mecanismo assincrono equivalente.

Evidencias no codigo:

- `ApiConfig.intervaloPolling = Duration(seconds: 5)`.
- `EntregaListController` usa polling de `GET /entregas`.
- `EntregaDetailController` usa polling de `GET /entregas/<id>`.
- Os controllers evitam requisicoes sobrepostas.
- Os timers sao cancelados em `dispose`.

Fluxo demonstravel:

1. Cliente cria entrega no app.
2. App mostra a entrega como `pendente`.
3. Um status e alterado fora do app por `PATCH /entregas/<id>/status`.
4. Em ate 5 segundos, a tela reflete o novo status sem botao de atualizar.

### 5. Arquitetura Flutter

A organizacao segue camadas simples, alinhadas ao que foi pedido na Sprint 3:

```text
lib/
  core/
    config/
    http/
  features/
    entregas/
      domain/
      data/
      application/
      presentation/
```

Responsabilidades:

- `domain`: modelo `Entrega` e enum `StatusEntrega`.
- `data`: servico REST `EntregaApiService`.
- `application`: controllers com estado e polling.
- `presentation`: telas e widgets reutilizaveis.

A dependencia externa principal e `http`, sem Bloc, Riverpod, GetX ou geracao de
codigo. Isso mantem a entrega simples, executavel e aderente ao prazo da Sprint 3.

### 6. Preservacao das Sprints 1 e 2

A Sprint 3 nao alterou o contrato REST para acomodar o mobile. O app consome a API
existente.

A mensageria da Sprint 2 tambem foi preservada:

- RabbitMQ continua como broker real.
- Flask continua produtor por padrao.
- `consumer_worker.py` continua sendo o consumidor independente.
- `InMemoryEventBus` permanece reservado para testes.
- Eventos `entrega.criada` e `entrega.status_atualizado` continuam sendo
  publicados pelo backend.

## Evidencias visuais

As imagens abaixo estao na raiz do repositorio e mostram a aplicacao rodando em
um telefone Android simulado no Android Studio.

### Tela inicial - lista vazia

Mostra a tela principal do app, com estado vazio, botao de atualizar e acao para
criar uma nova entrega.

![Tela inicial do app FastDelivery no emulador Android](../../main%20page.png)

### Tela de nova entrega

Mostra a tela de criacao com os tres campos exigidos pelo fluxo da Sprint 3.

![Tela de criacao de entrega no emulador Android](../../pagina%20de%20criar%20entrega.png)

### Formulario preenchido

Mostra o formulario preenchido antes do envio para o backend.

![Formulario de entrega preenchido no emulador Android](../../entrega%20escrevivel.png)

### Entrega criada pelo frontend

Mostra a entrega criada aparecendo na lista do app. A imagem tambem registra logs
do backend com `POST /entregas` retornando `201` e `GET /entregas` retornando
`200`, evidenciando a integracao REST real.

![Entrega criada pelo frontend e exibida no app Android](../../entrega%20criada%20pelo%20frontend.png)

## Evidencias de testes

Tambem existem saidas salvas em `docs/Sprint3/evidencias/`:

| Arquivo | Evidencia |
|---|---|
| `backend_unittest.txt` | Testes do backend com `Ran 24 tests ... OK`. |
| `flutter_analyze.txt` | Analise Flutter sem problemas: `No issues found!`. |
| `flutter_test.txt` | Testes Flutter com `All tests passed!`. |

Nesta auditoria, os comandos tambem foram executados novamente:

```powershell
# Code/server/
py -m unittest discover -s tests -v
# Resultado: Ran 24 tests in 2.085s - OK

# Code/mobile/fastdelivery_cliente/
flutter analyze
# Resultado: No issues found!

flutter test
# Resultado: All tests passed! (15 testes)
```

## Relacao com a rubrica de 20 pontos

| Criterio oficial | Peso | Atendimento |
|---|---:|---|
| Funcionalidade do app | 6,0 | Atendido: cria, lista, detalha e cancela entregas. |
| Integracao REST correta | 5,0 | Atendido: app consome os endpoints REST existentes. |
| Atualizacao assincrona | 4,0 | Atendido: polling automatico de 5 segundos em lista e detalhes. |
| Organizacao Flutter | 3,0 | Atendido: codigo separado em domain, data, application e presentation. |
| Qualidade da interface | 2,0 | Atendido: telas claras, estados de vazio/erro/carregamento e botoes adequados ao fluxo. |

## Conclusao

A Sprint 3 esta atendida para o escopo oficial de "Aplicativo Flutter para o
Cliente". O app cliente existe, e executavel, possui as tres telas obrigatorias,
integra com o backend REST, reflete atualizacoes de status por polling assincrono,
mantem a arquitetura documentada e preserva a camada MOM das sprints anteriores.
