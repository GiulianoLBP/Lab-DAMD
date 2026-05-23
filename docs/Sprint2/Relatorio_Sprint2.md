# FastDelivery — Relatório de Integração MOM (Sprint 2)

**Disciplina:** Laboratório de Desenvolvimento de Aplicações Móveis e Distribuídas (LDAMD)  
**Data:** 22 de maio de 2026  
**Autor:** GitHub Copilot (Agente de Desenvolvimento)

## 1. Escolha da Ferramenta: Redis Pub/Sub

Para a implementação do mecanismo de Message-Oriented Middleware (MOM) nesta fase do projeto FastDelivery, optou-se pelo **Redis Pub/Sub** em detrimento do RabbitMQ. As principais justificativas para essa decisão foram:

*   **Simplicidade e Baixa Sobrecarga:** O Redis é uma ferramenta extremamente leve que muitos projetos já utilizam para cache e estado. O modelo Pub/Sub do Redis é direto e ideal para as necessidades atuais de sinalização simples entre componentes.
*   **Facilidade de Configuração:** A integração com o ecossistema Python via biblioteca `redis-py` é trivial, permitindo uma implementação rápida e estável.
*   **Baixa Dependência para Desenvolvimento:** O Redis é facilmente provisionado via Docker, mas também permitiu a construção de um modo de compatibilidade robusto.

## 2. Padrão Arquitetural e Design

A arquitetura do subsistema MOM segue o padrão **Publish-Subscribe**, garantindo o desacoplamento total entre o produtor de eventos e os consumidores.

*   **Camadas Limpas (Clean Architecture):** A lógica de mensageria foi isolada no módulo `app/mom/`, impedindo que detalhes de infraestrutura vazem para os Casos de Uso ou Entidades.
*   **Strategy Pattern para Flexibilidade:** Foi implementada uma abstração baseada na interface `EventBus` (ABC). Isso permite que o sistema alterne entre diferentes mecanismos de transporte em tempo de execução.
*   **Bootstrap Assíncrono:** O consumidor de eventos opera em uma **thread daemon** separada, garantindo que o processamento dos eventos não bloqueie o loop principal do Flask (REST API).

## 3. Fluxo de Eventos

O fluxo operacional de um evento segue os seguintes passos:

1.  **Ação de Negócio:** O `EntregaUseCases` executa uma alteração (ex: criação ou mudança de status).
2.  **Publicação:** O `EntregaEventProducer` é invocado para formatar o payload e publicá-lo via `EventBus`.
3.  **Distribuição:** O barramento (Redis ou InMemory) encaminha a mensagem para todos os assinantes registrados.
4.  **Processamento:** O `consumer.py` intercepta a mensagem, extrai os dados e executa os handlers específicos (ex: salvar no histórico para consulta via `GET /eventos`).

## 4. Decisões de Fallback: InMemoryEventBus

Uma decisão arquitetural crítica foi a inclusão do `InMemoryEventBus`. Este mecanismo utiliza listas de callbacks e threads internas para simular o comportamento de um MOM sem a necessidade de um servidor Redis externo. 

Esta escolha foi motivada pela necessidade de:
*   Facilitar o desenvolvimento local rápido.
*   Permitir a execução de testes automatizados em ambientes de CI/CD sem infraestrutura adicional.
*   Garantir a resiliência do sistema: caso o Redis falhe na conexão inicial, o sistema pode optar por degradar graciosamente para o modo memória (se configurado).

## 5. Desafios Técnicos e Soluções

O maior desafio encontrado foi a **duplicação de threads consumidoras** durante o desenvolvimento com o modo *debug* do Flask. O *reloader* do Flask reinicia o processo principal, o que causava a inicialização de múltiplos consumidores competindo pelo mesmo broker.

**Solução:** Foi aplicado o parâmetro `use_reloader=False` no método `app.run()`. Além disso, a ordem de inicialização foi ajustada no `main.py` para garantir que o consumidor esteja pronto para escutar antes mesmo da API começar a aceitar conexões HTTP.

## 6. Limitações e Próximos Passos

O modelo Pub/Sub do Redis é, por natureza, **"fire-and-forget"**. Se um consumidor estiver offline no momento da publicação, ele não receberá a mensagem ao retornar. Para a Sprint 2, esta limitação é aceitável devido ao escopo de notificação em tempo real. 

Para a produção futura ou necessidades de persistência garantida, o projeto está preparado estruturalmente para migrar a implementação concreta do `EventBus` para **Redis Streams** ou **RabbitMQ**, mantendo a interface inalterada.

## 7. Referências Bibliográficas

*   HOHPE, G.; WOOLF, B. **Enterprise Integration Patterns**: Designing, Building, and Deploying Messaging Solutions. Boston: Addison-Wesley, 2003.
*   MARTIN, Robert C. **Arquitetura Limpa**: O guia do artesão para estrutura e design de software. Rio de Janeiro: Alta Books, 2019.
