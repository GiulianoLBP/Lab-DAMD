# Analise do diagrama C4 - Sprint 1

Arquivo analisado: `docs/architecture/fastdelivery-c4.drawio`

Referencia principal: item 3.2 do PDF `docs/Projeto_LAMD_60445_2026_1.pdf`.

## Veredito

O diagrama C4 esta majoritariamente correto para a Sprint 1, porque representa os elementos exigidos no item 3.2:

- App Cliente
- App Entregador / Prestador
- Backend REST
- Banco de dados SQLite
- MOM, indicado como RabbitMQ / Redis
- Protocolos de comunicacao entre os principais componentes

Porem, eu faria alguns ajustes antes de considerar o diagrama final para entrega, principalmente na representacao do MOM e nos protocolos associados a ele.

## O que o item 3.2 pede

O item 3.2 da Sprint 1 exige um diagrama de arquitetura com:

- representacao visual dos componentes do sistema;
- apps;
- backend;
- MOM;
- banco de dados;
- identificacao dos protocolos de comunicacao utilizados.

O diagrama pode ser feito em Draw.io, Mermaid, C4 Model ou ferramenta equivalente.

## Pontos corretos no diagrama atual

1. O diagrama mostra os dois perfis esperados:
   - Cliente;
   - Entregador.

2. O diagrama mostra os dois aplicativos moveis planejados:
   - App Cliente em Flutter/Dart;
   - App Entregador em Flutter/Dart.

3. O backend esta representado como:
   - Backend API;
   - Flask/Python;
   - responsavel por regras de negocio via REST.

4. O banco SQLite aparece como container separado e ligado ao backend por SQL.

5. Os protocolos principais aparecem no diagrama:
   - App Cliente -> Backend API: REST/HTTPS;
   - App Entregador -> Backend API: REST/HTTPS;
   - Backend API -> SQLite: SQL;
   - Backend API -> MOM: AMQP;
   - App Entregador -> MOM: AMQP.

6. O MOM aparece como elemento planejado para Sprint 2, o que esta coerente com a proposta do projeto, pois a Sprint 1 implementa o backend REST e deixa a mensageria para a proxima etapa.

## Ajustes que eu faria

### 1. Mover o MOM para dentro da fronteira do sistema

No diagrama atual, `RabbitMQ / Redis` aparece como `[External System]`, fora da fronteira `FastDelivery Platform`.

Eu alteraria isso para:

```text
RabbitMQ / Redis Pub/Sub
[Container: Message Broker]
Async event broker planned for Sprint 2.
```

Motivo: o item 3.2 trata o MOM como componente da arquitetura do sistema, junto dos apps, backend e banco de dados. Mesmo que ele so seja implementado na Sprint 2, ele faz parte da arquitetura planejada do FastDelivery.

### 2. Escolher RabbitMQ ou Redis no diagrama, em vez de deixar os dois juntos

O diagrama usa `RabbitMQ / Redis`, mas os protocolos indicados sao `AMQP`.

Eu escolheria uma das opcoes:

- Se a escolha for RabbitMQ:

```text
RabbitMQ
[Container: Message Broker]
Protocol: AMQP
```

- Se a escolha for Redis Pub/Sub:

```text
Redis Pub/Sub
[Container: Message Broker]
Protocol: Redis Pub/Sub
```

Motivo: AMQP e RabbitMQ combinam diretamente. Redis Pub/Sub nao usa AMQP. Deixar `RabbitMQ / Redis` com protocolo `AMQP` pode ser interpretado como imprecisao tecnica.

### 3. Manter as setas de mensageria tracejadas, mas explicar melhor

As setas tracejadas para o MOM estao corretas porque indicam funcionalidade futura.

Eu ajustaria os textos para deixar claro que fazem parte da arquitetura planejada:

```text
Backend API -> Message Broker
Publishes delivery events [AMQP ou Redis Pub/Sub] - Sprint 2
```

```text
App Entregador -> Message Broker
Consumes delivery events [AMQP ou Redis Pub/Sub] - Sprint 2
```

Motivo: a Sprint 1 pede a arquitetura geral, mas a implementacao do MOM so e cobrada na Sprint 2. A anotacao evita parecer que a mensageria ja esta implementada.

### 4. Renomear "Entregador" para "Prestador (Entregador)"

No PDF, o perfil generico e `prestador de servicos`; na proposta do FastDelivery, esse prestador e o `entregador`.

Eu usaria:

```text
Prestador (Entregador)
```

Motivo: aproxima o diagrama da linguagem da especificacao sem perder o nome do dominio.

### 5. Detalhar melhor as responsabilidades dos apps

Eu ajustaria as descricoes dos containers:

```text
App Cliente
[Container: Flutter/Dart]
Creates deliveries and tracks delivery status.
```

```text
App Entregador
[Container: Flutter/Dart]
Views available deliveries, accepts requests and updates status.
```

Motivo: isso conecta diretamente o diagrama as funcionalidades descritas na proposta e aos endpoints da Sprint 1.

## Conclusao

O diagrama atende a base do item 3.2, mas eu nao deixaria o MOM como `[External System]` se a intencao for representar a arquitetura do FastDelivery. A principal correcao seria transforma-lo em um container planejado dentro da fronteira do sistema e escolher um protocolo consistente com a tecnologia escolhida.

Minha recomendacao final e:

```text
Usar RabbitMQ como Message Broker e AMQP como protocolo.
```

Essa escolha deixa o diagrama mais direto, evita ambiguidade tecnica e prepara melhor a arquitetura para a Sprint 2.
