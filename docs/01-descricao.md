# Orçamento Familiar — Descrição do projeto

O **Orçamento Familiar** é um sistema web de orçamento familiar onde dois usuários (ex.: um casal) lançam receitas e despesas, acompanham o saldo comum da residência e o saldo pessoal mensal de cada um.

## Documentos do projeto

| Documento                                              | O que contém                                                       |
| ------------------------------------------------------ | ------------------------------------------------------------------- |
| [Descrição](01-descricao.md)                          | Objetivo, o que será praticado, tecnologias e escopo               |
| [Telas e regras de negócio](02-telas-e-regras.md)      | Exemplos de tela, funcionalidades e regras de negócio              |
| [Especificação técnica](03-especificacao-tecnica.md) | Arquitetura, concorrência, modelo de dados e dicionário (Oracle)  |
| [Tarefas](04-tarefas.md)                                | Pacotes de tarefas (issues), labels, homologação e acompanhamento |

## O que será praticado

| Conceito                        | Onde aparece no projeto                                                                                                 |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| CRUD                            | Incluir, consultar, editar e excluir lançamentos                                                                       |
| Grid paginada                   | `p:dataTable` lazy com paginação e ordenação feitas no banco                                                      |
| Filtros dinâmicos              | Filtro por período, natureza, escopo, forma, usuário e título                                                        |
| Validação                     | Campos obrigatórios na tela (JSF) e regras de negócio no Business                                                     |
| Upload e download de arquivos   | Cupons anexados ao lançamento, gravados em BLOB e baixados na consulta                                                 |
| Concorrência                   | Bloqueio otimista (`@Version`) no saldo comum, com mensagem e atualização da tela em caso de conflito               |
| Controle de transação         | Transações realizadas a través do Hibernate.                                                                         |
| Dados financeiros               | `BigDecimal`, `NUMBER(15,6)`, saldo acumulado, saldo mensal por usuário, data de efetivação (fatura do crédito) |
| Requisição assíncrona (AJAX) | `p:ajax`, `update`/`process`, seleção na grid, dialogs sem recarregar a página                                 |
| Controle de estado de tela      | Botões habilitados por seleção, dialog com modos consulta/inclusão/edição                                         |
| Login e logout                  | Hash de senha, sessão, filtro de páginas protegidas                                                                   |
| Modelo de dados                 | Modelagem ER, PK, FK, UK, CHECK, sequences no Oracle                                                                    |
| Consultas SQL                   | SQL nativo, válido para paginado e parâmetros nomeados usando Hibernate                                               |
| Mapeamento JPA                  | Entidades, enums, `@Version etc.`                                                                                     |
| Arquitetura em camadas          | View → Controller → Business → DAO, com DTOs Filtro/Model/Helper/VO                                                  |
| Parametrização                | Limites (com histórico de vigência) e regras de upload configuráveis em tela                                         |
| Datas                           | `java.time`, regra do ano corrente, competência mensal                                                               |
| Testes                          | JUnit, Mockito e teste de concorrência com threads                                                                     |

## Tecnologias

| Camada        | Tecnologia               | Observação                                                             |
| ------------- | ------------------------ | ------------------------------------------------------------------------ |
| Linguagem     | Java 8                   | Usar `java.time` (LocalDate) e `BigDecimal` para valores             |
| Front-end     | JSF 2.2 + PrimeFaces 5.2 | `p:dataTable` lazy, `p:dialog`, `p:fileUpload`, `p:fileDownload` |
| Servidor      | WildFly 13 (JBoss)       | Datasource Oracle configurado no `standalone.xml`                      |
| Persistência | Hibernate (JPA)          | Entidades mapeadas + SQL nativo para consultas da grid e saldos          |
| Transação   | Hibernate - JPA          | Hibernate implementa recursos, basta usar.                               |
| Banco         | Oracle                   | Sequences para PKs                                                       |
| Build         | Maven                    | Empacotamento `.war`                                                   |
| Anexos        | Storage                  | Armazenamento de arquivos.                                               |

## Escopo

| Módulo          | O que entrega                                                                            |
| ---------------- | ---------------------------------------------------------------------------------------- |
| Login            | Autenticação dos 2 usuários; redireciona para a tela de lançamentos                  |
| Lançamentos     | Grid paginada com filtro; consultar, incluir, editar e excluir receitas/despesas; anexos |
| Saldos           | Saldo geral (comum) e saldo pessoal disponível de cada usuário no mês                 |
| Parametrização | Limites de crédito pessoal, limite mínimo comum/pessoal e regras de upload             |

Fora do escopo: cadastro de novos usuários pela tela (os 2 usuários são criados por script), relatórios e integrações bancárias.
