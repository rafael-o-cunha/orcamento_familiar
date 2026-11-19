-- =============================================================================
-- Orçamento Familiar — 01_ddl.sql
-- Cria sequences, tabelas, chaves (PK, FK, UK), CHECKs, índices e comentários.
-- Alvo: Oracle Database 19c (também roda no Oracle XE 21 do Docker).
-- Dicionário de dados: docs/03-especificacao-tecnica.md, seção 4.
--
-- Regras deste script:
--   * Nenhuma FK usa ON DELETE CASCADE nem ON DELETE SET NULL. Excluir um
--     registro que ainda tem filhos é recusado pelo banco (ORA-02292); a ordem
--     de exclusão é responsabilidade do Business.
--   * Arquivos anexados NÃO ficam no banco: TB_ANEXO guarda só os metadados
--     (UUID, nome, caminho relativo, extensão, tamanho, hash). O arquivo fica em
--     disco, em <raiz de anexos>/<DS_CAMINHO>/<CD_UUID>.<DS_EXTENSAO>.
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
-- TB_PARAMETRO tem um único registro (ID = 1) e não usa sequence.

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
    CONSTRAINT CK_LANCAMENTO_EFETIVACAO  CHECK (DT_EFETIVACAO >= DT_LANCAMENTO)
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
COMMENT ON COLUMN TB_LANCAMENTO.DT_CRIACAO           IS 'Auditoria: inclusão';
COMMENT ON COLUMN TB_LANCAMENTO.DT_ALTERACAO         IS 'Auditoria: última alteração';
COMMENT ON COLUMN TB_LANCAMENTO.ID_USUARIO_ALTERACAO IS 'Auditoria: quem alterou por último';

-- -----------------------------------------------------------------------------
-- TB_TIPO_ARQUIVO — tipos de arquivo conhecidos e se o upload é permitido
-- -----------------------------------------------------------------------------
CREATE TABLE TB_TIPO_ARQUIVO (
    ID_TIPO_ARQUIVO       NUMBER(19)     NOT NULL,
    DS_EXTENSAO           VARCHAR2(10)   NOT NULL,
    DS_CONTENT_TYPE       VARCHAR2(100)  NOT NULL,
    TP_PREVIEW            CHAR(1)        NOT NULL,
    FL_PERMITIDO          CHAR(1)        DEFAULT 'S' NOT NULL,
    DT_ALTERACAO          TIMESTAMP,
    ID_USUARIO_ALTERACAO  NUMBER(19),
    CONSTRAINT PK_TIPO_ARQUIVO             PRIMARY KEY (ID_TIPO_ARQUIVO),
    CONSTRAINT UK_TIPO_ARQUIVO_EXTENSAO    UNIQUE (DS_EXTENSAO),
    CONSTRAINT FK_TIPO_ARQUIVO_USUARIO_ALT FOREIGN KEY (ID_USUARIO_ALTERACAO) REFERENCES TB_USUARIO (ID_USUARIO),
    CONSTRAINT CK_TIPO_ARQUIVO_EXTENSAO    CHECK (DS_EXTENSAO = LOWER(DS_EXTENSAO) AND INSTR(DS_EXTENSAO, '.') = 0),
    CONSTRAINT CK_TIPO_ARQUIVO_PREVIEW     CHECK (TP_PREVIEW IN ('I', 'P', 'N')),
    CONSTRAINT CK_TIPO_ARQUIVO_PERMITIDO   CHECK (FL_PERMITIDO IN ('S', 'N'))
);

CREATE INDEX IX_TIPO_ARQUIVO_USUARIO_ALT ON TB_TIPO_ARQUIVO (ID_USUARIO_ALTERACAO);

COMMENT ON TABLE  TB_TIPO_ARQUIVO                      IS 'Domínio dos tipos de arquivo; a parametrização liga/desliga FL_PERMITIDO';
COMMENT ON COLUMN TB_TIPO_ARQUIVO.ID_TIPO_ARQUIVO      IS 'Identificador (SQ_TIPO_ARQUIVO)';
COMMENT ON COLUMN TB_TIPO_ARQUIVO.DS_EXTENSAO          IS 'Extensão em minúsculas, sem ponto (jpg, png, pdf)';
COMMENT ON COLUMN TB_TIPO_ARQUIVO.DS_CONTENT_TYPE      IS 'MIME type esperado (image/jpeg, application/pdf)';
COMMENT ON COLUMN TB_TIPO_ARQUIVO.TP_PREVIEW           IS 'Preview na consulta: I = imagem, P = PDF, N = sem preview';
COMMENT ON COLUMN TB_TIPO_ARQUIVO.FL_PERMITIDO         IS 'S = aceito no upload, N = recusado';
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
    DS_EXTENSAO          VARCHAR2(10)   NOT NULL,
    DS_CONTENT_TYPE      VARCHAR2(100)  NOT NULL,
    NR_TAMANHO_BYTES     NUMBER(12)     NOT NULL,
    DS_HASH_SHA256       CHAR(64)       NOT NULL,
    DT_UPLOAD            TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    ID_USUARIO_UPLOAD    NUMBER(19)     NOT NULL,
    CONSTRAINT PK_ANEXO              PRIMARY KEY (ID_ANEXO),
    CONSTRAINT UK_ANEXO_UUID         UNIQUE (CD_UUID),
    CONSTRAINT FK_ANEXO_LANCAMENTO   FOREIGN KEY (ID_LANCAMENTO)     REFERENCES TB_LANCAMENTO (ID_LANCAMENTO),
    CONSTRAINT FK_ANEXO_TIPO_ARQUIVO FOREIGN KEY (ID_TIPO_ARQUIVO)   REFERENCES TB_TIPO_ARQUIVO (ID_TIPO_ARQUIVO),
    CONSTRAINT FK_ANEXO_USUARIO      FOREIGN KEY (ID_USUARIO_UPLOAD) REFERENCES TB_USUARIO (ID_USUARIO),
    CONSTRAINT CK_ANEXO_UUID         CHECK (REGEXP_LIKE(CD_UUID, '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')),
    CONSTRAINT CK_ANEXO_CAMINHO      CHECK (SUBSTR(DS_CAMINHO, 1, 1) <> '/' AND INSTR(DS_CAMINHO, '..') = 0),
    CONSTRAINT CK_ANEXO_TAMANHO      CHECK (NR_TAMANHO_BYTES > 0)
);

CREATE INDEX IX_ANEXO_LANCAMENTO   ON TB_ANEXO (ID_LANCAMENTO);
CREATE INDEX IX_ANEXO_TIPO_ARQUIVO ON TB_ANEXO (ID_TIPO_ARQUIVO);
CREATE INDEX IX_ANEXO_USUARIO      ON TB_ANEXO (ID_USUARIO_UPLOAD);

COMMENT ON TABLE  TB_ANEXO                   IS 'Metadados dos anexos; arquivo físico em <raiz>/<DS_CAMINHO>/<CD_UUID>.<DS_EXTENSAO>';
COMMENT ON COLUMN TB_ANEXO.ID_ANEXO          IS 'Identificador (SQ_ANEXO)';
COMMENT ON COLUMN TB_ANEXO.ID_LANCAMENTO     IS 'Lançamento dono do anexo (sem cascade: o Business exclui os anexos antes do lançamento)';
COMMENT ON COLUMN TB_ANEXO.ID_TIPO_ARQUIVO   IS 'Tipo do arquivo, validado no upload';
COMMENT ON COLUMN TB_ANEXO.CD_UUID           IS 'UUID gerado no upload (java.util.UUID); é o nome do arquivo em disco';
COMMENT ON COLUMN TB_ANEXO.NM_ARQUIVO        IS 'Nome original enviado pelo usuário; usado no download';
COMMENT ON COLUMN TB_ANEXO.DS_CAMINHO        IS 'Pasta relativa à raiz de anexos, no formato AAAA/MM (ex.: 2026/11)';
COMMENT ON COLUMN TB_ANEXO.DS_EXTENSAO       IS 'Extensão gravada em disco, em minúsculas, sem ponto';
COMMENT ON COLUMN TB_ANEXO.DS_CONTENT_TYPE   IS 'MIME type detectado no upload; usado no download e no preview';
COMMENT ON COLUMN TB_ANEXO.NR_TAMANHO_BYTES  IS 'Tamanho do arquivo em bytes';
COMMENT ON COLUMN TB_ANEXO.DS_HASH_SHA256    IS 'SHA-256 do conteúdo em hexadecimal; conferido no download';
COMMENT ON COLUMN TB_ANEXO.DT_UPLOAD         IS 'Data do upload';
COMMENT ON COLUMN TB_ANEXO.ID_USUARIO_UPLOAD IS 'Quem anexou';

-- -----------------------------------------------------------------------------
-- TB_PARAMETRO — parametrização geral (registro único, ID = 1)
-- -----------------------------------------------------------------------------
CREATE TABLE TB_PARAMETRO (
    ID_PARAMETRO              NUMBER(19)     NOT NULL,
    VL_LIMITE_MINIMO_COMUM    NUMBER(15,2)   NOT NULL,
    VL_LIMITE_MINIMO_PESSOAL  NUMBER(15,2)   NOT NULL,
    QT_MAX_ANEXOS             NUMBER(3)      NOT NULL,
    NR_TAMANHO_MAX_KB         NUMBER(8)      NOT NULL,
    FL_ANEXO_OBRIG_DESPESA    CHAR(1)        DEFAULT 'N' NOT NULL,
    NR_VERSAO                 NUMBER(10)     DEFAULT 0 NOT NULL,
    DT_ALTERACAO              TIMESTAMP,
    ID_USUARIO_ALTERACAO      NUMBER(19),
    CONSTRAINT PK_PARAMETRO             PRIMARY KEY (ID_PARAMETRO),
    CONSTRAINT FK_PARAMETRO_USUARIO_ALT FOREIGN KEY (ID_USUARIO_ALTERACAO) REFERENCES TB_USUARIO (ID_USUARIO),
    CONSTRAINT CK_PARAMETRO_UNICO       CHECK (ID_PARAMETRO = 1),
    CONSTRAINT CK_PARAMETRO_QT_ANEXOS   CHECK (QT_MAX_ANEXOS >= 1),
    CONSTRAINT CK_PARAMETRO_TAMANHO     CHECK (NR_TAMANHO_MAX_KB > 0),
    CONSTRAINT CK_PARAMETRO_ANEXO_OBRIG CHECK (FL_ANEXO_OBRIG_DESPESA IN ('S', 'N'))
);

CREATE INDEX IX_PARAMETRO_USUARIO_ALT ON TB_PARAMETRO (ID_USUARIO_ALTERACAO);

COMMENT ON TABLE  TB_PARAMETRO                          IS 'Parametrização geral; registro único com ID = 1. Tipos de arquivo ficam em TB_TIPO_ARQUIVO';
COMMENT ON COLUMN TB_PARAMETRO.ID_PARAMETRO             IS 'Sempre 1';
COMMENT ON COLUMN TB_PARAMETRO.VL_LIMITE_MINIMO_COMUM   IS 'Menor saldo comum permitido após uma despesa (ex.: 0,00 ou -500,00)';
COMMENT ON COLUMN TB_PARAMETRO.VL_LIMITE_MINIMO_PESSOAL IS 'Menor saldo pessoal disponível permitido após uma despesa';
COMMENT ON COLUMN TB_PARAMETRO.QT_MAX_ANEXOS            IS 'Máximo de anexos por lançamento';
COMMENT ON COLUMN TB_PARAMETRO.NR_TAMANHO_MAX_KB        IS 'Tamanho máximo por arquivo, em KB';
COMMENT ON COLUMN TB_PARAMETRO.FL_ANEXO_OBRIG_DESPESA   IS 'S = despesa exige ao menos um anexo';
COMMENT ON COLUMN TB_PARAMETRO.NR_VERSAO                IS 'Versão para bloqueio otimista (@Version); incrementada também ao salvar tipos de arquivo';
COMMENT ON COLUMN TB_PARAMETRO.DT_ALTERACAO             IS 'Auditoria: última alteração';
COMMENT ON COLUMN TB_PARAMETRO.ID_USUARIO_ALTERACAO     IS 'Auditoria: quem alterou por último';

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
-- TB_SALDO_CONTROLE — saldo consolidado e controle de versão
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
