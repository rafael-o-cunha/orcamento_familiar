# Orçamento Familiar

Sistema web de orçamento familiar para dois usuários (ex.: um casal): cada um lança receitas e despesas, acompanha o **saldo comum** da casa e o **saldo pessoal** do mês. É um projeto de estágio, um micro universo do sistema orçamentário/financeiro da empresa, com a mesma arquitetura e as mesmas tecnologias.

**Stack:** Java 8 · JSF 2.2 + PrimeFaces 5.2 · WildFly 13 · Hibernate (JPA) · Oracle · Maven

## Documentação

| Documento                                                   | O que contém                                                    |
| ----------------------------------------------------------- | ---------------------------------------------------------------- |
| [Descrição](docs/01-descricao.md)                          | Objetivo, o que será praticado, tecnologias e escopo            |
| [Telas e regras de negócio](docs/02-telas-e-regras.md)      | Wireframes, funcionalidades, regras RN01–RN22 e mensagens       |
| [Especificação técnica](docs/03-especificacao-tecnica.md) | Arquitetura, concorrência, modelo de dados e dicionário Oracle |
| [Tarefas](docs/04-tarefas.md)                                | Pacotes de tarefas (viram issues), labels e homologação        |

## Estrutura

```
.
├── app/                 Projeto Java (Maven, .war) — criado na tarefa T0.1
├── docs/                Documentação do projeto (+ img/ com os diagramas)
├── infra/
│   ├── .env.example     Variáveis do ambiente (copiado para .env)
│   ├── docker-compose.yml
│   ├── app/             Dockerfile do WildFly 13 + datasource Oracle
│   └── db/scripts/      Scripts SQL rodados no primeiro start do Oracle
├── notas/               Anotações do desenvolvedor
├── .github/             Labels, geração de issues, modelos de issue e PR
├── Makefile             Comandos (Linux/macOS)
└── make.bat             Mesmos comandos para Windows
```

## Como rodar

Pré-requisitos: Docker (com `docker compose`) e Git. Java 8 e Maven são opcionais: dá para compilar em container com `make build-docker`.

**Tudo em Docker**

```bash
make setup          # cria infra/.env
make up             # sobe Oracle + WildFly (a primeira vez demora alguns minutos)
make build-docker   # gera app/target/*.war   (ou: make build, com Maven local)
make deploy         # publica o war no WildFly
make logs-app       # acompanha o deploy
```

Aplicação em `http://localhost:8080/orcamento-familiar`, console do WildFly em `http://localhost:9990` (usuário e senha no `infra/.env`) e depuração remota na porta `8787`.

**WildFly direto na máquina**

1. `make db-up` para subir só o Oracle (ou use um Oracle seu).
2. No WildFly 13 local, crie o datasource `java:jboss/datasources/OrcamentoFamiliarDS` apontando para `jdbc:oracle:thin:@localhost:1521/XEPDB1` (os comandos estão em `infra/app/configurar-datasource.cli`).
3. Preencha `WILDFLY_HOME` no `infra/.env`, rode `make build` e `make deploy-local`.

No Windows, troque `make` por `make.bat` (ex.: `make.bat up`).

## Comandos

`make help` lista todos. Os principais:

| Comando                                | O que faz                                                       |
| -------------------------------------- | --------------------------------------------------------------- |
| `make up` / `make down`            | Sobe / para Oracle e WildFly                                    |
| `make build` / `make build-docker` | Gera o `.war` (Maven local / em container)                    |
| `make deploy` / `make redeploy`    | Publica o `.war` / build + publica                            |
| `make test`                          | Roda os testes                                                  |
| `make db-sql`                        | Abre o SQL*Plus no schema `ORCAMENTO`                         |
| `make db-reset`                      | Apaga o banco e roda de novo os scripts de `infra/db/scripts` |
| `make logs-app` / `make logs-db`   | Logs do WildFly / do Oracle                                     |
| `make clean` / `make clean-all`    | Limpa o build / remove containers, volume e imagem              |

## Issues no GitHub

As 29 tarefas de [`docs/04-tarefas.md`](docs/04-tarefas.md) viram issues automaticamente, com labels, um milestone por pacote e o campo "Depende de" ligado às outras issues. Rodar de novo não duplica nada.

- **Pelo GitHub:** aba **Actions** › *Gerar labels e issues* › *Run workflow*. Na primeira vez deixe "simulação" marcado para conferir; depois rode desmarcado.
- **Pela máquina** (com `gh auth login` feito): `make issues-simular` e depois `make issues`.

As labels ficam em [`.github/labels.json`](.github/labels.json). Novas tarefas e defeitos podem ser abertos pelos modelos em *New issue*.

## Fluxo de trabalho

- Uma branch por tarefa: `feature/T2.1-pesquisar`.
- Pull request com `Fecha #<issue>`; o modelo de PR traz o checklist de revisão.
- Status pela label: `to do` → `doing` → `pronto pra teste` (estagiário) → `homologar` → `done` (orientador).
