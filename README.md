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

- Python 3.8+
- pip (gerenciador de pacotes)

### Passos

1. **Clonar o repositório**
   ```bash
   git clone <url-do-repositorio>
   cd Lab-DAMD
   ```

2. **Criar ambiente virtual (opcional, mas recomendado)**
   ```bash
   python -m venv venv
   # Windows
   venv\Scripts\activate
   # macOS/Linux
   source venv/bin/activate
   ```

3. **Instalar dependências**
   ```bash
   pip install -r requirements.txt
   ```

4. **Executar o servidor**
   ```bash
   python main.py
   ```

   O servidor iniciará em `http://localhost:5000`

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

## 🧪 Testando a API

### Com Postman/Insomnia

Importe o arquivo `postman_collection.json` na sua ferramenta de testes (Postman, Insomnia, etc.). A coleção contém todos os 4 endpoints pré-configurados com exemplos de request e documentação.

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
│       │   └── database.py                # Conexão SQLite
│       ├── main.py                        # Entry point
│       └── requirements.txt               # Dependências
├── postman_collection.json                # Coleção de testes
└── README.md                              # Este arquivo
```

## 🔧 Dependências

- **Flask** — Framework web HTTP
- **SQLite3** — Banco de dados (já vem com Python)

Veja `requirements.txt` para a versão exata.

## 📝 Notas de Desenvolvimento

- O banco de dados SQLite é inicializado automaticamente no primeiro start
- Timestamps utilizam formato ISO 8601 (UTC)
- Todos os erros retornam JSON estruturado com campo `error`
- A validação de status ocorre na camada de use cases

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

## 📚 Próximas Fases

**Sprint 2:** Integração com Message Queue (RabbitMQ ou Redis) para eventos assíncronos
**Sprint 3:** App Flutter — Cliente
**Sprint 4:** App Flutter — Entregador + Relatório Final

---

**Desenvolvido para:** Lab. de Desenvolvimento de Aplicações Móveis e Distribuídas (LDAMD) — PUC Minas
