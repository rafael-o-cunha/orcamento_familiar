# Orçamento Familiar — comandos do projeto (Linux/macOS). No Windows use make.bat com os mesmos nomes.
# Rode "make" ou "make help" para ver a lista.

ENV_FILE := infra/.env
-include $(ENV_FILE)

COMPOSE   := docker compose -f infra/docker-compose.yml --env-file $(ENV_FILE)
APP_DIR   := app
WAR_DIR   := $(APP_DIR)/target
DEPLOY    := infra/app/deployments
MVN_IMAGE := maven:3.8-openjdk-8
REPO      ?= $(shell git remote get-url origin 2>/dev/null | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$$##')

.DEFAULT_GOAL := help
.PHONY: help setup up down restart ps logs logs-app logs-db \
        db-up db-down db-sql db-reset \
        build build-docker test deploy redeploy deploy-local \
        clean clean-all labels issues issues-simular

help: ## Lista os comandos
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(firstword $(MAKEFILE_LIST)) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

# ---------------------------------------------------------------- ambiente
setup: ## Cria infra/.env a partir do exemplo (se não existir)
	@test -f $(ENV_FILE) || (cp infra/.env.example $(ENV_FILE) && echo "infra/.env criado")
	@mkdir -p $(DEPLOY)

up: setup ## Sobe Oracle + WildFly (constrói a imagem do WildFly na primeira vez)
	$(COMPOSE) up -d --build
	@echo "Aplicação: http://localhost:$(APP_PORT)/orcamento-familiar  |  Console: http://localhost:$(ADMIN_PORT)"

down: ## Para os containers (os dados do banco ficam)
	$(COMPOSE) down

restart: ## Reinicia os containers
	$(COMPOSE) restart

ps: ## Mostra o estado dos containers
	$(COMPOSE) ps

logs: ## Acompanha os logs de tudo
	$(COMPOSE) logs -f

logs-app: ## Acompanha os logs do WildFly
	$(COMPOSE) logs -f app

logs-db: ## Acompanha os logs do Oracle
	$(COMPOSE) logs -f oracle

# ---------------------------------------------------------------- banco
db-up: setup ## Sobe só o Oracle (para rodar o WildFly na máquina)
	$(COMPOSE) up -d oracle

db-down: ## Para só o Oracle
	$(COMPOSE) stop oracle

db-sql: ## Abre o SQL*Plus no schema da aplicação
	docker exec -it orcamento-familiar-oracle sqlplus $(DB_USER)/$(DB_PASSWORD)@//localhost:1521/$(DB_SERVICE)

db-reset: ## APAGA os dados do banco e roda de novo os scripts de infra/db/scripts
	$(COMPOSE) rm -sf oracle
	-docker volume rm $(COMPOSE_PROJECT_NAME)_oracle-dados
	$(COMPOSE) up -d oracle

# ---------------------------------------------------------------- aplicação
build: ## Gera o .war com o Maven da máquina (Java 8)
	mvn -f $(APP_DIR)/pom.xml clean package -DskipTests

build-docker: ## Gera o .war usando Maven + Java 8 em container (sem instalar nada)
	docker run --rm -v "$(CURDIR)/$(APP_DIR)":/app -v orcamento-familiar-m2:/root/.m2 -w /app $(MVN_IMAGE) mvn clean package -DskipTests

test: ## Roda os testes (mvn test)
	mvn -f $(APP_DIR)/pom.xml test

deploy: ## Publica o .war no WildFly do container
	@ls $(WAR_DIR)/*.war >/dev/null 2>&1 || (echo "Nenhum .war em $(WAR_DIR). Rode make build." && exit 1)
	cp $(WAR_DIR)/*.war $(DEPLOY)/orcamento-familiar.war
	@echo "Publicado. Acompanhe com: make logs-app"

redeploy: build deploy ## build + deploy

deploy-local: ## Publica o .war no WildFly instalado na máquina (WILDFLY_HOME no infra/.env)
	@test -n "$(WILDFLY_HOME)" || (echo "Defina WILDFLY_HOME no infra/.env" && exit 1)
	cp $(WAR_DIR)/*.war "$(WILDFLY_HOME)/standalone/deployments/orcamento-familiar.war"

# ---------------------------------------------------------------- limpeza
clean: ## Limpa o build e o .war publicado
	-mvn -q -f $(APP_DIR)/pom.xml clean
	rm -f $(DEPLOY)/*.war $(DEPLOY)/*.war.*

clean-all: clean ## Remove containers, volume do banco e imagem do WildFly
	$(COMPOSE) down -v --rmi local

# ---------------------------------------------------------------- GitHub
labels: ## Cria/atualiza as labels no GitHub (precisa do gh logado)
	GITHUB_TOKEN=$$(gh auth token) python3 .github/scripts/gerar_issues.py --repo $(REPO) --somente-labels

issues-simular: ## Mostra as labels, milestones e issues que seriam criados
	python3 .github/scripts/gerar_issues.py --dry-run

issues: ## Cria labels, milestones e issues a partir de docs/04-tarefas.md
	GITHUB_TOKEN=$$(gh auth token) python3 .github/scripts/gerar_issues.py --repo $(REPO)
