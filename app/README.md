# app

Raiz do projeto Java (Maven, empacotamento `.war`). Esta pasta começa vazia: o projeto é criado na tarefa **T0.1**.

Ao criar, mantenha:

- `pom.xml` nesta pasta (o Makefile roda `mvn -f app/pom.xml`);
- `finalName` do war como `orcamento-familiar`  (endereço `http://localhost:8080/orcamento-familiar`);
- estrutura de pacotes de [`docs/03-especificacao-tecnica.md`](../docs/03-especificacao-tecnica.md#estrutura-de-pacotes-sugerida);
- `persistence.xml` apontando para o datasource JTA `java:jboss/datasources/OrcamentoFamiliarDS`, já criado no WildFly do Docker;
- `src/main/resources/frontend.properties` com as mensagens de [`docs/02-telas-e-regras.md`](../docs/02-telas-e-regras.md#4-mensagens).

Dependências do servidor (JSF, JPA/Hibernate, EJB, CDI) vêm do WildFly 13: declare-as com `<scope>provided</scope>` (por exemplo `javax:javaee-api:7.0`). PrimeFaces 5.2 vai dentro do war.
