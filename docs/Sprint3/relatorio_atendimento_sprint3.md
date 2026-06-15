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

A organizacao segue camadas simples, alinhadas ao que foi pedido na Sprint 3 e
inspiradas em Clean Architecture. A ideia principal e separar regras de negocio,
acesso a dados, controle de estado e interface, evitando que a tela conheca
detalhes de HTTP, JSON ou persistencia.

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
- `application`: controllers com estado, polling e orquestracao dos fluxos.
- `presentation`: telas e widgets reutilizaveis, sem regra de negocio pesada.
- `core`: configuracoes e excecoes compartilhadas.

A dependencia externa principal e `http`, sem Bloc, Riverpod, GetX ou geracao de
codigo. Isso mantem a entrega simples, executavel e aderente ao prazo da Sprint 3.

#### Leitura pela Clean Architecture

| Camada | Papel no app | Arquivos principais |
|---|---|---|
| Presentation | Mostra telas, recebe toques e renderiza estados visuais. | `presentation/screens/*`, `presentation/widgets/*` |
| Application | Guarda estado da tela, chama casos de uso simples e controla polling. | `application/entrega_controller.dart` |
| Domain | Representa conceitos do negocio sem depender de Flutter ou HTTP. | `domain/entrega.dart`, `domain/status_entrega.dart` |
| Data | Fala com servicos externos e converte JSON em objetos do dominio. | `data/entrega_api_service.dart` |
| Core | Configuracao e erros compartilhados. | `core/config/api_config.dart`, `core/http/api_exception.dart` |

O fluxo pratico fica assim:

```text
Tela Flutter -> Controller -> Service REST -> Backend Flask
      ^             |              |
      |             v              v
      +------ estado/notificacao   JSON/HTTP
```

#### Diagrama de camadas

O diagrama de camadas foi criado em `docs/Sprint3/arquitetura_app_cliente.md`.
Para deixar o relatorio autocontido, o mesmo desenho arquitetural da Sprint 3
tambem fica registrado abaixo:

```mermaid
flowchart TD
    User["Cliente"]
    Screens["Presentation\nscreens/widgets"]
    Controller["Application\nEntregaController"]
    Service["Data\nEntregaApiService"]
    Domain["Domain\nEntrega, StatusEntrega"]
    API["Backend Flask REST\nCode/server"]
    DB["SQLite\nentregas.db"]
    Rabbit["RabbitMQ\nfastdelivery.events"]
    Worker["consumer_worker.py"]

    User --> Screens
    Screens --> Controller
    Controller --> Service
    Controller --> Domain
    Service --> API
    API --> DB
    API --> Rabbit
    Rabbit --> Worker
    Worker --> DB
```

Essa separacao permite trocar detalhes de infraestrutura com menos impacto. Por
exemplo, se no futuro o app usar autenticacao ou cache local, a mudanca deve
entrar em `data`/`core`, sem obrigar as telas a entenderem como token, storage ou
HTTP funcionam.

### 6. Conceitos Flutter da aula aplicados

A aula `aula07_flutter (2).html` apresentou conceitos de Flutter, Dart, widgets,
estado, REST, seguranca e storage. A Sprint 3 aplica principalmente os conceitos
de widgets, estado, ciclo de vida, null safety, Material Design, REST e testes.

#### StatefulWidget e ciclo de vida

As telas de lista, detalhes e formulario sao `StatefulWidget` porque precisam
guardar estado temporario da UI: carregamento, dados recebidos, formulario em
envio e polling ativo.

Exemplo da lista:

```dart
class EntregaListScreen extends StatefulWidget {
  const EntregaListScreen({super.key, required this.service});

  final EntregaApiService service;

  @override
  State<EntregaListScreen> createState() => _EntregaListScreenState();
}
```

O ciclo de vida aparece no `initState` e no `dispose`. No `initState`, a tela
carrega os dados e inicia o polling. No `dispose`, libera o controller e cancela
o timer, evitando requisicoes depois que a tela saiu da arvore de widgets.

```dart
@override
void initState() {
  super.initState();
  _controller.carregar();
  _controller.iniciarPolling();
}

@override
void dispose() {
  _controller.dispose();
  super.dispose();
}
```

#### Estado local com setState

O formulario usa estado local para controlar se a entrega esta sendo enviada.
Quando `_enviando` vira `true`, o botao e desabilitado e o texto muda para
`Enviando...`.

```dart
if (!_formKey.currentState!.validate()) {
  return;
}
setState(() => _enviando = true);
```

Esse e um uso adequado de `setState`: o estado pertence somente ao formulario.
Ja a lista e os detalhes usam `ChangeNotifier`, porque precisam combinar dados
vindos da API, polling, loading, erro e cancelamento.

#### Tratamento de loading, erro e dados

A lista trata os tres estados basicos recomendados na aula para telas que buscam
dados de API:

```dart
if (_controller.carregando && entregas.isEmpty) {
  return const LoadingView(mensagem: 'Carregando entregas...');
}
if (_controller.erro != null && entregas.isEmpty) {
  return ErrorView(
    mensagem: _controller.erro!,
    onRetry: () => _controller.carregar(),
  );
}
if (entregas.isEmpty) {
  return const EmptyState(...);
}

return RefreshIndicator(
  onRefresh: _controller.carregar,
  child: ListView.builder(...),
);
```

Assim o usuario nunca fica diante de uma tela sem contexto. O app informa quando
esta carregando, quando ocorreu erro, quando nao ha entregas e quando ha dados.

#### Null safety

O modelo `Entrega` usa tipos opcionais quando o backend pode nao enviar um campo,
por exemplo `criadoEm` e `atualizadoEm`.

```dart
final String? criadoEm;
final String? atualizadoEm;

StatusEntrega? get statusEnum => StatusEntrega.fromValor(status);
```

Nas telas, o codigo trata esses valores antes de exibir:

```dart
valor: entrega.criadoEm ?? '-',
valor: entrega.atualizadoEm ?? '-',
```

Isso segue o conceito de null safety da aula: o codigo precisa reconhecer quando
um valor pode ser nulo e decidir explicitamente o que fazer.

#### REST com async/await

O app usa o pacote `http`, como sugerido na aula para comecar, e encapsula as
chamadas REST em `EntregaApiService`.

```dart
Future<List<Entrega>> listar({String? status}) async {
  final resp = await _enviar(() => _client.get(uri));
  _garantirSucesso(resp);
  final dynamic corpo = _decodificar(resp.body);
  return corpo
      .whereType<Map<String, dynamic>>()
      .map(Entrega.fromJson)
      .toList(growable: false);
}
```

O ponto importante e que a rede nao bloqueia a UI. A chamada retorna um `Future`,
o controller aguarda com `await`, e a tela e redesenhada quando o estado muda.

#### Material Design e widgets

O app usa Material 3 no `MaterialApp`:

```dart
theme: ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
  useMaterial3: true,
),
```

Nas telas, os componentes seguem o padrao Material: `Scaffold`, `AppBar`,
`FloatingActionButton`, `FilledButton`, `TextFormField`, `SnackBar`, `Card`,
`ListView` e `RefreshIndicator`.

#### Conceitos da aula que ficaram fora do escopo

Storage local (`shared_preferences`, `sqflite`, `flutter_secure_storage`) nao foi
implementado na Sprint 3 porque o app nao salva dados no aparelho; a persistencia
fica no backend. Autenticacao tambem ficou fora do escopo: o app usa
`cliente-demo-001` ate uma sprint futura introduzir login e tokens.

### 7. Preservacao das Sprints 1 e 2

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
um telefone Android simulado no Android Studio. Elas nao sao apenas prints de
tela: cada uma registra uma parte do comportamento exigido pela Sprint 3.

### Tela inicial - lista vazia

Este print mostra o estado inicial da tela de listagem quando o cliente ainda
nao possui entregas. Ele comprova que a lista trata o estado vazio de forma
clara, sem deixar a tela em branco, e oferece a acao principal da Sprint 3:
criar uma nova entrega.

![Tela inicial do app FastDelivery no emulador Android](../../main%20page.png)

### Tela de nova entrega

Este print mostra a tela de criacao com os campos `descricao`, `origem` e
`destino`. Ele evidencia a terceira tela obrigatoria da Sprint 3 e mostra que o
usuario cliente consegue iniciar uma solicitacao pelo app Flutter.

![Tela de criacao de entrega no emulador Android](../../pagina%20de%20criar%20entrega.png)

### Formulario preenchido

Este print mostra o formulario preenchido antes do envio. Ele ajuda a demonstrar
o fluxo real de entrada de dados do cliente antes do `POST /entregas`, sem usar
dados mockados na interface.

![Formulario de entrega preenchido no emulador Android](../../entrega%20escrevivel.png)

### Entrega criada pelo frontend

Este print mostra a entrega criada aparecendo na lista do app. A imagem tambem
registra logs do backend com `POST /entregas` retornando `201` e `GET /entregas`
retornando `200`, evidenciando que a tela Flutter esta integrada ao backend REST
real e nao apenas renderizando dados fixos.

![Entrega criada pelo frontend e exibida no app Android](../../entrega%20criada%20pelo%20frontend.png)

### Detalhe da entrega pendente

Este print cobre a tela de detalhes, que e um requisito explicito da Sprint 3.
Ele mostra os campos completos da entrega, a linha de progresso do status e o
botao `Cancelar entrega`, que aparece somente quando o status esta `pendente`.
Isso comprova que a tela de detalhes nao e apenas uma duplicacao da lista: ela
expande os dados e oferece uma acao contextual do cliente.

![Detalhe da entrega pendente no emulador Android](../../detalhe%20da%20entrega%20pendente.png)

### Entrega aceita na lista

Este print mostra a mesma entrega depois da mudanca de status para `aceito`.
Ele evidencia a atualizacao assincrona por polling: o status alterado no servidor
passa a aparecer automaticamente na lista do app, sem o cliente precisar recriar
a entrega ou navegar por outro fluxo manual.

![Entrega aceita exibida na lista do app](../../entrega%20aceita.png)

### Detalhe da entrega aceita

Este print mostra a tela de detalhes apos a entrega ser aceita. A etapa `Aceito`
aparece marcada na linha de progresso e o botao de cancelamento deixa de ficar
disponivel, exibindo a mensagem de que apenas entregas pendentes podem ser
canceladas pelo cliente. Isso valida duas regras de negocio no app: acompanhar a
mudanca de status e restringir a acao de cancelamento ao estado correto.

![Detalhe da entrega aceita no emulador Android](../../detalhe%20da%20entrega%20aceita.png)

### Botao de cancelar entrega

Este print mostra uma entrega pendente criada para validar o fluxo de
cancelamento pelo cliente. O botao `Cancelar entrega` aparece porque o status
ainda permite essa acao. Esse comportamento esta alinhado ao escopo da Sprint 3:
o cliente pode cancelar uma entrega pendente, mas nao pode aceitar, iniciar
transito ou concluir uma entrega.

![Botao de cancelar entrega pendente](../../bot%C3%A3o%20cancelar%20entrega.png)

### Confirmacao de cancelamento

Este print mostra o dialogo de confirmacao antes de cancelar. Ele evidencia um
cuidado de usabilidade: a acao altera o estado da entrega no backend, entao o app
pede confirmacao antes de enviar o `PATCH /entregas/<id>/status` com
`cancelado`.

![Popup de confirmacao de cancelamento](../../popup%20cancelar%20entrega.png)

### Entrega cancelada

Este print mostra o resultado final do cancelamento: badge `Cancelado`, mensagem
visual de entrega cancelada, snackbar de confirmacao e ausencia do botao de
cancelar. Ele comprova o fluxo completo de acao do cliente: tela de detalhes,
confirmacao, chamada REST e atualizacao da UI com o novo estado.

![Entrega cancelada no app Android](../../entrega%20cancelada.png)

### Backend publicando status aceito

Este print mostra o terminal do backend/RabbitMQ publicando o evento
`entrega.status_atualizado` quando a entrega `#9` muda de `pendente` para
`aceito`. Ele reforca que a atualizacao vista no app nasce de uma alteracao real
no backend e tambem preserva a comunicacao assincrona da Sprint 2 por meio da
publicacao do evento no broker.

![Backend publicando evento de entrega aceita](../../entrega%20aceita%20backend.png)

### Backend publicando cancelamento

Este print mostra o backend publicando outro evento `entrega.status_atualizado`,
agora para a entrega `#10`, com transicao de `pendente` para `cancelado`. Ele
complementa a evidencia anterior porque demonstra que a acao feita pelo app
cliente tambem gera evento de dominio e passa pelo mesmo fluxo assincrono do
sistema.

![Backend publicando evento de entrega cancelada](../../entrega%20cancelada%20backend%20terminal.png)

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
