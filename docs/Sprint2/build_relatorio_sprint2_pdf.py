from __future__ import annotations

from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    KeepTogether,
    PageBreak,
    PageTemplate,
    Paragraph,
    Preformatted,
    Spacer,
    Table,
    TableStyle,
)


HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "Relatorio_Sprint2_RabbitMQ.pdf"
PAGE_WIDTH, PAGE_HEIGHT = letter
LEFT = RIGHT = 0.82 * inch
TOP = 0.68 * inch
BOTTOM = 0.62 * inch
CONTENT = PAGE_WIDTH - LEFT - RIGHT

BLUE = colors.HexColor("#2E74B5")
DARK_BLUE = colors.HexColor("#1F4D78")
GRAY = colors.HexColor("#666666")
LIGHT_GRAY = colors.HexColor("#F2F4F7")
NOTE_BLUE = colors.HexColor("#E8EEF5")


styles = getSampleStyleSheet()
styles.add(ParagraphStyle(
    name="ReportTitle", parent=styles["Title"], fontName="Helvetica-Bold",
    fontSize=20, leading=23, alignment=TA_LEFT, textColor=colors.black,
    spaceAfter=3,
))
styles.add(ParagraphStyle(
    name="ReportSubtitle", parent=styles["Normal"], fontName="Helvetica-Bold",
    fontSize=12.5, leading=15, textColor=BLUE, spaceAfter=8,
))
styles.add(ParagraphStyle(
    name="Meta", parent=styles["Normal"], fontName="Helvetica",
    fontSize=8.2, leading=9.5, textColor=GRAY, spaceAfter=1,
))
styles.add(ParagraphStyle(
    name="BodyCompact", parent=styles["BodyText"], fontName="Helvetica",
    fontSize=9.2, leading=11.2, textColor=colors.black, spaceAfter=4,
))
styles.add(ParagraphStyle(
    name="H1Report", parent=styles["Heading1"], fontName="Helvetica-Bold",
    fontSize=13.2, leading=15, textColor=BLUE, spaceBefore=7, spaceAfter=4,
))
styles.add(ParagraphStyle(
    name="H2Report", parent=styles["Heading2"], fontName="Helvetica-Bold",
    fontSize=11, leading=13, textColor=DARK_BLUE, spaceBefore=5, spaceAfter=3,
))
styles.add(ParagraphStyle(
    name="TableCell", parent=styles["BodyText"], fontName="Helvetica",
    fontSize=7.8, leading=9.2, textColor=colors.black,
))
styles.add(ParagraphStyle(
    name="TableHeader", parent=styles["BodyText"], fontName="Helvetica-Bold",
    fontSize=7.8, leading=9.2, textColor=DARK_BLUE,
))
styles.add(ParagraphStyle(
    name="CodeReport", parent=styles["Code"], fontName="Courier",
    fontSize=6.9, leading=8.1, leftIndent=5, rightIndent=5, spaceAfter=4,
))
styles.add(ParagraphStyle(
    name="NoteReport", parent=styles["BodyText"], fontName="Helvetica",
    fontSize=8.1, leading=9.8, textColor=colors.black,
))
styles.add(ParagraphStyle(
    name="BulletReport", parent=styles["BodyText"], fontName="Helvetica",
    fontSize=8.8, leading=10.7, leftIndent=13, firstLineIndent=-8, spaceAfter=2,
))


def p(text: str, style="BodyCompact") -> Paragraph:
    return Paragraph(text, styles[style])


def h1(text: str) -> Paragraph:
    return Paragraph(text, styles["H1Report"])


def h2(text: str) -> Paragraph:
    return Paragraph(text, styles["H2Report"])


def code(text: str) -> Preformatted:
    return Preformatted(text.strip("\n"), styles["CodeReport"])


def bullet(text: str, number: str = "-") -> Paragraph:
    return Paragraph(f"{number} {text}", styles["BulletReport"])


def table(headers: list[str], rows: list[list[str]], widths: list[float]) -> Table:
    data = [[Paragraph(value, styles["TableHeader"]) for value in headers]]
    data.extend([
        [Paragraph(value, styles["TableCell"]) for value in row]
        for row in rows
    ])
    result = Table(data, colWidths=widths, repeatRows=1, hAlign="LEFT")
    result.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), LIGHT_GRAY),
        ("GRID", (0, 0), (-1, -1), 0.35, colors.HexColor("#B8C2CC")),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]))
    return result


def note(text: str) -> Table:
    result = Table(
        [[Paragraph(f"<b>Nota:</b> {text}", styles["NoteReport"])]],
        colWidths=[CONTENT],
        hAlign="LEFT",
    )
    result.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), NOTE_BLUE),
        ("BOX", (0, 0), (-1, -1), 0.35, colors.HexColor("#AABBCD")),
        ("LEFTPADDING", (0, 0), (-1, -1), 7),
        ("RIGHTPADDING", (0, 0), (-1, -1), 7),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]))
    return result


def footer(canvas, doc) -> None:
    canvas.saveState()
    canvas.setFont("Helvetica", 7.5)
    canvas.setFillColor(GRAY)
    canvas.drawString(LEFT, 0.35 * inch, "FastDelivery | Sprint 2 | Integração MOM")
    canvas.drawRightString(PAGE_WIDTH - RIGHT, 0.35 * inch, f"Página {doc.page}")
    canvas.restoreState()


def first_page() -> list:
    return [
        p("RELATÓRIO DE INTEGRAÇÃO MOM", "ReportTitle"),
        p("Sprint 2 - FastDelivery com RabbitMQ", "ReportSubtitle"),
        p("<b>Disciplina:</b> Laboratório de Desenvolvimento de Aplicações Móveis e Distribuídas", "Meta"),
        p("<b>Projeto:</b> FastDelivery", "Meta"),
        p("<b>Referência:</b> seção 3.3, página 5 do enunciado Projeto_LAMD_60445_2026_1", "Meta"),
        p("<b>Escopo:</b> integração assíncrona orientada a eventos com RabbitMQ", "Meta"),
        h1("Objetivo"),
        p("A Sprint 2 integrou um Middleware Orientado a Mensagens (MOM) ao backend Flask do FastDelivery. O objetivo foi permitir que fatos relevantes do domínio de entregas fossem publicados e processados de forma assíncrona, sem chamada REST direta entre produtor e consumidor."),
        h1("Decisões de design"),
        p("Foi adotado o RabbitMQ por ser um broker dedicado, com suporte nativo a filas duráveis, mensagens persistentes, confirmação de publicação, confirmação manual de consumo e Dead-Letter Queue (DLQ). O padrão aplicado é Publish-Subscribe sobre a exchange topic <b>fastdelivery.events</b>."),
        p("O backend Flask atua como produtor. Por padrão, o consumidor roda em outro processo com <b>py consumer_worker.py</b>. Assim, o produtor publica mesmo quando o consumidor está desligado; a fila <b>fastdelivery.entregas</b> armazena o backlog; quando o worker inicia, ele consome as mensagens pendentes."),
        h1("Fluxo implementado"),
        bullet("<b>POST /entregas</b> cria uma entrega e publica <b>entrega.criada</b>.", "1."),
        bullet("<b>PATCH /entregas/&lt;id&gt;/status</b> altera o estado e publica <b>entrega.status_atualizado</b>.", "2."),
        p("Os eventos seguem pela exchange <b>fastdelivery.events</b> para a fila durável <b>fastdelivery.entregas</b>. O worker processa a mensagem e somente então envia ack. Falhas recebem nack(requeue=False) e seguem para <b>fastdelivery.dlq</b>."),
        h1("Desafios e conclusão"),
        p("A primeira versão utilizava Redis. A revisão técnica motivou a migração para RabbitMQ e a inclusão de mensagens persistentes (delivery_mode=2), publisher confirms, uma tentativa de reconexão, DLQ e histórico idempotente no SQLite por evento_id. A solução atende ao enunciado: o broker é o ponto central, existem dois eventos de negócio documentados e o fluxo assíncrono pode ser demonstrado por logs, UI do RabbitMQ e GET /eventos."),
    ]


def requirement_page() -> list:
    return [
        PageBreak(),
        h1("Anexo 1 - Conferência do enunciado"),
        p("A seção 3.3 solicita MOM operacional com evidência, produtor e consumidor, publicação em dois momentos de negócio, catálogo dos eventos, prova de assincronicidade e relatório de integração de uma página. A página anterior é o relatório principal; os anexos apoiam a demonstração."),
        table(["Requisito", "Implementação", "Evidência recomendada"], [
            ["MOM operacional", "RabbitMQ via Docker Compose, AMQP 5672 e UI 15672", "UI e docker compose ps"],
            ["Produtor e consumidor", "EntregaEventProducer e consumer_worker.py", "Terminais separados"],
            ["Dois momentos", "Criação e alteração de status", "Logs dos dois tópicos"],
            ["Catálogo", "Eventos, routing keys e payloads", "Anexo 2"],
            ["Assincronicidade", "Backlog com worker desligado", "Ready > 0 e depois Ready = 0"],
            ["Relatório", "Síntese de decisões e desafios", "Primeira página"],
        ], [1.34 * inch, 2.62 * inch, 2.46 * inch]),
        h1("O que foi adicionado"),
        table(["Componente", "Responsabilidade"], [
            ["app/mom/barramento.py", "Interface EventBus, RabbitMQEventBus e InMemoryEventBus para testes"],
            ["app/mom/eventos.py", "Tópicos, payload comum e evento_id"],
            ["app/mom/producer.py", "Publicação dos fatos do domínio"],
            ["app/mom/consumer.py", "Handlers, histórico persistente e deduplicação"],
            ["consumer_worker.py", "Consumidor standalone sem Flask ou REST"],
            ["evento_processado_repository.py", "Histórico compartilhado no SQLite"],
            ["docker-compose.yml", "RabbitMQ com UI e volume persistente"],
            ["GET /eventos", "Consulta aos eventos processados"],
        ], [2.2 * inch, 4.22 * inch]),
        h1("Garantias técnicas"),
        bullet("Exchange topic fastdelivery.events e fila durável fastdelivery.entregas ligada com routing key #."),
        bullet("delivery_mode=2, publisher confirms e mandatory=True."),
        bullet("Ack manual após sucesso; nack(requeue=False) envia falhas para fastdelivery.dlq."),
        bullet("Nova tentativa após falha de conexão e deduplicação por evento_id no SQLite."),
    ]


def catalog_page() -> list:
    return [
        PageBreak(),
        h1("Anexo 2 - Catálogo de eventos"),
        h2("entrega.criada"),
        table(["Campo", "Valor"], [
            ["Momento", "Após EntregaUseCases.criar_entrega() persistir a nova entrega"],
            ["Produtor", "EntregaEventProducer.entrega_criada()"],
            ["Consumidor", "_ao_criar_entrega() executado por consumer_worker.py"],
            ["Exchange / routing key", "fastdelivery.events / entrega.criada"],
            ["Fila", "fastdelivery.entregas"],
        ], [1.72 * inch, 4.7 * inch]),
        code("""{
  "evento_id": "uuid-gerado-na-publicacao",
  "evento": "entrega.criada",
  "dados": {
    "id": 1, "descricao": "Pacote Sprint 2",
    "origem": "Rua A, 100", "destino": "Rua B, 200",
    "status": "pendente", "cliente_id": "cliente-001"
  },
  "timestamp": "2026-06-01T10:00:00"
}"""),
        h2("entrega.status_atualizado"),
        table(["Campo", "Valor"], [
            ["Momento", "Após EntregaUseCases.atualizar_status() persistir o novo estado"],
            ["Produtor", "EntregaEventProducer.status_alterado()"],
            ["Consumidor", "_ao_alterar_status() executado por consumer_worker.py"],
            ["Exchange / routing key", "fastdelivery.events / entrega.status_atualizado"],
            ["Fila", "fastdelivery.entregas"],
        ], [1.72 * inch, 4.7 * inch]),
        code("""{
  "evento_id": "uuid-gerado-na-publicacao",
  "evento": "entrega.status_atualizado",
  "dados": {
    "id": 1, "status_anterior": "pendente",
    "status_novo": "aceito", "cliente_id": "cliente-001"
  },
  "timestamp": "2026-06-01T10:02:00"
}"""),
    ]


def tests_page() -> list:
    return [
        PageBreak(),
        h1("Anexo 3 - Testes executados"),
        p("Comando executado em <b>Code/server/</b>:"),
        code("py -m unittest discover -s tests -v"),
        p("Resultado obtido em 01/06/2026:"),
        code("Ran 8 tests in 0.087s\nOK"),
        table(["Teste", "Validação"], [
            ["Modo em memória explícito", "EVENT_BUS=in_memory cria o barramento reservado a testes"],
            ["Configuração padrão", "Sem variável específica, cria RabbitMQEventBus"],
            ["Ack de sucesso", "Handler bem-sucedido produz basic_ack"],
            ["Falha de handler", "Exceção produz basic_nack(requeue=False) para DLQ"],
            ["Tópico desconhecido", "Mensagem sem handler também segue para DLQ"],
            ["Canal encerrado", "A conexão de publicação é substituída"],
            ["Falha transitória", "O produtor repete a publicação uma vez"],
            ["Idempotência", "O mesmo evento_id é persistido uma única vez"],
        ], [2.3 * inch, 4.12 * inch]),
        Spacer(1, 6),
        note("<b>tests/test_entregas.py</b> ainda é um placeholder. Os endpoints REST devem ser comprovados manualmente no roteiro a seguir. Não apresente a suíte MOM como se também cobrisse endpoints."),
    ]


def evidence_page_one() -> list:
    return [
        PageBreak(),
        h1("Anexo 4 - Roteiro de execução e prints"),
        h2("1. Preparar o broker"),
        p("Abra o Docker Desktop. Depois execute em um PowerShell:"),
        code(r"""cd C:\Users\gpercope\Documents\GitHub\Lab-DAMD\Code\server
docker compose up -d
docker compose ps
Copy-Item .env.example .env -ErrorAction SilentlyContinue
pip install -r requirements.txt"""),
        p("Abra <b>http://localhost:15672</b> e entre com <b>guest / guest</b>."),
        note("<b>Print E1:</b> capture docker compose ps e, na UI, Queues and Streams com fastdelivery.entregas e fastdelivery.dlq."),
        h2("2. Subir apenas o backend produtor"),
        code(r"""cd C:\Users\gpercope\Documents\GitHub\Lab-DAMD\Code\server
py main.py"""),
        note("<b>Print E2:</b> capture o terminal do Flask mostrando Mecanismo MOM.: rabbitmq e Consumidor in-process: OFF."),
        h2("3. Publicar com o worker desligado"),
        code(r"""$body = @{
  descricao = "Pacote demonstracao Sprint 2"
  origem = "Rua A, 100"
  destino = "Rua B, 200"
  cliente_id = "cliente-001"
} | ConvertTo-Json

$entrega = Invoke-RestMethod -Method Post `
  -Uri "http://localhost:5055/entregas" `
  -ContentType "application/json" -Body $body

Invoke-RestMethod -Method Patch `
  -Uri "http://localhost:5055/entregas/$($entrega.id)/status" `
  -ContentType "application/json" -Body '{"status":"aceito"}'"""),
        note("<b>Print E3:</b> com o worker desligado, abra Queues and Streams &gt; fastdelivery.entregas e capture Ready aumentando em 2. Este é o print principal da assincronicidade."),
    ]


def evidence_page_two() -> list:
    return [
        PageBreak(),
        h1("Anexo 4 - Roteiro de execução e prints (continuação)"),
        h2("4. Ligar o consumidor independente"),
        code(r"""cd C:\Users\gpercope\Documents\GitHub\Lab-DAMD\Code\server
py consumer_worker.py"""),
        note("<b>Print E4:</b> capture os logs do worker para entrega.criada e entrega.status_atualizado. <b>Print E5:</b> atualize a UI e capture Ready = 0."),
        h2("5. Consultar o histórico"),
        code(r"""Invoke-RestMethod -Uri "http://localhost:5055/eventos" |
  ConvertTo-Json -Depth 10"""),
        note("<b>Print E6:</b> capture o JSON contendo os dois eventos, seus evento_id, tipos, mensagens e payloads."),
        h2("6. Executar a suíte automatizada"),
        code("py -m unittest discover -s tests -v"),
        note("<b>Print E7:</b> capture a saída final com Ran 8 tests e OK."),
        h2("Evidências extras"),
        p("Persistência: com o worker desligado, publique uma entrega, confira Ready &gt; 0 e execute:"),
        code("docker compose restart rabbitmq\ndocker compose ps"),
        p("Após o container ficar saudável, a mensagem deve continuar na fila. Capture antes e depois."),
        p("DLQ: com o worker ligado, publique um tópico sem handler:"),
        code("""$codigo = @'
from app.mom.barramento import criar_barramento
from app.mom.eventos import obter_payload
bus = criar_barramento()
bus.publicar('entrega.desconhecida',
             obter_payload('entrega.desconhecida', {'teste': True}))
bus.parar()
'@
py -c $codigo"""),
        p("Capture o log do worker e a fila <b>fastdelivery.dlq</b> com mensagem em Ready."),
    ]


def presentation_page() -> list:
    return [
        PageBreak(),
        h1("Anexo 5 - Roteiro curto para apresentação"),
        bullet("Mostrar a UI do RabbitMQ e as filas fastdelivery.entregas e fastdelivery.dlq.", "1."),
        bullet("Explicar que o Flask é produtor puro e que consumer_worker.py roda separado, sem Flask e sem REST.", "2."),
        bullet("Manter o worker desligado, executar POST e PATCH e mostrar o backlog crescendo.", "3."),
        bullet("Ligar o worker e mostrar os dois eventos sendo consumidos.", "4."),
        bullet("Executar GET /eventos e mostrar o histórico persistente.", "5."),
        bullet("Mostrar rapidamente a saída dos oito testes automatizados.", "6."),
        bullet("Como evidência extra, demonstrar a DLQ ou a persistência após reinício do RabbitMQ.", "7."),
        h1("Aviso sobre evidências antigas"),
        note("Os arquivos em <b>docs/Sprint2/evidencias</b> foram gerados antes da migração e ainda descrevem Redis. Não use esses registros como prova atual da solução RabbitMQ. Produza capturas novas com o roteiro deste documento."),
    ]


def build() -> None:
    doc = BaseDocTemplate(
        str(OUTPUT),
        pagesize=letter,
        leftMargin=LEFT,
        rightMargin=RIGHT,
        topMargin=TOP,
        bottomMargin=BOTTOM,
        title="FastDelivery - Relatório Sprint 2 - RabbitMQ",
        author="FastDelivery",
    )
    frame = Frame(LEFT, BOTTOM, CONTENT, PAGE_HEIGHT - TOP - BOTTOM, id="normal")
    doc.addPageTemplates([PageTemplate(id="report", frames=[frame], onPage=footer)])
    story = []
    for section in (
        first_page(),
        requirement_page(),
        catalog_page(),
        tests_page(),
        evidence_page_one(),
        evidence_page_two(),
        presentation_page(),
    ):
        story.extend(section)
    doc.build(story)
    print(OUTPUT)


if __name__ == "__main__":
    build()
