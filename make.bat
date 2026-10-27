@echo off
rem Orçamento Familiar - espelho do Makefile para Windows. Uso: make.bat <comando>
rem Os nomes dos comandos sao os mesmos do Makefile. Rode "make.bat help" para a lista.
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

set "ENV_FILE=infra\.env"
set "APP_DIR=app"
set "WAR_DIR=app\target"
set "DEPLOY=infra\app\deployments"
set "MVN_IMAGE=maven:3.8-openjdk-8"

if exist "%ENV_FILE%" (
  for /f "usebackq eol=# tokens=1,* delims==" %%a in ("%ENV_FILE%") do set "%%a=%%b"
)
set "COMPOSE=docker compose -f infra\docker-compose.yml --env-file %ENV_FILE%"

set "CMD=%~1"
if "%CMD%"=="" set "CMD=help"
findstr /r /c:"^:%CMD%$" "%~f0" >nul 2>&1 || (echo Comando desconhecido: %CMD% & goto help)
goto %CMD%

:help
echo   setup            Cria infra\.env a partir do exemplo (se nao existir)
echo   up               Sobe Oracle + WildFly
echo   down             Para os containers (os dados do banco ficam)
echo   restart          Reinicia os containers
echo   ps               Mostra o estado dos containers
echo   logs             Acompanha os logs de tudo
echo   logs-app         Acompanha os logs do WildFly
echo   logs-db          Acompanha os logs do Oracle
echo   db-up            Sobe so o Oracle
echo   db-down          Para so o Oracle
echo   db-sql           Abre o SQL*Plus no schema da aplicacao
echo   db-reset         APAGA os dados do banco e roda de novo os scripts
echo   build            Gera o .war com o Maven da maquina (Java 8)
echo   build-docker     Gera o .war usando Maven + Java 8 em container
echo   test             Roda os testes (mvn test)
echo   deploy           Publica o .war no WildFly do container
echo   redeploy         build + deploy
echo   deploy-local     Publica o .war no WildFly da maquina (WILDFLY_HOME)
echo   clean            Limpa o build e o .war publicado
echo   clean-all        Remove containers, volume do banco e imagem do WildFly
echo   labels           Cria/atualiza as labels no GitHub (gh logado)
echo   issues-simular   Mostra o que seria criado no GitHub
echo   issues           Cria labels, milestones e issues no GitHub
goto :eof

:setup
if not exist "%ENV_FILE%" (copy infra\.env.example "%ENV_FILE%" >nul & echo infra\.env criado)
if not exist "%DEPLOY%" mkdir "%DEPLOY%"
goto :eof

:up
call :setup
for /f "usebackq eol=# tokens=1,* delims==" %%a in ("%ENV_FILE%") do set "%%a=%%b"
%COMPOSE% up -d --build
echo Aplicacao: http://localhost:%APP_PORT%/orcamento-familiar  ^|  Console: http://localhost:%ADMIN_PORT%
goto :eof

:down
%COMPOSE% down
goto :eof

:restart
%COMPOSE% restart
goto :eof

:ps
%COMPOSE% ps
goto :eof

:logs
%COMPOSE% logs -f
goto :eof

:logs-app
%COMPOSE% logs -f app
goto :eof

:logs-db
%COMPOSE% logs -f oracle
goto :eof

:db-up
call :setup
%COMPOSE% up -d oracle
goto :eof

:db-down
%COMPOSE% stop oracle
goto :eof

:db-sql
docker exec -it orcamento-familiar-oracle sqlplus %DB_USER%/%DB_PASSWORD%@//localhost:1521/%DB_SERVICE%
goto :eof

:db-reset
%COMPOSE% rm -sf oracle
docker volume rm %COMPOSE_PROJECT_NAME%_oracle-dados
%COMPOSE% up -d oracle
goto :eof

:build
call mvn -f %APP_DIR%\pom.xml clean package -DskipTests
goto :eof

:build-docker
docker run --rm -v "%CD%\%APP_DIR%":/app -v orcamento-familiar-m2:/root/.m2 -w /app %MVN_IMAGE% mvn clean package -DskipTests
goto :eof

:test
call mvn -f %APP_DIR%\pom.xml test
goto :eof

:deploy
if not exist "%WAR_DIR%\*.war" (echo Nenhum .war em %WAR_DIR%. Rode make.bat build. & exit /b 1)
for %%w in ("%WAR_DIR%\*.war") do copy /y "%%w" "%DEPLOY%\orcamento-familiar.war" >nul
echo Publicado. Acompanhe com: make.bat logs-app
goto :eof

:redeploy
call :build
call :deploy
goto :eof

:deploy-local
if "%WILDFLY_HOME%"=="" (echo Defina WILDFLY_HOME no infra\.env & exit /b 1)
for %%w in ("%WAR_DIR%\*.war") do copy /y "%%w" "%WILDFLY_HOME%\standalone\deployments\orcamento-familiar.war" >nul
goto :eof

:clean
call mvn -q -f %APP_DIR%\pom.xml clean
del /q "%DEPLOY%\*.war" "%DEPLOY%\*.war.*" 2>nul
goto :eof

:clean-all
call :clean
%COMPOSE% down -v --rmi local
goto :eof

:repo
if not "%REPO%"=="" goto :eof
for /f "delims=" %%r in ('git remote get-url origin') do set "REPO=%%r"
set "REPO=!REPO:https://github.com/=!"
set "REPO=!REPO:git@github.com:=!"
set "REPO=!REPO:.git=!"
goto :eof

:token
for /f "delims=" %%t in ('gh auth token') do set "GITHUB_TOKEN=%%t"
goto :eof

:labels
call :repo
call :token
python .github\scripts\gerar_issues.py --repo %REPO% --somente-labels
goto :eof

:issues-simular
python .github\scripts\gerar_issues.py --dry-run
goto :eof

:issues
call :repo
call :token
python .github\scripts\gerar_issues.py --repo %REPO%
goto :eof
