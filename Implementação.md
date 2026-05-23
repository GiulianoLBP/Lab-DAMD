# Implementação — Sprint 2 (Integração com MOM)

Este documento divide a Sprint 2 do FastDelivery em tarefas executáveis, com **condições de aceite** e **testes verificáveis** para que a IA possa concluir cada item sem ambiguidade.

> **Prazo:** 25/05/2026 — **Pontos:** 20 — **Hoje:** 22/05/2026

---

## 0. Visão geral — Status atual do código

A camada MOM **já está implementada** em `Code/server/app/mom/`. O que falta é, na maior parte, **evidência operacional, documentação e relatório**. Resumo do que existe:

| Componente | Arquivo | Status |
|------------|---------|--------|
| Barramento abstrato (`EventBus` ABC) | `app/mom/barramento.py` | ✅ Implementado |
| Fallback `InMemoryEventBus` (thread daemon) | `app/mom/barramento.py` | ✅ Implementado |
| Implementação real `RedisEventBus` (Pub/Sub) | `app/mom/barramento.py` | ✅ Implementado |
| Factory `criar_barramento()` (env vars) | `app/mom/barramento.py` | ✅ Implementado |
| Definição de tópicos e payloads | `app/mom/eventos.py` | ✅ Implementado |
| `EntregaEventProducer` (2 eventos) | `app/mom/producer.py` | ✅ Implementado |
| Handlers consumidores + histórico (100 max) | `app/mom/consumer.py` | ✅ Implementado |
| Bootstrap MOM no `main.py` | `main.py` | ✅ Implementado |
| Endpoint `GET /eventos` | `app/controllers/entrega_controller.py` | ✅ Implementado |
| Disparo de eventos nos use cases | `app/use_cases/entrega_use_cases.py` | ✅ Implementado |
| **Documentação formal dos eventos** | `docs/Sprint2/eventos.md` | ❌ Pendente |
| **Relatório de integração (PDF, 1 pág)** | `docs/Sprint2/Relatorio_Sprint2.pdf` | ❌ Pendente |
| **Diagrama C4 atualizado (MOM ativo)** | `docs/architecture/fastdelivery-c4.drawio` | ❌ Pendente (Redis ainda marcado como "futuro") |
| **Evidência de execução com Redis** | `docs/Sprint2/evidencias/` | ❌ Pendente |
| **docker-compose para Redis** | `Code/server/docker-compose.yml` | ❌ Pendente |
| **Postman atualizado (incluir `/eventos`)** | `postman_collection.json` | ❌ Pendente |
| **README atualizado (Sprint 2)** | `README.md` | ❌ Pendente |

---

## 1. Tarefas pendentes (em ordem de execução)

### TASK-01 — Setup Redis local via Docker Compose

**Descrição.** Adicionar arquivo `docker-compose.yml` em `Code/server/` para subir um Redis local rapidamente, sem instalação no host. Documenta o jeito padrão do projeto para rodar o MOM real.

**Arquivos a criar/editar:**
- Criar: `Code/server/docker-compose.yml`
- Criar: `Code/server/.dockerignore` (opcional)

**Conteúdo proposto (`docker-compose.yml`):**

```yaml
version: '3.9'
services:
  redis:
    image: redis:7-alpine
    container_name: fastdelivery-redis
    ports:
      - "6379:6379"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
```

**Condições de aceite:**
- [ ] `docker compose up -d` (a partir de `Code/server/`) sobe o container e retorna sem erro.
- [ ] `docker ps` mostra `fastdelivery-redis` com status `healthy`.
- [ ] Porta 6379 acessível em `localhost`.

**Teste a rodar:**
```powershell
cd Code/server
docker compose up -d
docker exec fastdelivery-redis redis-cli ping   # deve retornar "PONG"
```

---

### TASK-02 — Validar funcionamento com Redis real (end-to-end)

**Descrição.** Subir o servidor com `REDIS_HOST=localhost`, criar entregas, alterar status, e verificar que tanto o **producer** publica no Redis quanto o **consumer** processa os eventos. Esta é a evidência exigida pelo critério "MOM funcionando corretamente" (25% / 5pts).

**Pré-requisitos:** TASK-01 concluída.

**Procedimento:**
1. Subir Redis: `docker compose up -d` (em `Code/server/`).
2. Iniciar backend: `$env:REDIS_HOST = "localhost"; py main.py`.
3. Confirmar nos logs: `Barramento criado: Redis (via REDIS_HOST)` e `[Redis] Consumidor iniciado em thread daemon`.
4. Em outro terminal, executar testes (TASK-04).

**Condições de aceite:**
- [ ] Log de startup mostra `Mecanismo MOM.: redis`.
- [ ] Após `POST /entregas`, log do producer aparece: `Evento publicado: entrega.criada (entrega #N)`.
- [ ] Logo em seguida, log do consumer: `[Redis] Recebido de "entrega.criada"` + `CONSUMIDOR → Nova entrega criada!`.
- [ ] Após `PATCH /entregas/<id>/status`, mesma cadeia para `entrega.status_atualizado`.
- [ ] `GET /eventos` retorna ambos os eventos no histórico.
- [ ] **Não há chamada REST entre producer e consumer** — o consumer está numa thread daemon dentro do mesmo processo, escutando o Pub/Sub.

**Teste a rodar:**
```powershell
# Terminal 1
cd Code/server
docker compose up -d
$env:REDIS_HOST = "localhost"
py main.py

# Terminal 2
curl -X POST http://localhost:5000/entregas `
  -H "Content-Type: application/json" `
  -d '{"descricao":"Pacote teste","origem":"A","destino":"B","cliente_id":"c1"}'

curl -X PATCH http://localhost:5000/entregas/1/status `
  -H "Content-Type: application/json" `
  -d '{"status":"aceito"}'

curl http://localhost:5000/eventos
```

**Saída esperada de `GET /eventos`:** array com 2 itens (`entrega.criada` e `entrega.status_atualizado`), com `mensagem` e `processado_em` preenchidos.

---

### TASK-03 — Coletar evidências de execução

**Descrição.** Capturar provas exigidas pelo critério "MOM funcionando corretamente (evidência)". Logs em texto + screenshots compõem a prova.

**Arquivos a criar:**
- `docs/Sprint2/evidencias/logs_startup.txt` — copy-paste dos logs do `py main.py`.
- `docs/Sprint2/evidencias/logs_fluxo.txt` — logs durante POST + PATCH + GET /eventos.
- `docs/Sprint2/evidencias/screenshot_terminal_producer_consumer.png` — terminal mostrando ambos.
- `docs/Sprint2/evidencias/screenshot_redis_monitor.png` — saída de `redis-cli MONITOR` durante um POST.
- `docs/Sprint2/evidencias/screenshot_get_eventos.png` — Postman/curl retornando histórico.

**Comando útil para Redis MONITOR (prova de tráfego real no broker):**
```powershell
docker exec -it fastdelivery-redis redis-cli MONITOR
```

**Condições de aceite:**
- [ ] Pasta `docs/Sprint2/evidencias/` criada com **pelo menos 3 screenshots** + 2 arquivos `.txt` de log.
- [ ] Cada screenshot tem timestamp visível.
- [ ] Em `redis-cli MONITOR` aparecem comandos `PUBLISH "entrega.criada" ...` e `PUBLISH "entrega.status_atualizado" ...`.

---

### TASK-04 — Documentação formal dos eventos (`eventos.md`)

**Descrição.** Criar tabela em Markdown documentando cada evento conforme exigido pelo critério "Qualidade e completude da documentação dos eventos" (20% / 4pts). Já temos o dicionário em `app/mom/eventos.py`, mas o avaliador precisa ler isso em formato legível.

**Arquivo a criar:** `docs/Sprint2/eventos.md`

**Estrutura mínima:**

```markdown
# FastDelivery — Catálogo de Eventos (Sprint 2)

| Evento | Tópico | Produtor | Consumidor | Quando dispara |
|--------|--------|----------|------------|----------------|
| Entrega Criada | `entrega.criada` | `EntregaUseCases.criar_entrega()` | `consumer._ao_criar_entrega` | Após `POST /entregas` |
| Status Alterado | `entrega.status_atualizado` | `EntregaUseCases.atualizar_status()` | `consumer._ao_alterar_status` | Após `PATCH /entregas/<id>/status` |

## Payloads (JSON)

### entrega.criada
```json
{ ... payload completo ... }
```

### entrega.status_atualizado
```json
{ ... payload completo ... }
```

## Diagrama de fluxo
(diagrama mermaid sequencial cliente → REST → use_case → producer → bus → consumer)
```

**Condições de aceite:**
- [ ] Arquivo tem **tabela**, **payloads JSON reais** (copiados da execução, não inventados) e **diagrama sequencial mermaid**.
- [ ] Payloads bate exatamente com o que `obter_payload()` em `app/mom/eventos.py` gera (chaves `evento`, `dados`, `timestamp`).
- [ ] Documenta também o tópico interno: `entrega.criada` e `entrega.status_atualizado`.

**Teste a rodar:**
```powershell
# Valida que os payloads no .md batem com o código
Select-String -Path docs/Sprint2/eventos.md -Pattern "entrega.criada","entrega.status_atualizado"
```

---

### TASK-05 — Atualizar diagrama C4 (MOM ativo, não mais "futuro")

**Descrição.** O `docs/architecture/fastdelivery-c4.drawio` atual marca o Redis como `(future, dashed)`. Para Sprint 2, atualizar para sólido + descrição realista.

**Arquivos a editar:**
- `docs/architecture/fastdelivery-c4.drawio`

**Mudanças necessárias:**
1. Container "Redis (MOM)" deixa de ser tracejado.
2. Adicionar container "Consumer Service" dentro do Backend (thread daemon).
3. Setas: `Backend → Redis` (publish) + `Redis → Consumer Service` (subscribe), ambas sólidas com label `AMQP-like / Pub/Sub`.
4. Manter setas futuras tracejadas: `Redis → App Entregador` (Sprint 4).

**Condições de aceite:**
- [ ] Diagrama abre sem erro no draw.io / VS Code.
- [ ] Redis aparece como container "ativo" (sólido).
- [ ] Consumer Service aparece como container separado dentro do boundary do backend.
- [ ] Exportar PNG do diagrama em `docs/Sprint2/evidencias/fastdelivery-c4-sprint2.png`.

**Teste a rodar:** abrir manualmente o `.drawio` e validar visualmente; exportar PNG.

---

### TASK-06 — Atualizar Postman collection (incluir `GET /eventos`)

**Descrição.** A coleção atual cobre apenas os 4 endpoints da Sprint 1. Adicionar o novo endpoint `GET /eventos` com exemplos.

**Arquivos a editar:**
- `postman_collection.json`

**Item a adicionar:**
- Nome: `GET /eventos — Histórico MOM`
- URL: `http://localhost:5000/eventos`
- Query opcional: `ultimos=10`
- Exemplo de response (200 OK): copiar do retorno real obtido na TASK-02.

**Condições de aceite:**
- [ ] `postman_collection.json` é JSON válido (`Get-Content postman_collection.json | ConvertFrom-Json` não dá erro).
- [ ] Existem **5 requests** na coleção (4 antigos + 1 novo).
- [ ] O novo request tem exemplo de response salvo.

**Teste a rodar:**
```powershell
Get-Content postman_collection.json | ConvertFrom-Json | Select-Object -ExpandProperty item | Measure-Object
# Deve listar 5 requests
```

---

### TASK-07 — Relatório de integração (PDF, 1 página)

**Descrição.** Critério "Clareza do relatório de integração" (10% / 2pts). Documento curto cobrindo:
1. **Escolha da ferramenta** — por que Redis Pub/Sub (vs RabbitMQ): simplicidade, baixa dependência, pub/sub idiomático.
2. **Padrão arquitetural** — Publish-Subscribe + Strategy (fallback InMemory para dev) + Producer/Consumer decoupled.
3. **Fluxo dos eventos** — diagrama curto + descrição.
4. **Decisão de fallback** — `InMemoryEventBus` para rodar testes sem broker.
5. **Desafios encontrados** — exemplos: garantir que o consumer não duplica no `flask debug reload` (resolvido com `use_reloader=False`); ordem de inicialização (consumer antes de Flask aceitar conexões).
6. **Limitações** — Pub/Sub é fire-and-forget (sem persistência), aceitável para Sprint 2; para produção considerar Streams.

**Arquivos a criar:**
- `docs/Sprint2/Relatorio_Sprint2.md` (fonte editável)
- `docs/Sprint2/Relatorio_Sprint2.pdf` (entregável — converter via pandoc ou ferramenta de markdown→PDF)

**Condições de aceite:**
- [ ] PDF tem **no máximo 2 páginas** (alvo: 1 página densa).
- [ ] Cobre os **6 pontos** listados acima.
- [ ] Inclui **pelo menos 1 referência bibliográfica** (Hohpe & Woolf — Enterprise Integration Patterns é a natural).
- [ ] PDF gera sem erro a partir do Markdown.

**Teste a rodar:**
```powershell
# Validar com pandoc (se instalado)
pandoc docs/Sprint2/Relatorio_Sprint2.md -o docs/Sprint2/Relatorio_Sprint2.pdf
```

---

### TASK-08 — Atualizar README com instruções Sprint 2

**Descrição.** Adicionar nova seção no `README.md` cobrindo: como subir Redis, env vars, novo endpoint, link para `docs/Sprint2/eventos.md`.

**Arquivos a editar:**
- `README.md`

**Seções a adicionar:**
1. `## Sprint 2 — Integração com MOM`
2. Subseções: "Subir Redis com Docker", "Variáveis de ambiente (`REDIS_URL`, `REDIS_HOST`)", "Modo fallback (InMemory)", "Endpoint `GET /eventos`".
3. Link para `docs/Sprint2/eventos.md` (catálogo de eventos) e `docs/Sprint2/Relatorio_Sprint2.pdf`.
4. Atualizar checklist no final ("Sprint 1 — Checklist" passa a incluir "Sprint 2 — Checklist").

**Condições de aceite:**
- [ ] README renderiza no GitHub sem quebra.
- [ ] Tem instrução clara para rodar **com** e **sem** Redis (modo fallback).
- [ ] Marca Sprint 2 como "✅ entregue" no checklist.

---

### TASK-09 — Verificação cruzada com critérios oficiais

**Descrição.** Antes de declarar a sprint pronta, mapear cada critério de avaliação a uma evidência concreta.

**Critérios oficiais (PDF, página 5):**

| Critério (peso) | Evidência |
|-----------------|-----------|
| MOM funcionando (25%) | TASK-02 + TASK-03 (screenshots + logs + Redis MONITOR) |
| Producer + consumer (30%) | `app/mom/producer.py` + `app/mom/consumer.py` (já implementados, validados em TASK-02) |
| Documentação eventos (20%) | TASK-04 (`docs/Sprint2/eventos.md`) + dicionário em `app/mom/eventos.py` |
| Assincronicidade real (15%) | TASK-03 (Redis MONITOR mostra PUBLISH; consumer em thread separada não recebe via REST) |
| Relatório (10%) | TASK-07 (`Relatorio_Sprint2.pdf`) |

**Condição de aceite:**
- [ ] Cada linha da tabela acima tem **um arquivo concreto** apontável no repositório.
- [ ] Rodar o checklist da TASK-10.

---

### TASK-10 — Checklist final de entrega

```
[ ] docker-compose.yml em Code/server/
[ ] Servidor sobe com REDIS_HOST=localhost e logs mostram "Mecanismo MOM.: redis"
[ ] POST /entregas dispara entrega.criada (visível no log do producer E do consumer)
[ ] PATCH /entregas/<id>/status dispara entrega.status_atualizado
[ ] GET /eventos retorna histórico com ambos os eventos
[ ] Servidor sobe SEM Redis (fallback) e ainda dispara/processa eventos
[ ] docs/Sprint2/eventos.md com tabela + payloads + mermaid
[ ] docs/Sprint2/Relatorio_Sprint2.pdf (1 página)
[ ] docs/Sprint2/evidencias/ com >= 3 screenshots + 2 logs.txt
[ ] docs/architecture/fastdelivery-c4.drawio atualizado (Redis sólido)
[ ] postman_collection.json com 5 requests
[ ] README.md com seção Sprint 2
[ ] Cada uma das 11 etapas tem 1 commit separado (vide CLAUDE.md, seção 5)
```

---

## 2. Plano de validação E2E (script único)

Antes de fazer o último commit, rodar a sequência completa abaixo do zero:

```powershell
# 1. Limpa estado
Remove-Item Code/server/entregas.db -ErrorAction SilentlyContinue
docker compose -f Code/server/docker-compose.yml down -v

# 2. Sobe Redis
docker compose -f Code/server/docker-compose.yml up -d
Start-Sleep -Seconds 2
docker exec fastdelivery-redis redis-cli ping   # PONG

# 3. Inicia servidor
cd Code/server
$env:REDIS_HOST = "localhost"
Start-Process powershell -ArgumentList "py main.py"
Start-Sleep -Seconds 3

# 4. Cria 2 entregas
curl -X POST http://localhost:5000/entregas -H "Content-Type: application/json" -d '{"descricao":"E2E-1","origem":"X","destino":"Y","cliente_id":"c1"}'
curl -X POST http://localhost:5000/entregas -H "Content-Type: application/json" -d '{"descricao":"E2E-2","origem":"P","destino":"Q","cliente_id":"c2"}'

# 5. Altera status
curl -X PATCH http://localhost:5000/entregas/1/status -H "Content-Type: application/json" -d '{"status":"aceito"}'
curl -X PATCH http://localhost:5000/entregas/2/status -H "Content-Type: application/json" -d '{"status":"em_transito"}'

# 6. Consulta histórico — deve retornar 4 eventos
curl http://localhost:5000/eventos

# 7. Encerra
docker compose -f Code/server/docker-compose.yml down
```

**Resultado esperado:** O passo 6 retorna **array com 4 elementos** (2 `entrega.criada` + 2 `entrega.status_atualizado`), e o terminal do servidor mostra logs de producer + consumer para cada operação.

---

## 3. Sequência de commits sugerida (Sprint 2)

Conforme CLAUDE.md §5 (cada etapa = 1 commit). Os commits da camada MOM já existem; faltam os de documentação/evidência:

```
feat: add docker-compose for Redis MOM
docs: add formal events catalog (docs/Sprint2/eventos.md)
docs: capture Sprint 2 execution evidence (logs + screenshots)
docs: update C4 diagram — Redis MOM is now active
chore: add GET /eventos to Postman collection
docs: add Sprint 2 integration report (PDF)
docs: update README with Sprint 2 setup and MOM section
```

---

## 4. Notas técnicas para a IA

- **Não reescrever** os arquivos em `app/mom/` — eles estão funcionais. Apenas validar e documentar.
- **Validar com Redis real** é obrigatório: o critério é "evidência de funcionamento". Logs do fallback InMemory **não substituem** os logs do Redis.
- O `use_reloader=False` em `main.py` é proposital: sem isso, o Flask debug spawn duplica a thread do consumer. Documentar isso no relatório (TASK-07).
- O histórico de eventos (`_eventos_processados` em `consumer.py`) é em memória — limita 100 e perde no restart. Isso é aceitável para Sprint 2, mas deve ser registrado como limitação no relatório.
- Ao rodar o `MONITOR` no Redis, esperar comandos `PUBLISH` (não `SUBSCRIBE`) na evidência — `SUBSCRIBE` foi emitido na inicialização, antes do MONITOR estar ligado.
