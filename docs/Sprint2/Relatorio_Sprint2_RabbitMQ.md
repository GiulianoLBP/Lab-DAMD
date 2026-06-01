# FastDelivery - Relatório de Integração MOM (Sprint 2)

**Disciplina:** Laboratório de Desenvolvimento de Aplicações Móveis e Distribuídas  
**Projeto:** FastDelivery  
**Sprint:** Sprint 2 - Integração com Middleware Orientado a Mensagens  
**Tecnologia MOM:** RabbitMQ (AMQP)  
**Referência do enunciado:** seção 3.3, página 5 de `docs/Projeto_LAMD_60445_2026_1.pdf`

---

## Parte A - Relatório de integração (texto principal para entrega)

### Objetivo

A Sprint 2 integrou um Middleware Orientado a Mensagens (MOM) ao backend Flask do FastDelivery. O objetivo foi permitir que fatos relevantes do domínio de entregas fossem publicados e processados de forma assíncrona, sem chamada REST direta entre produtor e consumidor.

### Decisões de design

Foi adotado o RabbitMQ por ser um broker dedicado, com suporte nativo a filas duráveis, mensagens persistentes, confirmação de publicação, confirmação manual de consumo e Dead-Letter Queue (DLQ). O padrão aplicado é Publish-Subscribe sobre uma exchange do tipo `topic`, chamada `fastdelivery.events`.

O backend Flask atua como produtor. Por padrão, o consumidor roda em outro processo com `py consumer_worker.py`. Essa separação demonstra que os dois componentes têm ciclos de vida independentes: o produtor publica no broker mesmo quando o consumidor está desligado; a fila `fastdelivery.entregas` armazena o backlog; quando o worker inicia, ele consome as mensagens pendentes.

### Fluxo implementado

Dois momentos distintos do negócio publicam eventos:

1. `POST /entregas` cria uma entrega e publica `entrega.criada`.
2. `PATCH /entregas/<id>/status` altera o estado da entrega e publica `entrega.status_atualizado`.

Os eventos passam pela exchange `fastdelivery.events` e são encaminhados para a fila durável `fastdelivery.entregas`. O worker registra handlers para os dois tópicos, processa cada mensagem e somente então envia `ack`. Se o handler falhar ou não existir, o barramento envia `nack(requeue=False)` e o RabbitMQ encaminha a mensagem para `fastdelivery.dlq`.

### Desafios e soluções

A primeira versão da Sprint 2 utilizava Redis. A revisão técnica identificou limitações de persistência, tratamento de falhas e comprovação de desacoplamento. A solução foi migrar para RabbitMQ, preservar a interface `EventBus` e adicionar confiabilidade: mensagens persistentes (`delivery_mode=2`), publisher confirms, uma tentativa de reconexão do produtor, DLQ e histórico idempotente persistido no SQLite por `evento_id`.

### Conclusão

A implementação atende ao objetivo da Sprint 2: o RabbitMQ é o ponto central da comunicação assíncrona, o produtor e o consumidor são independentes, dois eventos de negócio são publicados e o fluxo pode ser comprovado por logs, interface de gestão do broker e consulta ao endpoint `GET /eventos`.

---

## Parte B - Conferência dos requisitos do enunciado

| Requisito da seção 3.3 | Implementação no FastDelivery | Evidência recomendada |
|---|---|---|
| MOM configurado e operacional | RabbitMQ via `docker-compose.yml`, portas `5672` e `15672` | Print da UI do RabbitMQ e `docker compose ps` |
| Produtor e consumidor implementados | `EntregaEventProducer` no backend e `consumer_worker.py` separado | Print dos terminais do backend e do worker |
| Publicação em dois momentos distintos | Criação de entrega e alteração de status | Logs dos tópicos `entrega.criada` e `entrega.status_atualizado` |
| Documentação dos eventos | Catálogo na Parte C deste documento | Tabela e payloads JSON |
| Assincronicidade real | Worker desligado enquanto mensagens acumulam na fila; processamento após ligar o worker | Print da fila com backlog e depois vazia |
| Relatório de integração | Parte A deste documento | Primeira página do DOCX/PDF |

## Parte C - Catálogo de eventos

### Evento `entrega.criada`

| Campo | Valor |
|---|---|
| Momento de publicação | Após `EntregaUseCases.criar_entrega()` persistir a nova entrega |
| Produtor | `EntregaEventProducer.entrega_criada()` |
| Consumidor | Handler `_ao_criar_entrega()` executado por `consumer_worker.py` |
| Exchange | `fastdelivery.events` (`topic`) |
| Routing key | `entrega.criada` |
| Fila | `fastdelivery.entregas` |

```json
{
  "evento_id": "uuid-gerado-na-publicacao",
  "evento": "entrega.criada",
  "dados": {
    "id": 1,
    "descricao": "Pacote Sprint 2",
    "origem": "Rua A, 100",
    "destino": "Rua B, 200",
    "status": "pendente",
    "cliente_id": "cliente-001"
  },
  "timestamp": "2026-06-01T10:00:00"
}
```

### Evento `entrega.status_atualizado`

| Campo | Valor |
|---|---|
| Momento de publicação | Após `EntregaUseCases.atualizar_status()` persistir o novo estado |
| Produtor | `EntregaEventProducer.status_alterado()` |
| Consumidor | Handler `_ao_alterar_status()` executado por `consumer_worker.py` |
| Exchange | `fastdelivery.events` (`topic`) |
| Routing key | `entrega.status_atualizado` |
| Fila | `fastdelivery.entregas` |

```json
{
  "evento_id": "uuid-gerado-na-publicacao",
  "evento": "entrega.status_atualizado",
  "dados": {
    "id": 1,
    "status_anterior": "pendente",
    "status_novo": "aceito",
    "cliente_id": "cliente-001"
  },
  "timestamp": "2026-06-01T10:02:00"
}
```

## Parte D - O que foi adicionado na Sprint 2

| Componente | Responsabilidade |
|---|---|
| `app/mom/barramento.py` | Interface `EventBus`, implementação real `RabbitMQEventBus` e implementação `InMemoryEventBus` reservada a testes |
| `app/mom/eventos.py` | Tópicos, estrutura comum dos payloads e `evento_id` |
| `app/mom/producer.py` | Publicação dos eventos do domínio |
| `app/mom/consumer.py` | Handlers, histórico persistente e deduplicação |
| `consumer_worker.py` | Consumidor standalone sem Flask e sem rota REST |
| `app/repositories/evento_processado_repository.py` | Persistência dos eventos processados no SQLite |
| `docker-compose.yml` | RabbitMQ com UI de gestão e volume persistente |
| `GET /eventos` | Consulta ao histórico processado pelo consumidor |

### Garantias técnicas

- Exchange `fastdelivery.events` do tipo `topic`.
- Fila durável `fastdelivery.entregas`, ligada à exchange com routing key `#`.
- Mensagens persistentes com `delivery_mode=2`.
- Publisher confirms e publicação `mandatory=True`.
- `ack` manual somente após processamento bem-sucedido.
- `nack(requeue=False)` para encaminhar falhas à fila `fastdelivery.dlq`.
- Uma nova tentativa de publicação após falha de conexão.
- Deduplicação por `evento_id` no histórico SQLite.

## Parte E - Testes automatizados executados

Comando executado em `Code/server/`:

```powershell
py -m unittest discover -s tests -v
```

Resultado obtido em 01/06/2026:

```text
Ran 8 tests in 0.087s
OK
```

Cobertura da suíte `tests/test_mom.py`:

| Teste | O que valida |
|---|---|
| Configuração explícita do modo em memória | `EVENT_BUS=in_memory` cria o barramento reservado a testes |
| Configuração padrão | Sem variável específica, a aplicação cria `RabbitMQEventBus` |
| Confirmação de sucesso | Handler bem-sucedido produz `basic_ack` |
| Falha de handler | Exceção produz `basic_nack(requeue=False)` para DLQ |
| Tópico sem handler | Mensagem desconhecida também segue para DLQ |
| Canal encerrado | A conexão de publicação é substituída |
| Falha transitória | O produtor repete a publicação uma vez |
| Histórico idempotente | O mesmo `evento_id` é registrado apenas uma vez no SQLite |

**Limite atual da automação:** `tests/test_entregas.py` ainda contém apenas um placeholder. Portanto, os endpoints REST devem ser comprovados manualmente no roteiro abaixo. Não apresentar os testes de MOM como se também cobrissem os endpoints.

## Parte F - Como rodar e tirar os prints

### 1. Preparação

Abra o Docker Desktop. Depois, em um PowerShell:

```powershell
cd C:\Users\gpercope\Documents\GitHub\Lab-DAMD\Code\server
docker compose up -d
docker compose ps
Copy-Item .env.example .env -ErrorAction SilentlyContinue
pip install -r requirements.txt
```

Abra `http://localhost:15672`, entre com usuário `guest` e senha `guest`.

**Print E1 - Broker operacional:** capture a saída de `docker compose ps` e a página inicial da UI do RabbitMQ. Na UI, abra **Queues and Streams** e confirme que aparecem `fastdelivery.entregas` e `fastdelivery.dlq`.

### 2. Backend produtor sem consumidor

Em um segundo PowerShell:

```powershell
cd C:\Users\gpercope\Documents\GitHub\Lab-DAMD\Code\server
py main.py
```

Confirme no terminal a mensagem de consumidor in-process desligado e a orientação para rodar `consumer_worker.py` separadamente.

**Print E2 - Produtor separado:** capture o terminal do Flask mostrando `Mecanismo MOM.: rabbitmq` e `Consumidor in-process: OFF`.

### 3. Publicar mensagens com o worker desligado

Em um terceiro PowerShell:

```powershell
$body = @{
  descricao = "Pacote demonstracao Sprint 2"
  origem = "Rua A, 100"
  destino = "Rua B, 200"
  cliente_id = "cliente-001"
} | ConvertTo-Json

$entrega = Invoke-RestMethod `
  -Method Post `
  -Uri "http://localhost:5000/entregas" `
  -ContentType "application/json" `
  -Body $body

$entrega

Invoke-RestMethod `
  -Method Patch `
  -Uri "http://localhost:5000/entregas/$($entrega.id)/status" `
  -ContentType "application/json" `
  -Body '{"status":"aceito"}'
```

Na UI do RabbitMQ, abra **Queues and Streams** > `fastdelivery.entregas`. Com o worker ainda desligado, a quantidade de mensagens **Ready** deve aumentar em `2`.

**Print E3 - Backlog assíncrono:** capture a fila `fastdelivery.entregas` com mensagens em **Ready**. Esse é o print mais importante: ele mostra que o produtor publicou mesmo sem consumidor ativo.

### 4. Ligar o consumidor independente

Em um quarto PowerShell:

```powershell
cd C:\Users\gpercope\Documents\GitHub\Lab-DAMD\Code\server
py consumer_worker.py
```

O worker deve processar o backlog e registrar logs para `entrega.criada` e `entrega.status_atualizado`. Atualize a UI do RabbitMQ: a fila `fastdelivery.entregas` deve voltar a **Ready = 0**.

**Print E4 - Consumo em processo separado:** capture os logs do worker mostrando os dois eventos recebidos.  
**Print E5 - Fila esvaziada:** capture a UI com **Ready = 0** após o worker consumir o backlog.

### 5. Consultar o histórico processado

No terminal de cliente:

```powershell
Invoke-RestMethod -Uri "http://localhost:5000/eventos" |
  ConvertTo-Json -Depth 10
```

**Print E6 - Histórico persistente:** capture o JSON contendo os dois eventos processados, seus `evento_id`, tipos, mensagens e payloads.

### 6. Executar testes automatizados

Em outro PowerShell dentro de `Code/server/`:

```powershell
py -m unittest discover -s tests -v
```

**Print E7 - Testes:** capture a saída final com `Ran 8 tests` e `OK`.

## Parte G - Evidências extras para fortalecer a apresentação

### Persistência após reinício do broker

Com o worker desligado, publique uma nova entrega, confirme que existe uma mensagem em **Ready** e rode:

```powershell
docker compose restart rabbitmq
docker compose ps
```

Depois que o container estiver saudável, atualize a UI. A mensagem deve continuar na fila.

**Print extra P1:** fila com backlog antes do reinício.  
**Print extra P2:** mesma fila com backlog depois do reinício.

### Dead-Letter Queue

Com o worker ligado, publique deliberadamente um tópico que não possui handler:

```powershell
py -c "from app.mom.barramento import criar_barramento; from app.mom.eventos import obter_payload; bus=criar_barramento(); bus.publicar('entrega.desconhecida', obter_payload('entrega.desconhecida', {'teste': True})); bus.parar()"
```

Na UI, abra **Queues and Streams** > `fastdelivery.dlq`. A fila deve receber a mensagem rejeitada.

**Print extra D1:** log do worker informando que não existe handler para `entrega.desconhecida`.  
**Print extra D2:** fila `fastdelivery.dlq` com mensagem em **Ready**.

## Parte H - Roteiro curto para apresentar ao professor

1. Mostrar a UI do RabbitMQ e as filas `fastdelivery.entregas` e `fastdelivery.dlq`.
2. Explicar que o Flask é produtor puro e que `consumer_worker.py` roda separado, sem Flask e sem endpoint REST.
3. Manter o worker desligado, executar o `POST` e o `PATCH` e mostrar o backlog crescendo na fila.
4. Ligar o worker e mostrar os dois eventos sendo consumidos.
5. Executar `GET /eventos` e mostrar o histórico persistente.
6. Mostrar rapidamente a saída dos oito testes automatizados.
7. Como evidência extra, demonstrar a DLQ ou a persistência após reinício do RabbitMQ.

## Observação sobre evidências antigas

Os arquivos históricos em `docs/Sprint2/evidencias/` foram produzidos antes da migração e ainda descrevem Redis. Eles não devem ser usados como evidência atual da solução RabbitMQ. Use os prints novos sugeridos nesta documentação.

