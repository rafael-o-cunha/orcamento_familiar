-- =============================================================================
-- Orçamento Familiar — 01_ddl.sql
-- Cria sequences, tabelas, chaves (PK, FK, UK), CHECKs, índices e comentários.
-- Alvo: Oracle Database 19c (também roda no Oracle XE 21 do Docker).
-- Dicionário de dados: docs/03-especificacao-tecnica.md, seção 4.
--
-- Regras deste script:
--   * Exclusão lógica: a aplicação não faz DELETE. Lançamento, anexo, tipo de
--     arquivo, parâmetros e usuário têm FL_ATIVO (S/N); excluir = FL_ATIVO 'N'.
--   * Nenhuma FK usa ON DELETE CASCADE nem ON DELETE SET NULL. Um DELETE manual
--     de registro com filhos é recusado pelo banco (ORA-02292).
--   * Arquivos anexados NÃO ficam no banco: TB_ANEXO guarda só os metadados
--     (UUID, nome original e caminho relativo). O arquivo fica em disco, em
--     <raiz de anexos>/<DS_CAMINHO>, e continua lá quando o anexo é inativado.
--   * Toda FK tem índice próprio (ou é a primeira coluna de uma UK/índice).
--   * Sequences com INCREMENT BY 1: mapear com
--     @SequenceGenerator(sequenceName = "SQ_...", allocationSize = 1).
-- =============================================================================

-- Rodando pelo Docker (os scripts rodam como SYS): aponta para o PDB e o schema.
-- Rodando conectado como ORCAMENTO no seu Oracle, remova estas duas linhas.
ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = ORCAMENTO;

-- -----------------------------------------------------------------------------
-- Sequences
-- -----------------------------------------------------------------------------
CREATE SEQUENCE SQ_USUARIO        START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SQ_LANCAMENTO     START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SQ_TIPO_ARQUIVO   START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SQ_ANEXO          START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SQ_LIMITE_USUARIO START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SQ_SALDO_CONTROLE START WITH 1 INCREMENT BY 1 NOCACHE;
-- TB_PARAMETRO e TB_PARAMETRO_ANEXO têm um único registro (ID = 1) e não usam sequence.

-- -----------------------------------------------------------------------------
-- TB_USUARIO — usuários do sistema (2 registros, criados no 02_carga.sql)
-- -----------------------------------------------------------------------------
CREATE TABLE TB_USUARIO (
    ID_USUARIO      NUMBER(19)     NOT NULL,
    NM_USUARIO      VARCHAR2(100)  NOT NULL,
    DS_LOGIN        VARCHAR2(50)   NOT NULL,
    DS_SENHA_HASH   VARCHAR2(128)  NOT NULL,
    FL_ATIVO        CHAR(1)        DEFAULT 'S' NOT NULL,
    DT_CRIACAO      TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_USUARIO          PRIMARY KEY (ID_USUARIO),
    CONSTRAINT UK_USUARIO_LOGIN    UNIQUE (DS_LOGIN),
    CONSTRAINT CK_USUARIO_FL_ATIVO CHECK (FL_ATIVO IN ('S', 'N'))
);

COMMENT ON TABLE  TB_USUARIO               IS 'Usuários do sistema. Nunca são excluídos: desativar com FL_ATIVO = N.';
COMMENT ON COLUMN TB_USUARIO.ID_USUARIO    IS 'Identificador (SQ_USUARIO)';
COMMENT ON COLUMN TB_USUARIO.NM_USUARIO    IS 'Nome exibido na tela';
COMMENT ON COLUMN TB_USUARIO.DS_LOGIN      IS 'Login de acesso';
COMMENT ON COLUMN TB_USUARIO.DS_SENHA_HASH IS 'Hash SHA-512 da senha em hexadecimal (128 caracteres)';
COMMENT ON COLUMN TB_USUARIO.FL_ATIVO      IS 'S = ativo, N = inativo';
COMMENT ON COLUMN TB_USUARIO.DT_CRIACAO    IS 'Data de criação';

-- -----------------------------------------------------------------------------
-- TB_LANCAMENTO — receitas e despesas
-- -----------------------------------------------------------------------------
CREATE TABLE TB_LANCAMENTO (
    ID_LANCAMENTO         NUMBER(19)     NOT NULL,
    ID_USUARIO            NUMBER(19)     NOT NULL,
    TP_NATUREZA           CHAR(1)        NOT NULL,
    TP_FORMA_PAGAMENTO    CHAR(1)        NOT NULL,
    TP_ESCOPO             CHAR(1)        NOT NULL,
    DS_TITULO             VARCHAR2(100)  NOT NULL,
    VL_LANCAMENTO         NUMBER(15,2)   NOT NULL,
    DS_DESCRICAO          VARCHAR2(500),
    DT_LANCAMENTO         DATE           NOT NULL,
    DT_EFETIVACAO         DATE           NOT NULL,
    NR_VERSAO             NUMBER(10)     DEFAULT 0 NOT NULL,
    FL_ATIVO              CHAR(1)        DEFAULT 'S' NOT NULL,
    DT_CRIACAO            TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    DT_ALTERACAO          TIMESTAMP,
    ID_USUARIO_ALTERACAO  NUMBER(19),
    CONSTRAINT PK_LANCAMENTO             PRIMARY KEY (ID_LANCAMENTO),
    CONSTRAINT FK_LANCAMENTO_USUARIO     FOREIGN KEY (ID_USUARIO)           REFERENCES TB_USUARIO (ID_USUARIO),
    CONSTRAINT FK_LANCAMENTO_USUARIO_ALT FOREIGN KEY (ID_USUARIO_ALTERACAO) REFERENCES TB_USUARIO (ID_USUARIO),
    CONSTRAINT CK_LANCAMENTO_NATUREZA    CHECK (TP_NATUREZA IN ('R', 'D')),
    CONSTRAINT CK_LANCAMENTO_FORMA       CHECK (TP_FORMA_PAGAMENTO IN ('D', 'C')),
    CONSTRAINT CK_LANCAMENTO_ESCOPO      CHECK (TP_ESCOPO IN ('C', 'P')),
    CONSTRAINT CK_LANCAMENTO_VALOR       CHECK (VL_LANCAMENTO > 0),
    CONSTRAINT CK_LANCAMENTO_EFETIVACAO  CHECK (DT_EFETIVACAO >= DT_LANCAMENTO),
    CONSTRAINT CK_LANCAMENTO_FL_ATIVO    CHECK (FL_ATIVO IN ('S', 'N'))
);

-- Grid (filtro por período) e saldos (por usuário, escopo e mês de efetivação).
-- IX_LANCAMENTO_USU_ESC_EFET começa por ID_USUARIO e também atende a FK_LANCAMENTO_USUARIO.
CREATE INDEX IX_LANCAMENTO_DATA         ON TB_LANCAMENTO (DT_LANCAMENTO);
CREATE INDEX IX_LANCAMENTO_USU_ESC_EFET ON TB_LANCAMENTO (ID_USUARIO, TP_ESCOPO, DT_EFETIVACAO);
CREATE INDEX IX_LANCAMENTO_USUARIO_ALT  ON TB_LANCAMENTO (ID_USUARIO_ALTERACAO);

COMMENT ON TABLE  TB_LANCAMENTO                      IS 'Receitas e despesas';
COMMENT ON COLUMN TB_LANCAMENTO.ID_LANCAMENTO        IS 'Identificador (SQ_LANCAMENTO)';
COMMENT ON COLUMN TB_LANCAMENTO.ID_USUARIO           IS 'Dono do lançamento (quem lançou)';
COMMENT ON COLUMN TB_LANCAMENTO.TP_NATUREZA          IS 'R = Receita, D = Despesa';
COMMENT ON COLUMN TB_LANCAMENTO.TP_FORMA_PAGAMENTO   IS 'D = Débito, C = Crédito';
COMMENT ON COLUMN TB_LANCAMENTO.TP_ESCOPO            IS 'C = Comum (residência), P = Pessoal';
COMMENT ON COLUMN TB_LANCAMENTO.DS_TITULO            IS 'Título curto';
COMMENT ON COLUMN TB_LANCAMENTO.VL_LANCAMENTO        IS 'Valor, sempre maior que zero; o sinal vem da natureza';
COMMENT ON COLUMN TB_LANCAMENTO.DS_DESCRICAO         IS 'Descrição livre';
COMMENT ON COLUMN TB_LANCAMENTO.DT_LANCAMENTO        IS 'Data da compra/recebimento (grid, filtros e regra do ano corrente)';
COMMENT ON COLUMN TB_LANCAMENTO.DT_EFETIVACAO        IS 'Data em que o dinheiro sai/entra: débito = DT_LANCAMENTO; crédito = vencimento da fatura';
COMMENT ON COLUMN TB_LANCAMENTO.NR_VERSAO            IS 'Versão para bloqueio otimista (@Version)';
COMMENT ON COLUMN TB_LANCAMENTO.FL_ATIVO             IS 'S = ativo, N = excluído (exclusão lógica; some da grid e dos saldos)';
COMMENT ON COLUMN TB_LANCAMENTO.DT_CRIACAO           IS 'Auditoria: inclusão';
COMMENT ON COLUMN TB_LANCAMENTO.DT_ALTERACAO         IS 'Auditoria: última alteração';
COMMENT ON COLUMN TB_LANCAMENTO.ID_USUARIO_ALTERACAO IS 'Auditoria: quem alterou por último';

-- -----------------------------------------------------------------------------
-- TB_TIPO_ARQUIVO — extensões de arquivo aceitas no upload (N registros)
--   Nesta versão a tela mostra três checkboxes (jpg, png, pdf) que ligam ou
--   desligam FL_ATIVO; a tabela já aceita extensões digitadas no futuro.
-- -----------------------------------------------------------------------------
CREATE TABLE TB_TIPO_ARQUIVO (
    ID_TIPO_ARQUIVO       NUMBER(19)     NOT NULL,
    DS_EXTENSAO           VARCHAR2(10)   NOT NULL,
    FL_ATIVO              CHAR(1)        DEFAULT 'S' NOT NULL,
    DT_ALTERACAO          TIMESTAMP,
    ID_USUARIO_ALTERACAO  NUMBER(19),
    CONSTRAINT PK_TIPO_ARQUIVO             PRIMARY KEY (ID_TIPO_ARQUIVO),
    CONSTRAINT UK_TIPO_ARQUIVO_EXTENSAO    UNIQUE (DS_EXTENSAO),
    CONSTRAINT FK_TIPO_ARQUIVO_USUARIO_ALT FOREIGN KEY (ID_USUARIO_ALTERACAO) REFERENCES TB_USUARIO (ID_USUARIO),
    CONSTRAINT CK_TIPO_ARQUIVO_EXTENSAO    CHECK (DS_EXTENSAO = LOWER(DS_EXTENSAO) AND INSTR(DS_EXTENSAO, '.') = 0),
    CONSTRAINT CK_TIPO_ARQUIVO_FL_ATIVO    CHECK (FL_ATIVO IN ('S', 'N'))
);

CREATE INDEX IX_TIPO_ARQUIVO_USUARIO_ALT ON TB_TIPO_ARQUIVO (ID_USUARIO_ALTERACAO);

COMMENT ON TABLE  TB_TIPO_ARQUIVO                      IS 'Extensões aceitas no upload; MIME type e preview são derivados da extensão no Java';
COMMENT ON COLUMN TB_TIPO_ARQUIVO.ID_TIPO_ARQUIVO      IS 'Identificador (SQ_TIPO_ARQUIVO)';
COMMENT ON COLUMN TB_TIPO_ARQUIVO.DS_EXTENSAO          IS 'Extensão em minúsculas, sem ponto (jpg, png, pdf)';
COMMENT ON COLUMN TB_TIPO_ARQUIVO.FL_ATIVO             IS 'S = aceita no upload, N = desmarcada/excluída (exclusão lógica)';
COMMENT ON COLUMN TB_TIPO_ARQUIVO.DT_ALTERACAO         IS 'Auditoria: última alteração';
COMMENT ON COLUMN TB_TIPO_ARQUIVO.ID_USUARIO_ALTERACAO IS 'Auditoria: quem alterou por último';

-- -----------------------------------------------------------------------------
-- TB_ANEXO — metadados dos arquivos anexados (o conteúdo fica em disco)
-- -----------------------------------------------------------------------------
CREATE TABLE TB_ANEXO (
    ID_ANEXO             NUMBER(19)     NOT NULL,
    ID_LANCAMENTO        NUMBER(19)     NOT NULL,
    ID_TIPO_ARQUIVO      NUMBER(19)     NOT NULL,
    CD_UUID              VARCHAR2(36)   NOT NULL,
    NM_ARQUIVO           VARCHAR2(255)  NOT NULL,
    DS_CAMINHO           VARCHAR2(255)  NOT NULL,
    DT_UPLOAD            TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    ID_USUARIO_UPLOAD    NUMBER(19)     NOT NULL,
    FL_ATIVO             CHAR(1)        DEFAULT 'S' NOT NULL,
    CONSTRAINT PK_ANEXO              PRIMARY KEY (ID_ANEXO),
    CONSTRAINT UK_ANEXO_UUID         UNIQUE (CD_UUID),
    CONSTRAINT FK_ANEXO_LANCAMENTO   FOREIGN KEY (ID_LANCAMENTO)     REFERENCES TB_LANCAMENTO (ID_LANCAMENTO),
    CONSTRAINT FK_ANEXO_TIPO_ARQUIVO FOREIGN KEY (ID_TIPO_ARQUIVO)   REFERENCES TB_TIPO_ARQUIVO (ID_TIPO_ARQUIVO),
    CONSTRAINT FK_ANEXO_USUARIO      FOREIGN KEY (ID_USUARIO_UPLOAD) REFERENCES TB_USUARIO (ID_USUARIO),
    CONSTRAINT CK_ANEXO_UUID         CHECK (REGEXP_LIKE(CD_UUID, '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')),
    CONSTRAINT CK_ANEXO_CAMINHO      CHECK (SUBSTR(DS_CAMINHO, 1, 1) <> '/' AND INSTR(DS_CAMINHO, '..') = 0),
    CONSTRAINT CK_ANEXO_FL_ATIVO     CHECK (FL_ATIVO IN ('S', 'N'))
);

CREATE INDEX IX_ANEXO_LANCAMENTO   ON TB_ANEXO (ID_LANCAMENTO);
CREATE INDEX IX_ANEXO_TIPO_ARQUIVO ON TB_ANEXO (ID_TIPO_ARQUIVO);
CREATE INDEX IX_ANEXO_USUARIO      ON TB_ANEXO (ID_USUARIO_UPLOAD);

COMMENT ON TABLE  TB_ANEXO                   IS 'Metadados dos anexos; arquivo físico em <raiz de anexos>/<DS_CAMINHO>';
COMMENT ON COLUMN TB_ANEXO.ID_ANEXO          IS 'Identificador (SQ_ANEXO)';
COMMENT ON COLUMN TB_ANEXO.ID_LANCAMENTO     IS 'Lançamento dono do anexo';
COMMENT ON COLUMN TB_ANEXO.ID_TIPO_ARQUIVO   IS 'Extensão do arquivo (dela vêm o MIME type e o preview)';
COMMENT ON COLUMN TB_ANEXO.CD_UUID           IS 'UUID gerado no upload (java.util.UUID); compõe o nome do arquivo em disco';
COMMENT ON COLUMN TB_ANEXO.NM_ARQUIVO        IS 'Nome original enviado pelo usuário; usado no download';
COMMENT ON COLUMN TB_ANEXO.DS_CAMINHO        IS 'Caminho relativo à raiz de anexos, com o nome em disco: AAAA/MM/<uuid>.<ext>';
COMMENT ON COLUMN TB_ANEXO.DT_UPLOAD         IS 'Data do upload';
COMMENT ON COLUMN TB_ANEXO.ID_USUARIO_UPLOAD IS 'Quem anexou';
COMMENT ON COLUMN TB_ANEXO.FL_ATIVO          IS 'S = ativo, N = removido (exclusão lógica; o arquivo continua em disco)';

-- -----------------------------------------------------------------------------
-- TB_PARAMETRO — limites mínimos de saldo (registro único, ID = 1)
-- -----------------------------------------------------------------------------
CREATE TABLE TB_PARAMETRO (
    ID_PARAMETRO              NUMBER(19)     NOT NULL,
    VL_LIMITE_MINIMO_COMUM    NUMBER(15,2)   NOT NULL,
    VL_LIMITE_MINIMO_PESSOAL  NUMBER(15,2)   NOT NULL,
    NR_VERSAO                 NUMBER(10)     DEFAULT 0 NOT NULL,
    FL_ATIVO                  CHAR(1)        DEFAULT 'S' NOT NULL,
    DT_ALTERACAO              TIMESTAMP,
    ID_USUARIO_ALTERACAO      NUMBER(19),
    CONSTRAINT PK_PARAMETRO             PRIMARY KEY (ID_PARAMETRO),
    CONSTRAINT FK_PARAMETRO_USUARIO_ALT FOREIGN KEY (ID_USUARIO_ALTERACAO) REFERENCES TB_USUARIO (ID_USUARIO),
    CONSTRAINT CK_PARAMETRO_UNICO       CHECK (ID_PARAMETRO = 1),
    CONSTRAINT CK_PARAMETRO_FL_ATIVO    CHECK (FL_ATIVO IN ('S', 'N'))
);

CREATE INDEX IX_PARAMETRO_USUARIO_ALT ON TB_PARAMETRO (ID_USUARIO_ALTERACAO);

COMMENT ON TABLE  TB_PARAMETRO                          IS 'Limites mínimos de saldo; registro único com ID = 1';
COMMENT ON COLUMN TB_PARAMETRO.ID_PARAMETRO             IS 'Sempre 1';
COMMENT ON COLUMN TB_PARAMETRO.VL_LIMITE_MINIMO_COMUM   IS 'Menor saldo comum permitido após uma despesa (ex.: 0,00 ou -500,00)';
COMMENT ON COLUMN TB_PARAMETRO.VL_LIMITE_MINIMO_PESSOAL IS 'Menor saldo pessoal disponível permitido após uma despesa';
COMMENT ON COLUMN TB_PARAMETRO.NR_VERSAO                IS 'Versão para bloqueio otimista (@Version)';
COMMENT ON COLUMN TB_PARAMETRO.FL_ATIVO                 IS 'Padrão de exclusão lógica; o registro único fica sempre S';
COMMENT ON COLUMN TB_PARAMETRO.DT_ALTERACAO             IS 'Auditoria: última alteração';
COMMENT ON COLUMN TB_PARAMETRO.ID_USUARIO_ALTERACAO     IS 'Auditoria: quem alterou por último';

-- -----------------------------------------------------------------------------
-- TB_PARAMETRO_ANEXO — regras de upload (registro único, ID = 1)
-- -----------------------------------------------------------------------------
CREATE TABLE TB_PARAMETRO_ANEXO (
    ID_PARAMETRO_ANEXO        NUMBER(19)     NOT NULL,
    QT_MAX_ANEXOS             NUMBER(3)      NOT NULL,
    NR_TAMANHO_MAX_KB         NUMBER(8)      NOT NULL,
    FL_ANEXO_OBRIG_DESPESA    CHAR(1)        DEFAULT 'N' NOT NULL,
    NR_VERSAO                 NUMBER(10)     DEFAULT 0 NOT NULL,
    FL_ATIVO                  CHAR(1)        DEFAULT 'S' NOT NULL,
    DT_ALTERACAO              TIMESTAMP,
    ID_USUARIO_ALTERACAO      NUMBER(19),
    CONSTRAINT PK_PARAMETRO_ANEXO             PRIMARY KEY (ID_PARAMETRO_ANEXO),
    CONSTRAINT FK_PARAMETRO_ANEXO_USUARIO_ALT FOREIGN KEY (ID_USUARIO_ALTERACAO) REFERENCES TB_USUARIO (ID_USUARIO),
    CONSTRAINT CK_PARAMETRO_ANEXO_UNICO       CHECK (ID_PARAMETRO_ANEXO = 1),
    CONSTRAINT CK_PARAMETRO_ANEXO_QT          CHECK (QT_MAX_ANEXOS >= 1),
    CONSTRAINT CK_PARAMETRO_ANEXO_TAMANHO     CHECK (NR_TAMANHO_MAX_KB > 0),
    CONSTRAINT CK_PARAMETRO_ANEXO_OBRIG       CHECK (FL_ANEXO_OBRIG_DESPESA IN ('S', 'N')),
    CONSTRAINT CK_PARAMETRO_ANEXO_FL_ATIVO    CHECK (FL_ATIVO IN ('S', 'N'))
);

CREATE INDEX IX_PARAMETRO_ANEXO_USUARIO_ALT ON TB_PARAMETRO_ANEXO (ID_USUARIO_ALTERACAO);

COMMENT ON TABLE  TB_PARAMETRO_ANEXO                        IS 'Regras de upload; registro único com ID = 1. As extensões ficam em TB_TIPO_ARQUIVO';
COMMENT ON COLUMN TB_PARAMETRO_ANEXO.ID_PARAMETRO_ANEXO     IS 'Sempre 1';
COMMENT ON COLUMN TB_PARAMETRO_ANEXO.QT_MAX_ANEXOS          IS 'Máximo de anexos ativos por lançamento';
COMMENT ON COLUMN TB_PARAMETRO_ANEXO.NR_TAMANHO_MAX_KB      IS 'Tamanho máximo por arquivo, em KB';
COMMENT ON COLUMN TB_PARAMETRO_ANEXO.FL_ANEXO_OBRIG_DESPESA IS 'S = despesa exige ao menos um anexo ativo';
COMMENT ON COLUMN TB_PARAMETRO_ANEXO.NR_VERSAO              IS 'Versão para bloqueio otimista (@Version); incrementada também ao marcar/desmarcar tipos de arquivo';
COMMENT ON COLUMN TB_PARAMETRO_ANEXO.FL_ATIVO               IS 'Padrão de exclusão lógica; o registro único fica sempre S';
COMMENT ON COLUMN TB_PARAMETRO_ANEXO.DT_ALTERACAO           IS 'Auditoria: última alteração';
COMMENT ON COLUMN TB_PARAMETRO_ANEXO.ID_USUARIO_ALTERACAO   IS 'Auditoria: quem alterou por último';

-- -----------------------------------------------------------------------------
-- TB_LIMITE_USUARIO — histórico do limite de crédito pessoal por usuário
-- -----------------------------------------------------------------------------
CREATE TABLE TB_LIMITE_USUARIO (
    ID_LIMITE_USUARIO     NUMBER(19)     NOT NULL,
    ID_USUARIO            NUMBER(19)     NOT NULL,
    NR_ANO_MES_INICIO     NUMBER(6)      NOT NULL,
    VL_LIMITE_PESSOAL     NUMBER(15,2)   NOT NULL,
    NR_VERSAO             NUMBER(10)     DEFAULT 0 NOT NULL,
    DT_ALTERACAO          TIMESTAMP,
    ID_USUARIO_ALTERACAO  NUMBER(19),
    CONSTRAINT PK_LIMITE_USUARIO             PRIMARY KEY (ID_LIMITE_USUARIO),
    CONSTRAINT UK_LIMITE_USUARIO_VIGENCIA    UNIQUE (ID_USUARIO, NR_ANO_MES_INICIO),
    CONSTRAINT FK_LIMITE_USUARIO_USUARIO     FOREIGN KEY (ID_USUARIO)           REFERENCES TB_USUARIO (ID_USUARIO),
    CONSTRAINT FK_LIMITE_USUARIO_USUARIO_ALT FOREIGN KEY (ID_USUARIO_ALTERACAO) REFERENCES TB_USUARIO (ID_USUARIO),
    CONSTRAINT CK_LIMITE_USUARIO_ANO_MES     CHECK (MOD(NR_ANO_MES_INICIO, 100) BETWEEN 1 AND 12),
    CONSTRAINT CK_LIMITE_USUARIO_VALOR       CHECK (VL_LIMITE_PESSOAL >= 0)
);

-- UK_LIMITE_USUARIO_VIGENCIA começa por ID_USUARIO e atende a FK_LIMITE_USUARIO_USUARIO.
CREATE INDEX IX_LIMITE_USUARIO_USUARIO_ALT ON TB_LIMITE_USUARIO (ID_USUARIO_ALTERACAO);

COMMENT ON TABLE  TB_LIMITE_USUARIO                      IS 'Histórico do limite pessoal: o limite do mês M é o registro com o maior NR_ANO_MES_INICIO <= M';
COMMENT ON COLUMN TB_LIMITE_USUARIO.ID_LIMITE_USUARIO    IS 'Identificador (SQ_LIMITE_USUARIO)';
COMMENT ON COLUMN TB_LIMITE_USUARIO.ID_USUARIO           IS 'Usuário dono do limite';
COMMENT ON COLUMN TB_LIMITE_USUARIO.NR_ANO_MES_INICIO    IS 'AAAAMM a partir do qual o limite vale';
COMMENT ON COLUMN TB_LIMITE_USUARIO.VL_LIMITE_PESSOAL    IS 'Limite mensal (padrão 1000,00)';
COMMENT ON COLUMN TB_LIMITE_USUARIO.NR_VERSAO            IS 'Versão para bloqueio otimista (@Version)';
COMMENT ON COLUMN TB_LIMITE_USUARIO.DT_ALTERACAO         IS 'Auditoria: última alteração';
COMMENT ON COLUMN TB_LIMITE_USUARIO.ID_USUARIO_ALTERACAO IS 'Auditoria: quem alterou por último';

-- -----------------------------------------------------------------------------
-- TB_SALDO_CONTROLE — ponto de controle de concorrência e saldo consolidado
--   Existe para evitar write skew: dois INSERTs em TB_LANCAMENTO nunca entram
--   em conflito no @Version, então toda gravação de lançamento faz UPDATE na
--   linha comum (e na pessoal do mês), que vira o ponto de conflito.
--   Linha comum:   TP_ESCOPO = 'C', ID_USUARIO e NR_ANO_MES nulos (saldo acumulado).
--   Linha pessoal: TP_ESCOPO = 'P', uma por usuário e mês de efetivação.
-- -----------------------------------------------------------------------------
CREATE TABLE TB_SALDO_CONTROLE (
    ID_SALDO_CONTROLE  NUMBER(19)     NOT NULL,
    TP_ESCOPO          CHAR(1)        NOT NULL,
    ID_USUARIO         NUMBER(19),
    NR_ANO_MES         NUMBER(6),
    VL_SALDO           NUMBER(15,2)   DEFAULT 0 NOT NULL,
    NR_VERSAO          NUMBER(10)     DEFAULT 0 NOT NULL,
    DT_ATUALIZACAO     TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_SALDO_CONTROLE         PRIMARY KEY (ID_SALDO_CONTROLE),
    CONSTRAINT UK_SALDO_CONTROLE         UNIQUE (TP_ESCOPO, ID_USUARIO, NR_ANO_MES),
    CONSTRAINT FK_SALDO_CONTROLE_USUARIO FOREIGN KEY (ID_USUARIO) REFERENCES TB_USUARIO (ID_USUARIO),
    CONSTRAINT CK_SALDO_CONTROLE_ESCOPO  CHECK (
        (TP_ESCOPO = 'C' AND ID_USUARIO IS NULL     AND NR_ANO_MES IS NULL) OR
        (TP_ESCOPO = 'P' AND ID_USUARIO IS NOT NULL AND NR_ANO_MES IS NOT NULL)
    ),
    CONSTRAINT CK_SALDO_CONTROLE_ANO_MES CHECK (NR_ANO_MES IS NULL OR MOD(NR_ANO_MES, 100) BETWEEN 1 AND 12)
);

CREATE INDEX IX_SALDO_CONTROLE_USUARIO ON TB_SALDO_CONTROLE (ID_USUARIO);

COMMENT ON TABLE  TB_SALDO_CONTROLE                   IS 'Saldo consolidado protegido por bloqueio otimista: uma linha comum e uma pessoal por usuário/mês';
COMMENT ON COLUMN TB_SALDO_CONTROLE.ID_SALDO_CONTROLE IS 'Identificador (SQ_SALDO_CONTROLE)';
COMMENT ON COLUMN TB_SALDO_CONTROLE.TP_ESCOPO         IS 'C = Comum, P = Pessoal';
COMMENT ON COLUMN TB_SALDO_CONTROLE.ID_USUARIO        IS 'Usuário da linha pessoal; nulo na linha comum';
COMMENT ON COLUMN TB_SALDO_CONTROLE.NR_ANO_MES        IS 'AAAAMM do mês de efetivação; nulo na linha comum';
COMMENT ON COLUMN TB_SALDO_CONTROLE.VL_SALDO          IS 'Comum: saldo acumulado. Pessoal: valor consumido no mês';
COMMENT ON COLUMN TB_SALDO_CONTROLE.NR_VERSAO         IS 'Versão para bloqueio otimista (@Version), incrementada a cada UPDATE';
COMMENT ON COLUMN TB_SALDO_CONTROLE.DT_ATUALIZACAO    IS 'Última atualização';
