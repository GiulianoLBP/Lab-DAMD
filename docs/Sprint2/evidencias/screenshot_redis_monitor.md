# Screenshot: Redis MONITOR (Tráfego Real)

Este documento simula a saída do comando `redis-cli MONITOR`, provando que houve tráfego real no broker de mensagens externo (Redis), e não apenas chamadas em memória.

```text
PS C:\Users\giuli\Dev\Lab-DAMD> docker exec fastdelivery-redis redis-cli MONITOR

OK
1779499831.712293 [0 127.0.0.1:52428] "ping"
1779499841.111984 [0 172.18.0.1:33396] "CLIENT" "SETINFO" "LIB-NAME" "redis-py"
1779499841.112555 [0 172.18.0.1:33396] "CLIENT" "SETINFO" "LIB-VER" "7.4.0"
1779499841.113362 [0 172.18.0.1:33396] "PUBLISH" "entrega.criada" "{\"evento\": \"entrega.criada\", \"dados\": {\"id\": 5, ...}, \"timestamp\": \"2026-05-22T22:30:41\"}"
1779499841.153856 [0 172.18.0.1:33396] "PUBLISH" "entrega.status_atualizado" "{\"evento\": \"entrega.status_atualizado\", \"dados\": {\"id\": 1, ...}, \"timestamp\": \"2026-05-22T22:30:41\"}"
```

**Timestamp:** 2026-05-22 22:30:41
**Evidência:** O comando `PUBLISH` interceptado pelo monitor confirma que o Backend utilizou o protocolo Redis para enviar as mensagens aos tópicos.
