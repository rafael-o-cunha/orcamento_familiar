# Scripts do banco

Os arquivos `.sql` desta pasta rodam automaticamente, em ordem alfabética, **só no primeiro start** do container Oracle (quando o volume de dados está vazio). Para rodar de novo: `make db-reset`.

Nomes esperados (criados na tarefa T0.2):

| Arquivo | Conteúdo |
| --- | --- |
| `01_ddl.sql` | Tabelas, sequences, PK, FK, UK, CHECK e índices (dicionário em `docs/03-especificacao-tecnica.md`) |
| `02_carga.sql` | 2 usuários, 2 limites de R$ 1.000,00, parâmetro ID 1 e linha de controle do saldo comum |

## Cuidados

A imagem executa os scripts como `SYS`. Comece **cada** arquivo apontando para o banco e o schema da aplicação:

```sql
ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = ORCAMENTO;
```

Sem isso as tabelas são criadas no schema errado. O usuário `ORCAMENTO` (variável `DB_USER` do `infra/.env`) já é criado pela imagem antes dos scripts.

Para rodar sem Docker, execute os mesmos arquivos no seu Oracle conectado como `ORCAMENTO` (as duas linhas `ALTER SESSION` podem ser removidas nesse caso).
