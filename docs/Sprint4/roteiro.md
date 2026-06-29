# Roteiro do Screencast — Sprint 4 (FastDelivery)

Roteiro para gravar o vídeo de demonstração (3–5 min) exigido pela Sprint 4.
Demonstra o **fluxo completo de ponta a ponta** com os **dois apps rodando ao
mesmo tempo** e a **notificação assíncrona via MOM** (RabbitMQ → WebSocket).

**Duração alvo:** ~4 minutos. **Critérios cobertos (rubrica):** funcionalidade do
app do prestador (25%), fluxo ponta a ponta (30%), notificação assíncrona via
MOM (20%), clareza do screencast (10%).

> Telas/rótulos citados são exatamente os do app. Onde aparece "⭐" é um momento
> que **vale nota** — não corte e deixe acontecer na tela, sem tocar no app.

---

## 1. Antes de gravar (setup — não precisa estar no vídeo)

Suba tudo e deixe as janelas posicionadas **antes** de apertar REC.

### 1.1 Subir backend + MOM (3 terminais em `Code/server`)

```powershell
# Terminal 1 — RabbitMQ (MOM)
cd Code\server
docker compose up -d

# Terminal 2 — Backend (REST + producer + ponte WebSocket)
.\.venv\Scripts\python.exe main.py
#   confirme no log: "Tempo real....: WS  /ws/eventos"

# Terminal 3 — Consumidor de histórico (processo separado)
.\.venv\Scripts\python.exe consumer_worker.py
```

### 1.2 Abrir os dois apps no Chrome (2 terminais em `Code/mobile`)

```powershell
# App do CLIENTE
cd Code\mobile\fastdelivery_cliente
flutter run -d chrome --dart-define=FASTDELIVERY_API_URL=http://localhost:5055

# App do PRESTADOR
cd Code\mobile\fastdelivery_prestador
flutter run -d chrome `
  --dart-define=FASTDELIVERY_API_URL=http://localhost:5055 `
  --dart-define=FASTDELIVERY_WS_URL=ws://localhost:5055/ws/eventos
```

### 1.3 Abas auxiliares (para a cena de evidência do MOM)

- **RabbitMQ Management:** http://localhost:15672 (login `guest` / `guest`).
- **Histórico de eventos:** http://localhost:5055/eventos

### 1.4 Layout da tela (importante para mostrar o tempo real)

- Janela do **cliente à ESQUERDA** e do **prestador à DIREITA**, lado a lado e
  visíveis ao mesmo tempo. É isso que prova a comunicação assíncrona ao vivo.
- No prestador, deixe a aba **"Pendentes"** aberta e confirme o indicador
  **"ao vivo"** (verde) no topo direito = WebSocket conectado.
- Comece com a lista do cliente vazia ou curta (fica mais claro). Se quiser zerar,
  pare o backend e apague `Code/server/entregas.db` antes de subir de novo.

### 1.5 Gravação

- Resolução 1080p, áudio de microfone limpo, feche notificações do sistema.
- Mova o mouse devagar e pause ~2s nos momentos-chave (⭐).

---

## 2. Roteiro cena a cena

| # | Cena | Tempo | Janela em foco |
|---|------|-------|----------------|
| 0 | Abertura | 0:00–0:20 | Tela toda / terminais |
| 1 | Os dois apps lado a lado | 0:20–0:50 | Cliente + Prestador |
| 2 | Cliente cria a solicitação | 0:50–1:40 | Cliente |
| 3 | ⭐ Prestador notificado em tempo real | 1:40–2:15 | Prestador |
| 4 | Prestador aceita | 2:15–2:50 | Prestador |
| 5 | ⭐ Cliente recebe a atualização | 2:50–3:15 | Cliente |
| 6 | Avançar status (trânsito → concluído) | 3:15–3:45 | Prestador + Cliente |
| 7 | Evidência do MOM | 3:45–4:10 | RabbitMQ UI + /eventos |
| 8 | Encerramento | 4:10–4:20 | Tela toda |

---

### Cena 0 — Abertura (0:00–0:20)
**Falar:** "Olá, sou o Giuliano. Este é o FastDelivery, projeto de LDAMD da PUC
Minas. Vou demonstrar a Sprint 4: o app do prestador e a notificação assíncrona
de ponta a ponta entre cliente e prestador, usando MOM com RabbitMQ."
**Fazer:** mostrar rapidamente os terminais rodando (backend com o log
`WS /ws/eventos`, o `consumer_worker.py` ativo e o `docker compose`/RabbitMQ no ar).
**Destacar:** "backend, consumidor e broker já estão no ar".

### Cena 1 — Os dois apps lado a lado (0:20–0:50)
**Falar:** "À esquerda, o app do cliente; à direita, o app do prestador. Repare
no indicador **'ao vivo'** no prestador: ele está conectado ao backend por
WebSocket, então recebe as solicitações em tempo real, sem atualizar a tela."
**Fazer:**
- Cliente: mostrar a tela **FastDelivery** (lista de entregas).
- Prestador: aba **Pendentes**; apontar o ponto verde **"ao vivo"** no topo.
**Destacar:** o "ao vivo" e o fato de as duas janelas estarem visíveis juntas.

### Cena 2 — Cliente cria a solicitação (0:50–1:40)
**Falar:** "O cliente cria uma nova solicitação de entrega."
**Fazer (no app do CLIENTE):**
1. Tocar no botão **"Nova entrega"** (FAB, canto inferior direito).
2. Preencher os campos:
   - **Descrição:** ex. `Documentos contratuais`
   - **Origem:** ex. `Av. Afonso Pena, 1000`
   - **Destino:** ex. `Rua Pium-í, 540`
3. Tocar em **"Criar entrega"**.
4. Aparece o aviso **"Entrega #N criada com sucesso"** e a tela volta para a
   lista, com a entrega no status **"Pendente"**.
**Destacar:** o status inicial **Pendente**.

### Cena 3 — ⭐ Prestador notificado em tempo real (1:40–2:15)
**Falar:** "Repare: eu **não toquei** no app do prestador. A solicitação apareceu
sozinha, com um aviso de **'Nova solicitação'**. O backend publicou o evento
`entrega.criada` no RabbitMQ e a ponte entregou ao app por WebSocket."
**Fazer:** **NÃO clicar em nada** no prestador. Apenas apontar:
- o **snackbar** "Nova solicitação: Documentos contratuais";
- o novo card na aba **Pendentes** (status **Pendente**).
**Destacar (vale nota):** "notificação assíncrona via MOM, sem refresh manual".
Deixe ~3s parado para ficar claro que foi automático.

### Cena 4 — Prestador aceita (2:15–2:50)
**Falar:** "O prestador abre a solicitação e decide aceitar."
**Fazer (no app do PRESTADOR):**
1. Tocar no card da solicitação → abre **"Solicitação #N"**.
2. Mostrar a linha do tempo e os botões **"Recusar"** e **"Aceitar"**.
3. Tocar em **"Aceitar"**.
4. O status vira **"Aceito"** e aparece o aviso **"Solicitação aceita"**.
**Destacar:** os dois botões de decisão e a mudança para **Aceito**.

### Cena 5 — ⭐ Cliente recebe a atualização (2:50–3:15)
**Falar:** "De volta ao cliente — também **sem atualizar a tela** — o status muda
para **Aceito**. Isso fecha o ciclo de ponta a ponta: o cliente é notificado da
atualização feita pelo prestador."
**Fazer (no app do CLIENTE):**
1. Estar na tela de **detalhe** da entrega (ou na lista).
2. **Não tocar em nada**; aguardar até ~5s.
3. O status atualiza sozinho para **Aceito** (o cliente usa polling REST de 5s).
**Destacar (vale nota):** "cliente notificado automaticamente; ciclo completo".

### Cena 6 — Avançar status: trânsito → concluído (3:15–3:45)
**Falar:** "O prestador acompanha a entrega até o fim."
**Fazer (no app do PRESTADOR):**
1. No detalhe da solicitação (status Aceito), tocar em **"Iniciar trânsito"**
   → status **Em trânsito**.
2. Tocar em **"Concluir entrega"** → status **Concluído** (linha do tempo cheia).
3. Mostrar a aba **"Em andamento"** (a entrega aparece enquanto está aceita/em
   trânsito).
**Fazer (no app do CLIENTE):** mostrar que o status também reflete **Em trânsito /
Concluído** (sem atualizar manualmente).
**Destacar:** o fluxo de status completo `pendente → aceito → em_transito → concluido`.

### Cena 7 — Evidência do MOM (3:45–4:10)
**Falar:** "Por baixo, tudo passou pelo MOM. No RabbitMQ vemos o exchange e as
filas; e o endpoint de eventos mostra o histórico processado."
**Fazer:**
1. **RabbitMQ UI** (http://localhost:15672 → aba **Queues and Streams**):
   apontar o exchange `fastdelivery.events` e as filas `fastdelivery.entregas`
   (histórico) e `fastdelivery.realtime` (ponte do WebSocket); comentar os
   contadores de mensagens.
2. **GET /eventos** (http://localhost:5055/eventos): mostrar os registros
   `entrega.criada` e `entrega.status_atualizado` processados.
**Destacar:** "duas filas diferentes ligadas ao mesmo exchange — a do worker de
histórico e a da notificação em tempo real, sem competir entre si".

### Cena 8 — Encerramento (4:10–4:20)
**Falar:** "Resumindo: arquitetura orientada a eventos com MOM (RabbitMQ),
backend REST em Flask, dois apps Flutter em Clean Architecture e notificação
assíncrona de ponta a ponta. Obrigado!"
**Fazer:** mostrar os dois apps lado a lado uma última vez.

---

## 3. Checklist de cobertura (confira antes de finalizar)

- [ ] Os **dois apps** apareceram rodando **simultaneamente**.
- [ ] App do prestador com as **3 telas**: Pendentes, Detalhe (Aceitar/Recusar),
      Em andamento.
- [ ] **Criação** da solicitação no cliente (Pendente).
- [ ] ⭐ Prestador **notificado em tempo real**, sem refresh manual (snackbar + card).
- [ ] Prestador **aceita** (Pendente → Aceito).
- [ ] ⭐ Cliente **recebe a atualização** sozinho (ciclo ponta a ponta fechado).
- [ ] Avanço de status até **Concluído**.
- [ ] **Evidência do MOM**: filas no RabbitMQ + `GET /eventos`.
- [ ] Duração entre **3 e 5 minutos**, áudio claro.

## 4. Plano B (se algo travar na gravação)
- Se o "ao vivo" estiver vermelho/"offline": confirme que o backend está no ar e
  recarregue a aba do prestador (a reconexão re-sincroniza via REST).
- Se o cliente não atualizar no web: aguarde o ciclo de polling (~5s) ou troque de
  tela e volte.
- Em último caso, narre o passo enquanto recarrega a página — o estado vem do
  backend, então nada se perde.
