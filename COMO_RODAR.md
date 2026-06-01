# Como rodar a aplicacao

Este guia mostra como executar localmente a API Flask do FastDelivery.

## Pre-requisitos

- Python 3.8 ou superior
- pip
- PowerShell, no Windows

No Windows, use o comando `py` para executar o Python.

## Passo a passo

1. Abra o terminal na raiz do projeto.

2. Entre na pasta do servidor:

```powershell
cd Code\server
```

3. Crie um ambiente virtual:

```powershell
py -m venv venv
```

4. Ative o ambiente virtual:

```powershell
.\venv\Scripts\Activate.ps1
```

Se o PowerShell bloquear a ativacao do ambiente virtual, execute:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

Depois tente ativar novamente:

```powershell
.\venv\Scripts\Activate.ps1
```

5. Instale as dependencias:

```powershell
pip install -r requirements.txt
```

6. Inicie a aplicacao:

```powershell
py main.py
```

Ao iniciar corretamente, a API ficara disponivel em:

```text
http://localhost:5000
```

O banco SQLite `entregas.db` sera criado automaticamente na primeira execucao.

## Teste rapido

Com a aplicacao rodando, abra outro terminal e execute:

```powershell
curl http://localhost:5000/entregas
```

Para criar uma entrega:

```powershell
curl -X POST http://localhost:5000/entregas `
  -H "Content-Type: application/json" `
  -d '{"descricao":"Entrega teste","origem":"Rua A","destino":"Rua B","cliente_id":"cliente-1"}'
```

## Encerrar a aplicacao

No terminal em que o servidor esta rodando, pressione:

```text
Ctrl + C
```

Para sair do ambiente virtual:

```powershell
deactivate
```
