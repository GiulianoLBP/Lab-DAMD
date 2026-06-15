# Evidências — Sprint 3

Esta pasta guarda as evidências da Sprint 3 (app Flutter Cliente).

## Verificação automatizada (capturada nesta máquina)

| Arquivo | Comando | Resultado |
|---|---|---|
| `backend_unittest.txt` | `py -m unittest discover -s tests -v` (em `Code/server/`) | `Ran 24 tests ... OK` |
| `flutter_analyze.txt` | `flutter analyze` (em `Code/mobile/fastdelivery_cliente/`) | `No issues found!` |
| `flutter_test.txt` | `flutter test` | `All tests passed!` (15 testes) |

Os testes de backend cobrem a matriz API01–API10 do plano de testes mais o
cancelamento pelo cliente; os testes Flutter cobrem FL01–FL08 (model, service,
badge, formulário e estado vazio).

## Capturas da demonstração (preencher no run ao vivo)

Rode backend + worker + app e salve aqui:

- `01_lista.png` — lista de entregas do cliente.
- `02_form.png` — formulário de nova entrega preenchido.
- `03_detalhe_pendente.png` — detalhes com status `pendente`.
- `04_detalhe_aceito.png` — detalhes após `PATCH .../status {aceito}` via
  curl/Postman, **sem toque manual** (atualização por polling em até 5s).
- `05_backend_log.png` — backend recebendo as requisições REST.
- `06_worker_log.png` — `consumer_worker.py` processando os eventos.

Roteiro detalhado da demo: `docs/Sprint3/plano_testes_e_aceite.md` (seção
"Roteiro manual de demonstração", passos D01–D07).

> Observação: as capturas de tela dependem de um dispositivo/emulador em
> execução e devem ser geradas durante a apresentação. A verificação
> automatizada (acima) já está registrada nos `.txt` desta pasta.
