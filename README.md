# FastDelivery — Backend REST API

Plataforma de delivery generalista desenvolvida em Flask (Python) com banco de dados SQLite.

## 📋 Visão Geral

FastDelivery é um sistema que conecta **clientes** (que solicitam entregas) e **entregadores** (que aceitam e executam as entregas). Esta é a implementação do backend REST da Sprint 1, com 4 endpoints principais e arquitetura em camadas (Clean Architecture).

## 🏗️ Arquitetura

O código segue **Clean Architecture** com separação em camadas:

```
app/
├── domain/           # Entidades e enums de domínio
├── repositories/     # Acesso aos dados (SQLite)
├── use_cases/        # Lógica de negócio
└── controllers/      # Rotas Flask (thin layer)
```

## 🚀 Setup e Instalação

### Pré-requisitos

- Python 3.8+ (recomendado: 3.12)
- pip (gerenciador de pacotes)
- Docker e Docker Compose (para rodar o MOM Redis)

> **Windows:** use sempre o comando `py` (Python Launcher) em vez de `python` para garantir que o interpretador correto seja usado.

### Passos

1. **Clonar o repositório e entrar na pasta do servidor**
   ```powershell
   git clone <url-do-repositorio>
   cd Lab-DAMD\Code\server
   ```

2. **Subir o Redis (MOM)**
   A partir da Sprint 2, o sistema utiliza Redis para comunicação assíncrona.
   ```powershell
   docker compose up -d
   ```

3. **Criar ambiente virtual** (opcional, mas recomendado)
   ```powershell
   # Windows (PowerShell)
   py -m venv venv
   .\venv\Scripts\Activate.ps1

   # macOS/Linux
   python3 -m venv venv
   source venv/bin/activate
   ```

   > **Nota PowerShell:** se aparecer erro de política de execução, rode primeiro:
   > `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`

3. **Instalar dependências** (dentro de `Code\server\`)
   ```powershell
   pip install -r requirements.txt
   ```

4. **Executar o servidor** (dentro de `Code\server\`)
   ```powershell
   # Modo padrão (com Redis rodando via Docker)
   $env:REDIS_HOST = "localhost"
   py main.py

   # Modo Fallback (sem Redis — eventos em memória)
   py main.py
   ```

   O servidor iniciará em `http://localhost:5000`

### Variáveis de Ambiente

O sistema detecta automaticamente o mecanismo de mensageria:
- `REDIS_HOST` ou `REDIS_URL`: ativa o **RedisEventBus** (Produção/Integração).
- Caso omitidas: ativa o **InMemoryEventBus** (Desenvolvimento/Testes rápidos).

## 🛰️ Sprint 2 — Integração com MOM

O sistema implementa o padrão **Publish-Subscribe** para notificar eventos de entrega de forma assíncrona.

- **Produtor:** `EntregaUseCases` dispara eventos ao criar ou atualizar status.
- **Consumidor:** Uma thread daemon (`consumer.py`) escuta os tópicos e processa a lógica de negócio secundária (como logs e histórico).
- **Broker:** Redis (Pub/Sub) via Docker.

### Tópicos Disponíveis
- `entrega.criada`: Disparado ao criar uma nova entrega.
- `entrega.status_atualizado`: Disparado ao alterar o status de uma entrega.

## 📊 Schema do Banco de Dados

### Tabela: `entregas`

| Campo | Tipo | Restrições | Descrição |
|-------|------|-----------|-----------|
| `id` | INTEGER | PRIMARY KEY, AUTOINCREMENT | Identificador único da entrega |
| `descricao` | TEXT | NOT NULL | Descrição do item a entregar |
| `origem` | TEXT | NOT NULL | Endereço de origem |
| `destino` | TEXT | NOT NULL | Endereço de destino |
| `status` | TEXT | NOT NULL, DEFAULT 'pendente' | Status atual (ver valores abaixo) |
| `cliente_id` | TEXT | NOT NULL | ID do cliente que solicitou |
| `criado_em` | TEXT | NOT NULL | Timestamp de criação (ISO 8601) |
| `atualizado_em` | TEXT | NOT NULL | Timestamp da última atualização (ISO 8601) |

#### Valores válidos para `status`

- `pendente` — Entrega aguardando aceite de um entregador
- `aceito` — Entregador aceitou a entrega
- `em_transito` — Entrega a caminho do destino
- `concluido` — Entrega finalizada com sucesso
- `cancelado` — Entrega foi cancelada

```sql
CREATE TABLE entregas (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    descricao   TEXT    NOT NULL,
    origem      TEXT    NOT NULL,
    destino     TEXT    NOT NULL,
    status      TEXT    NOT NULL DEFAULT 'pendente',
    cliente_id  TEXT    NOT NULL,
    criado_em   TEXT    NOT NULL DEFAULT (datetime('now')),
    atualizado_em TEXT  NOT NULL DEFAULT (datetime('now'))
);
```

## 🔌 Endpoints da API

### 1. POST /entregas

**Criar nova solicitação de entrega**

**Request:**
```bash
curl -X POST http://localhost:5000/entregas \
  -H "Content-Type: application/json" \
  -d '{
    "descricao": "Buscar encomenda",
    "origem": "Rua A, 100",
    "destino": "Rua B, 200",
    "cliente_id": "cliente-uuid-123"
  }'
```

**Response (201 Created):**
```json
{
  "id": 1,
  "descricao": "Buscar encomenda",
  "origem": "Rua A, 100",
  "destino": "Rua B, 200",
  "status": "pendente",
  "cliente_id": "cliente-uuid-123",
  "criado_em": "2026-05-11T10:00:00",
  "atualizado_em": "2026-05-11T10:00:00"
}
```

---

### 2. GET /entregas

**Listar todas as entregas**

**Request:**
```bash
# Listar todas
curl http://localhost:5000/entregas

# Filtrar por status
curl http://localhost:5000/entregas?status=pendente
```

**Response (200 OK):**
```json
[
  {
    "id": 1,
    "descricao": "Buscar encomenda",
    "origem": "Rua A, 100",
    "destino": "Rua B, 200",
    "status": "pendente",
    "cliente_id": "cliente-uuid-123",
    "criado_em": "2026-05-11T10:00:00",
    "atualizado_em": "2026-05-11T10:00:00"
  }
]
```

---

### 3. GET /entregas/`<id>`

**Consultar detalhes de uma entrega específica**

**Request:**
```bash
curl http://localhost:5000/entregas/1
```

**Response (200 OK):**
```json
{
  "id": 1,
  "descricao": "Buscar encomenda",
  "origem": "Rua A, 100",
  "destino": "Rua B, 200",
  "status": "pendente",
  "cliente_id": "cliente-uuid-123",
  "criado_em": "2026-05-11T10:00:00",
  "atualizado_em": "2026-05-11T10:00:00"
}
```

**Response (404 Not Found):**
```json
{
  "error": "Entrega não encontrada"
}
```

---

### 4. PATCH /entregas/`<id>`/status

**Atualizar status de uma entrega**

**Request:**
```bash
curl -X PATCH http://localhost:5000/entregas/1/status \
  -H "Content-Type: application/json" \
  -d '{"status": "aceito"}'
```

**Response (200 OK):**
```json
{
  "id": 1,
  "descricao": "Buscar encomenda",
  "origem": "Rua A, 100",
  "destino": "Rua B, 200",
  "status": "aceito",
  "cliente_id": "cliente-uuid-123",
  "criado_em": "2026-05-11T10:00:00",
  "atualizado_em": "2026-05-11T10:00:50"
}
```

**Response (400 Bad Request):**
```json
{
  "error": "Status inválido"
}
```

**Response (404 Not Found):**
```json
{
  "error": "Entrega não encontrada"
}
```

---

### 5. GET /eventos

**Listar eventos processados pelo consumidor MOM**

**Request:**
```bash
# Obter últimos eventos (padrão 10)
curl http://localhost:5000/eventos

# Filtrar quantidade
curl http://localhost:5000/eventos?ultimos=5
```

**Response (200 OK):**
```json
[
  {
    "tipo": "entrega.criada",
    "entrega_id": 1,
    "mensagem": "Nova entrega criada: Buscar encomenda",
    "processado_em": "2026-05-22T10:00:00",
    "payload": { "id": 1, "status": "pendente" }
  }
]
```

---

## 🧪 Testando a API

### Com Postman/Insomnia

Importe o arquivo `postman_collection.json` na sua ferramenta de testes (Postman, Insomnia, etc.). A coleção contém todos os 4 endpoints pré-configurados com exemplos de request e documentação.

### Evidências de execução

Todos os endpoints foram testados com o servidor rodando localmente em `http://localhost:5000`.

#### POST /entregas — Criar nova entrega

![POST /entregas](docs/Image/POST-entregas.png)

Cria uma nova solicitação com status inicial `pendente`. Retorna `201 Created` com o objeto completo.

---

#### GET /entregas — Listar todas as entregas

![GET /entregas](docs/Image/GET-entregas.png)

Lista todas as entregas cadastradas. Suporta filtro opcional `?status=<valor>`. Retorna `200 OK` com array de objetos.

---

#### GET /entregas/\<id\> — Consultar entrega por ID

![GET /entregas/id](docs/Image/GET-entregas-id.png)

Retorna os detalhes de uma entrega específica. Retorna `200 OK` com o objeto ou `404 Not Found` se o id não existir.

---

#### PATCH /entregas/\<id\>/status — Atualizar status

![PATCH /entregas/id/status](docs/Image/PATCH-entregas-id-stauts.png)

Atualiza o status de uma entrega existente. Retorna `200 OK` com o objeto atualizado, `400 Bad Request` para status inválido ou `404 Not Found` se o id não existir.

### Com curl

Veja exemplos nos endpoints acima ou use:

```bash
# Criar entrega
curl -X POST http://localhost:5000/entregas \
  -H "Content-Type: application/json" \
  -d '{"descricao":"Test","origem":"A","destino":"B","cliente_id":"c1"}'

# Listar entregas
curl http://localhost:5000/entregas

# Obter entrega específica
curl http://localhost:5000/entregas/1

# Atualizar status
curl -X PATCH http://localhost:5000/entregas/1/status \
  -H "Content-Type: application/json" \
  -d '{"status":"aceito"}'
```

## 📁 Estrutura do Projeto

```
Lab-DAMD/
├── Code/
│   └── server/
│       ├── app/
│       │   ├── domain/
│       │   │   └── models.py              # Entidades (Entrega, StatusEntrega)
│       │   ├── repositories/
│       │   │   └── entrega_repository.py  # Acesso a SQLite
│       │   ├── use_cases/
│       │   │   └── entrega_use_cases.py   # Lógica de negócio
│       │   ├── controllers/
│       │   │   └── entrega_controller.py  # Rotas Flask
│       │   ├── mom/                       # Camada de mensageria (EventBus)
│       │   └── database.py                # Conexão SQLite
│       ├── main.py                        # Entry point
│       ├── docker-compose.yml             # Infra Redis
│       └── requirements.txt               # Dependências
├── docs/
│   └── Sprint2/                           # Documentação da Integração MOM
├── postman_collection.json                # Coleção de testes (v2)
└── README.md                              # Este arquivo
```

## 📑 Documentação da Sprint 2

- [Guia de Eventos e Tópicos](docs/Sprint2/eventos.md)
- [Relatório Técnico de Integração](docs/Sprint2/Relatorio_Sprint2.md)
- [Evidências de Execução MOM](docs/Sprint2/evidencias/)

## 🔧 Dependências

- **Flask** — Framework web HTTP
- **Redis** — Driver para integração com MOM
- **SQLite3** — Banco de dados (já vem com Python)

Veja `requirements.txt` para a versão exata.

## 📝 Notas de Desenvolvimento

- O banco de dados SQLite é inicializado automaticamente no primeiro start
- Timestamps utilizam formato ISO 8601 (UTC)
- Todos os erros retornam JSON estruturado com campo `error`
- A validação de status ocorre na camada de use cases
- O modo Fallback (`InMemoryEventBus`) permite rodar o projeto sem Docker para fins de desenvolvimento rápido.

## 📋 Sprint 1 — Checklist

- [x] Estrutura de Clean Architecture definida
- [x] Banco de dados SQLite com schema
- [x] Modelo de domínio (Entrega + StatusEntrega enum)
- [x] Repository com CRUD
- [x] Use cases (lógica de negócio)
- [x] Flask routes (POST, GET, PATCH)
- [x] Validação e tratamento de erros
- [x] Coleção Postman
- [x] README

## 📋 Sprint 2 — Checklist (MOM)

- [x] Barramento abstrato e implementações (Redis + Memory)
- [x] Docker Compose para Redis local
- [x] Produtor de eventos integrado aos Use Cases
- [x] Consumidor em thread daemon com histórico
- [x] Novo endpoint `GET /eventos`
- [x] Diagrama C4 atualizado com MOM sólido
- [x] Relatório de integração e catálogo de eventos
- [x] Evidências de tráfego real no Redis (MONITOR)

## 📚 Próximas Fases

**Sprint 3:** App Flutter — Cliente
**Sprint 4:** App Flutter — Entregador + Relatório Final

---

**Desenvolvido para:** Lab. de Desenvolvimento de Aplicações Móveis e Distribuídas (LDAMD) — PUC Minas
