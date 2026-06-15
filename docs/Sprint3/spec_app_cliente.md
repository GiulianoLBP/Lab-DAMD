# Spec - App Flutter Cliente

## Escopo funcional

O app da Sprint 3 representa somente o perfil Cliente. Ele nao deve implementar telas ou decisoes do Prestador, que ficam para a Sprint 4.

### Fluxos obrigatorios

| ID | Fluxo | Resultado esperado |
|---|---|---|
| F01 | Cliente abre o app | Lista de entregas do cliente e carregada automaticamente. |
| F02 | Cliente cria entrega | App envia `POST /entregas`, mostra sucesso e abre/lista a entrega criada. |
| F03 | Cliente consulta detalhes | App chama `GET /entregas/<id>` e mostra campos completos. |
| F04 | Servidor muda status | App reflete mudanca sem botao de atualizar, por polling. |
| F05 | Cliente cancela entrega pendente | App chama `PATCH /entregas/<id>/status` com `cancelado` e atualiza tela. |
| F06 | Backend indisponivel | App mostra mensagem clara e permite tentar novamente. |

## Telas

### 1. Lista de entregas

Responsabilidades:

- Buscar `GET /entregas` ao abrir.
- Filtrar no app por `cliente_id` fixo de demonstracao.
- Atualizar automaticamente a cada 5 segundos enquanto a tela estiver visivel.
- Mostrar estado vazio quando nao houver entregas.
- Mostrar estado de carregamento sem bloquear a navegacao.
- Mostrar erro com acao de tentar novamente.
- Ter botao simples para criar nova entrega.

Conteudo minimo por item:

- Descricao.
- Origem resumida.
- Destino resumido.
- Status com badge colorido.
- Data de atualizacao, se disponivel.

### 2. Detalhes da entrega

Responsabilidades:

- Buscar `GET /entregas/<id>` ao abrir.
- Atualizar automaticamente a cada 5 segundos.
- Mostrar todos os campos retornados pelo backend.
- Mostrar uma linha de progresso simples do status:
  `pendente -> aceito -> em_transito -> concluido`.
- Mostrar `cancelado` como estado final alternativo.
- Exibir botao "Cancelar" somente quando `status == pendente`.

Importante:

- O app cliente nao deve aceitar entrega, iniciar transito ou concluir entrega. Essas acoes pertencem ao prestador na Sprint 4.
- Para demonstrar mudanca de status na Sprint 3, usar Postman/curl contra `PATCH /entregas/<id>/status`.

### 3. Nova entrega

Campos:

- `descricao`
- `origem`
- `destino`

Valores automaticos:

- `cliente_id = cliente-demo-001`
- `status` nao deve ser enviado; o backend define `pendente`.

Validacoes no app:

- Campos obrigatorios.
- Nao aceitar texto em branco.
- Desabilitar envio enquanto a requisicao estiver em andamento.
- Exibir erro retornado pelo backend quando houver `{"error": "..."}`

## Contratos REST usados pelo app

| Uso no app | Metodo e rota | Payload | Sucesso | Erros esperados |
|---|---|---|---|---|
| Criar entrega | `POST /entregas` | `descricao`, `origem`, `destino`, `cliente_id` | `201` com entrega completa | `400` body ausente/campos invalidos; `500` se broker falhar |
| Listar entregas | `GET /entregas` | nenhum | `200` array de entregas | `400` se filtro de status invalido |
| Detalhar entrega | `GET /entregas/<id>` | nenhum | `200` entrega completa | `404` entrega nao encontrada |
| Cancelar entrega | `PATCH /entregas/<id>/status` | `{"status":"cancelado"}` | `200` entrega atualizada | `400` status invalido; `404` entrega nao encontrada |
| Evidencia MOM | `GET /eventos` | nenhum | `200` eventos processados | nenhum erro funcional esperado |

## Modelo de dados esperado no Flutter

```dart
class Entrega {
  final int id;
  final String descricao;
  final String origem;
  final String destino;
  final String status;
  final String clienteId;
  final String? criadoEm;
  final String? atualizadoEm;
}
```

Status validos:

- `pendente`
- `aceito`
- `em_transito`
- `concluido`
- `cancelado`

## Backlog de desenvolvimento

| ID | Item | Descricao | Pronto quando |
|---|---|---|---|
| B01 | Criar projeto Flutter | Criar app em `Code/mobile/fastdelivery_cliente/` com Material 3. | `flutter analyze` roda sem erro inicial. |
| B02 | Configurar API base URL | Usar `--dart-define=FASTDELIVERY_API_URL=...`, com default documentado. | App roda em Windows/Android emulator apontando para o backend local. |
| B03 | Criar model `Entrega` | Parse seguro de JSON do backend. | Teste unitario cobre `fromJson`. |
| B04 | Criar service REST | Implementar `listar`, `buscarPorId`, `criar`, `cancelar`. | Testes com client fake cobrem sucesso e erro. |
| B05 | Lista de entregas | Tela inicial com carregamento, vazio, erro, lista e polling. | Entregas aparecem apos criar via app ou Postman. |
| B06 | Formulario de criacao | Tela simples com validacao e feedback. | `POST /entregas` cria registro real no SQLite. |
| B07 | Detalhes com polling | Tela mostra campos, status e atualiza sozinha. | Status alterado por curl aparece sem toque manual. |
| B08 | Cancelamento pelo cliente | Botao cancelar apenas em `pendente`. | PATCH para `cancelado` funciona e tela atualiza. |
| B09 | UX simples e bonita | Cores, espacamento, badges e mensagens consistentes. | Interface e legivel em celular e desktop pequeno. |
| B10 | Documentar execucao | README do app com comandos e URL por ambiente. | Qualquer avaliador consegue rodar backend + app. |
| B11 | Evidencias Sprint 3 | Prints ou pequeno roteiro com backend, app e mudanca assincrona. | Arquivos ficam em `docs/Sprint3/evidencias/`. |

## Fora de escopo

- Login/cadastro de cliente.
- Pagamento.
- Mapa/geolocalizacao.
- Chat.
- Push notification real.
- Consumo direto do RabbitMQ pelo app cliente.
- App do entregador/prestador.
- Alteracoes amplas no schema SQLite.

