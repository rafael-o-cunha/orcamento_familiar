# WildFly 13 (Java 8) com o driver Oracle e o datasource da aplicação já configurados.
FROM jboss/wildfly:13.0.0.Final

ARG WILDFLY_ADMIN_USER=admin
ARG WILDFLY_ADMIN_PASSWORD=admin123
ARG OJDBC_VERSION=19.24.0.0

# Driver JDBC do Oracle (Maven Central).
RUN curl -fsSL -o /tmp/ojdbc8.jar \
      "https://repo1.maven.org/maven2/com/oracle/database/jdbc/ojdbc8/${OJDBC_VERSION}/ojdbc8-${OJDBC_VERSION}.jar"

# Módulo do driver + datasource java:jboss/datasources/OrcamentoFamiliarDS.
# URL, usuário e senha são lidos das variáveis de ambiente quando o servidor sobe.
COPY configurar-datasource.cli /tmp/configurar-datasource.cli
RUN /opt/jboss/wildfly/bin/jboss-cli.sh --file=/tmp/configurar-datasource.cli \
 && rm -rf /opt/jboss/wildfly/standalone/configuration/standalone_xml_history/current \
 && rm -f /tmp/ojdbc8.jar

# Usuário do console de administração (http://localhost:9990).
RUN /opt/jboss/wildfly/bin/add-user.sh -u "${WILDFLY_ADMIN_USER}" -p "${WILDFLY_ADMIN_PASSWORD}" --silent

EXPOSE 8080 9990 8787

# -b/-bmanagement: aceita conexões de fora do container; --debug: depuração remota na 8787.
CMD ["/opt/jboss/wildfly/bin/standalone.sh", "-b", "0.0.0.0", "-bmanagement", "0.0.0.0", "--debug", "*:8787"]
