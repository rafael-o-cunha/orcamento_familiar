# Scripts do banco

Os arquivos `.sql` desta pasta rodam automaticamente, em ordem alfabética, **só no primeiro start** do container Oracle (quando o volume de dados está vazio). Para rodar de novo: `make db-reset`.

| Arquivo | Conteúdo |
| --- | --- |
| `01_ddl.sql` | Pronto (Oracle 19c). Sequences, 8 tabelas, PK, FK sem cascade, FL_ATIVO (exclusão lógica), UK, CHECK, índices e comentários, conforme o dicionário em `docs/03-especificacao-tecnica.md` |
| `02_carga.sql` | A criar na tarefa T0.2: 2 usuários, 2 limites de R$ 1.000,00, parâmetro ID 1, regras de anexo ID 1, tipos de arquivo ativos (jpg, png, pdf) e linha de controle do saldo comum |

## Cuidados

A imagem executa os scripts como `SYS`. Comece **cada** arquivo apontando para o banco e o schema da aplicação:

```sql
ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = ORCAMENTO;
```

Sem isso as tabelas são criadas no schema errado. O usuário `ORCAMENTO` (variável `DB_USER` do `infra/.env`) já é criado pela imagem antes dos scripts.

Para rodar sem Docker, execute os mesmos arquivos no seu Oracle conectado como `ORCAMENTO` (as duas linhas `ALTER SESSION` podem ser removidas nesse caso).
