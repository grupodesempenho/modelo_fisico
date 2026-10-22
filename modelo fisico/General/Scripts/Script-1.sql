-- =====================================================================
-- MODELO FÍSICO — PostgreSQL
-- Script 1 de 2: tabelas, índices e views.
-- Execute como SCRIPT no DBeaver (Alt+X), em um banco vazio.
--
-- Convenções:
--   * nomes em snake_case, sem acento; tabelas no plural
--   * PK: BIGINT GENERATED ALWAYS AS IDENTITY
--   * FK de negócio: ON DELETE RESTRICT; tabelas de ligação: CASCADE
--   * registros não são apagados: usa-se a flag "ativo"
--   * campos com valores ainda não decididos: VARCHAR sem CHECK
--     (o CHECK será adicionado depois com ALTER TABLE)
-- =====================================================================

-- Funções de criptografia (usadas em integracoes.chave_acesso)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------
-- 1. equipes
-- ---------------------------------------------------------------------
CREATE TABLE equipes (
    equipe_id   BIGINT GENERATED ALWAYS AS IDENTITY,
    nome_equipe VARCHAR(100) NOT NULL,
    CONSTRAINT pk_equipes PRIMARY KEY (equipe_id),
    CONSTRAINT uq_equipes_nome UNIQUE (nome_equipe)
);
COMMENT ON TABLE equipes IS 'Equipes da empresa. O tamanho é calculado na view vw_equipes.';

-- ---------------------------------------------------------------------
-- 2. usuarios
-- ---------------------------------------------------------------------
CREATE TABLE usuarios (
    usuario_id         BIGINT GENERATED ALWAYS AS IDENTITY,
    numero_matricula   VARCHAR(20)  NOT NULL,
    equipe_id          BIGINT       NOT NULL,
    gerente            BOOLEAN      NOT NULL DEFAULT FALSE,
    cpf                VARCHAR(11)  NOT NULL,          -- somente dígitos
    hash_senha         VARCHAR(255) NOT NULL,
    ativo              BOOLEAN      NOT NULL DEFAULT TRUE,
    email              VARCHAR(254) NOT NULL,
    telefone           VARCHAR(20),
    nivel_de_permissao VARCHAR(20)  NOT NULL,          -- valores a definir
    nome               VARCHAR(150) NOT NULL,
    data_nascimento    DATE         NOT NULL,
    foto               BYTEA,
    data_entrada       DATE         NOT NULL,
    data_saida         DATE,
    cargo              VARCHAR(100),
    departamento       VARCHAR(100),
    CONSTRAINT pk_usuarios PRIMARY KEY (usuario_id),
    CONSTRAINT uq_usuarios_matricula UNIQUE (numero_matricula),
    CONSTRAINT uq_usuarios_cpf UNIQUE (cpf),
    CONSTRAINT uq_usuarios_email UNIQUE (email),
    CONSTRAINT fk_usuarios_equipe FOREIGN KEY (equipe_id)
        REFERENCES equipes (equipe_id) ON DELETE RESTRICT,
    CONSTRAINT ck_usuarios_cpf CHECK (cpf ~ '^[0-9]{11}$'),
    CONSTRAINT ck_usuarios_nascimento CHECK (data_nascimento < CURRENT_DATE),
    CONSTRAINT ck_usuarios_saida CHECK (data_saida IS NULL OR data_saida >= data_entrada)
);
COMMENT ON TABLE usuarios IS 'Colaboradores da empresa. Não se apaga: usa-se ativo = FALSE. A idade é calculada na view vw_usuarios.';

-- ---------------------------------------------------------------------
-- 3. avaliacoes
-- ---------------------------------------------------------------------
CREATE TABLE avaliacoes (
    avaliacao_id  BIGINT GENERATED ALWAYS AS IDENTITY,
    tipo          VARCHAR(30)  NOT NULL,               -- valores a definir
    status        VARCHAR(20)  NOT NULL,               -- valores a definir
    local         VARCHAR(150),
    data_inicio   DATE         NOT NULL,
    data_fim      DATE,
    prazo         DATE,
    meio_av       VARCHAR(50),                         -- valores a definir
    link          VARCHAR(500),
    periodicidade INT,                                 -- em dias
    descricao     TEXT,
    resultado     TEXT,
    criterios     TEXT,
    CONSTRAINT pk_avaliacoes PRIMARY KEY (avaliacao_id),
    CONSTRAINT ck_avaliacoes_periodicidade CHECK (periodicidade IS NULL OR periodicidade > 0),
    CONSTRAINT ck_avaliacoes_datas CHECK (data_fim IS NULL OR data_fim >= data_inicio)
);
COMMENT ON TABLE avaliacoes IS 'Avaliações aplicadas na empresa.';

-- ---------------------------------------------------------------------
-- 4. metas
-- ---------------------------------------------------------------------
CREATE TABLE metas (
    metas_id     BIGINT GENERATED ALWAYS AS IDENTITY,
    progresso    NUMERIC(5,2) NOT NULL DEFAULT 0,      -- percentual (0 a 100)
    data_criacao DATE         NOT NULL DEFAULT CURRENT_DATE,
    prazo        DATE,
    status       VARCHAR(20)  NOT NULL DEFAULT 'pendente',
    observacoes  TEXT,
    descricao    TEXT         NOT NULL,
    CONSTRAINT pk_metas PRIMARY KEY (metas_id),
    CONSTRAINT ck_metas_progresso CHECK (progresso BETWEEN 0 AND 100),
    CONSTRAINT ck_metas_status CHECK (status IN ('pendente', 'em_andamento', 'concluida')),
    CONSTRAINT ck_metas_concluida CHECK (status <> 'concluida' OR progresso = 100)
);
COMMENT ON TABLE metas IS 'Metas dos usuários. Ligação com usuários na tabela usuarios_metas.';

-- ---------------------------------------------------------------------
-- 5. competencias
-- ---------------------------------------------------------------------
CREATE TABLE competencias (
    competencias_id BIGINT GENERATED ALWAYS AS IDENTITY,
    nome            VARCHAR(100) NOT NULL,
    e_curso         BOOLEAN      NOT NULL DEFAULT FALSE,
    descricao       TEXT,
    CONSTRAINT pk_competencias PRIMARY KEY (competencias_id),
    CONSTRAINT uq_competencias_nome UNIQUE (nome)
);
COMMENT ON TABLE competencias IS 'Competências e cursos que podem ser desenvolvidos.';

-- ---------------------------------------------------------------------
-- 6. trilhas
-- ---------------------------------------------------------------------
CREATE TABLE trilhas (
    trilha_id BIGINT GENERATED ALWAYS AS IDENTITY,
    nome      VARCHAR(100) NOT NULL,
    nivel     VARCHAR(20)  NOT NULL,                   -- valores a definir
    setor     VARCHAR(100),
    link      VARCHAR(500),
    descricao TEXT,
    CONSTRAINT pk_trilhas PRIMARY KEY (trilha_id)
);
COMMENT ON TABLE trilhas IS 'Trilhas de aprendizado. Ligação com competências em competencias_trilhas.';

-- ---------------------------------------------------------------------
-- 7. ferramentas
-- ---------------------------------------------------------------------
CREATE TABLE ferramentas (
    ferramenta_id BIGINT GENERATED ALWAYS AS IDENTITY,
    nome          VARCHAR(100) NOT NULL,
    tipo          VARCHAR(30)  NOT NULL,               -- valores a definir
    CONSTRAINT pk_ferramentas PRIMARY KEY (ferramenta_id)
);
COMMENT ON TABLE ferramentas IS 'Ferramentas externas que podem ser integradas ao sistema.';

-- ---------------------------------------------------------------------
-- 8. gatilhos (antiga tabela "triggers"; configuração em colunas)
-- ---------------------------------------------------------------------
CREATE TABLE gatilhos (
    gatilho_id       BIGINT GENERATED ALWAYS AS IDENTITY,
    usuario_id       BIGINT        NOT NULL,
    valor_referencia NUMERIC(14,4) NOT NULL,
    status           VARCHAR(20)   NOT NULL,           -- valores a definir
    metrica_alvo     VARCHAR(50)   NOT NULL,           -- valores a definir
    operador_logico  VARCHAR(10)   NOT NULL,           -- valores a definir
    CONSTRAINT pk_gatilhos PRIMARY KEY (gatilho_id),
    CONSTRAINT fk_gatilhos_usuario FOREIGN KEY (usuario_id)
        REFERENCES usuarios (usuario_id) ON DELETE RESTRICT
);
COMMENT ON TABLE gatilhos IS 'Regras configuradas por usuários que disparam alertas. Não confundir com os triggers do PostgreSQL.';

-- ---------------------------------------------------------------------
-- 9. alertas (relação 1:1 com gatilhos)
-- ---------------------------------------------------------------------
CREATE TABLE alertas (
    alerta_id     BIGINT GENERATED ALWAYS AS IDENTITY,
    gatilho_id    BIGINT       NOT NULL,
    mensagem      VARCHAR(255) NOT NULL,
    descricao     TEXT,
    periodicidade INT,                                 -- em dias; NULL = não se repete
    nivel         VARCHAR(20)  NOT NULL,               -- valores a definir
    visualizado   BOOLEAN      NOT NULL DEFAULT FALSE,
    CONSTRAINT pk_alertas PRIMARY KEY (alerta_id),
    CONSTRAINT uq_alertas_gatilho UNIQUE (gatilho_id),
    CONSTRAINT fk_alertas_gatilho FOREIGN KEY (gatilho_id)
        REFERENCES gatilhos (gatilho_id) ON DELETE RESTRICT,
    CONSTRAINT ck_alertas_periodicidade CHECK (periodicidade IS NULL OR periodicidade > 0)
);
COMMENT ON TABLE alertas IS 'Alertas gerados por gatilhos (um alerta por gatilho).';

-- ---------------------------------------------------------------------
-- 10. historicos
-- ---------------------------------------------------------------------
CREATE TABLE historicos (
    historico_id   BIGINT GENERATED ALWAYS AS IDENTITY,
    usuario_id     BIGINT       NOT NULL,
    acao_realizada VARCHAR(150) NOT NULL,
    descricao      TEXT,
    data           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_historicos PRIMARY KEY (historico_id),
    CONSTRAINT fk_historicos_usuario FOREIGN KEY (usuario_id)
        REFERENCES usuarios (usuario_id) ON DELETE RESTRICT
);
COMMENT ON TABLE historicos IS 'Registro das ações realizadas por cada usuário.';

-- ---------------------------------------------------------------------
-- 11. feedbacks
-- ---------------------------------------------------------------------
CREATE TABLE feedbacks (
    feedback_id             BIGINT GENERATED ALWAYS AS IDENTITY,
    usuario_id_autor        BIGINT    NOT NULL,
    usuario_id_destinatario BIGINT    NOT NULL,
    data                    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    descricao               TEXT      NOT NULL,
    CONSTRAINT pk_feedbacks PRIMARY KEY (feedback_id),
    CONSTRAINT fk_feedbacks_autor FOREIGN KEY (usuario_id_autor)
        REFERENCES usuarios (usuario_id) ON DELETE RESTRICT,
    CONSTRAINT fk_feedbacks_destinatario FOREIGN KEY (usuario_id_destinatario)
        REFERENCES usuarios (usuario_id) ON DELETE RESTRICT,
    CONSTRAINT ck_feedbacks_autor_diferente CHECK (usuario_id_autor <> usuario_id_destinatario)
);
COMMENT ON TABLE feedbacks IS 'Feedbacks escritos por um usuário (autor) para outro (destinatário).';

-- ---------------------------------------------------------------------
-- 12. integracoes (relação 1:1 com ferramentas)
-- ---------------------------------------------------------------------
CREATE TABLE integracoes (
    integracao_id             BIGINT GENERATED ALWAYS AS IDENTITY,
    ferramenta_id             BIGINT       NOT NULL,
    url                       VARCHAR(500) NOT NULL,
    chave_acesso              BYTEA        NOT NULL,   -- criptografada (pgcrypto)
    permissoes_acesso         VARCHAR(100),             -- valores a definir
    frequencia_sincronizacao  INT,                      -- em dias
    status                    VARCHAR(20)  NOT NULL,    -- valores a definir
    data_ultima_sincronizacao TIMESTAMP,
    CONSTRAINT pk_integracoes PRIMARY KEY (integracao_id),
    CONSTRAINT uq_integracoes_ferramenta UNIQUE (ferramenta_id),
    CONSTRAINT fk_integracoes_ferramenta FOREIGN KEY (ferramenta_id)
        REFERENCES ferramentas (ferramenta_id) ON DELETE RESTRICT,
    CONSTRAINT ck_integracoes_frequencia CHECK (frequencia_sincronizacao IS NULL OR frequencia_sincronizacao > 0)
);
COMMENT ON TABLE integracoes IS 'Integração de uma ferramenta externa com o sistema (no máximo uma por ferramenta).';
COMMENT ON COLUMN integracoes.chave_acesso IS
    'Criptografada com pgcrypto. Gravar: pgp_sym_encrypt(''texto'', ''senha_mestra''). Ler: pgp_sym_decrypt(chave_acesso, ''senha_mestra'').';

-- ---------------------------------------------------------------------
-- 13. usuarios_metas (ligação N:N; CASCADE)
-- ---------------------------------------------------------------------
CREATE TABLE usuarios_metas (
    usuario_id BIGINT NOT NULL,
    metas_id   BIGINT NOT NULL,
    CONSTRAINT pk_usuarios_metas PRIMARY KEY (usuario_id, metas_id),
    CONSTRAINT fk_usuarios_metas_usuario FOREIGN KEY (usuario_id)
        REFERENCES usuarios (usuario_id) ON DELETE CASCADE,
    CONSTRAINT fk_usuarios_metas_meta FOREIGN KEY (metas_id)
        REFERENCES metas (metas_id) ON DELETE CASCADE
);
COMMENT ON TABLE usuarios_metas IS 'Quais metas pertencem a quais usuários (N:N).';

-- ---------------------------------------------------------------------
-- 14. desenvolvimentos
--     A FK composta (usuario_id, metas_id) garante que a meta
--     pertence ao MESMO usuário. Se metas_id for NULL, não é verificada.
-- ---------------------------------------------------------------------
CREATE TABLE desenvolvimentos (
    desenvolvimento_id    BIGINT GENERATED ALWAYS AS IDENTITY,
    usuario_id            BIGINT       NOT NULL,
    competencias_id       BIGINT       NOT NULL,
    tipo_habilidade       VARCHAR(30)  NOT NULL,       -- valores a definir
    curso_realizado       VARCHAR(150),
    instituicao           VARCHAR(150),
    data_conclusao        DATE,
    certificado           BYTEA,
    objetivo_profissional TEXT,
    status                VARCHAR(20)  NOT NULL,       -- valores a definir
    ativo                 BOOLEAN      NOT NULL DEFAULT TRUE,
    metas_id              BIGINT,
    CONSTRAINT pk_desenvolvimentos PRIMARY KEY (desenvolvimento_id),
    CONSTRAINT fk_desenvolvimentos_usuario FOREIGN KEY (usuario_id)
        REFERENCES usuarios (usuario_id) ON DELETE RESTRICT,
    CONSTRAINT fk_desenvolvimentos_competencia FOREIGN KEY (competencias_id)
        REFERENCES competencias (competencias_id) ON DELETE RESTRICT,
    CONSTRAINT fk_desenvolvimentos_meta_do_usuario FOREIGN KEY (usuario_id, metas_id)
        REFERENCES usuarios_metas (usuario_id, metas_id) ON DELETE RESTRICT
);
COMMENT ON TABLE desenvolvimentos IS 'Desenvolvimento de competências de um usuário, opcionalmente ligado a uma meta dele.';

-- ---------------------------------------------------------------------
-- 15. insights
-- ---------------------------------------------------------------------
CREATE TABLE insights (
    insight_id    BIGINT GENERATED ALWAYS AS IDENTITY,
    equipe_id     BIGINT    NOT NULL,
    usuario_id    BIGINT,                              -- quem editou (NULL = não editado)
    texto_gerado  TEXT      NOT NULL,
    texto_editado TEXT,
    data_edicao   TIMESTAMP,
    CONSTRAINT pk_insights PRIMARY KEY (insight_id),
    CONSTRAINT fk_insights_equipe FOREIGN KEY (equipe_id)
        REFERENCES equipes (equipe_id) ON DELETE RESTRICT,
    CONSTRAINT fk_insights_usuario FOREIGN KEY (usuario_id)
        REFERENCES usuarios (usuario_id) ON DELETE RESTRICT,
    CONSTRAINT ck_insights_edicao CHECK (
        (texto_editado IS NULL) = (data_edicao IS NULL)
        AND (texto_editado IS NULL OR usuario_id IS NOT NULL)
    )
);OMMENT ON TABLE insights IS 'Insights gerados para uma equipe, com possível edição por um usuário.';

-- ---------------------------------------------------------------------
-- 16. usuarios_avaliacoes (ligação N:N com atributos; CASCADE)
-- ---------------------------------------------------------------------
CREATE TABLE usuarios_avaliacoes (
    usuario_id   BIGINT NOT NULL,
    avaliacao_id BIGINT NOT NULL,
    papel        VARCHAR(30) NOT NULL,                 -- valores a definir
    nota         NUMERIC(4,2),                         -- escala de 0 a 10
    comentario   TEXT,
    CONSTRAINT pk_usuarios_avaliacoes PRIMARY KEY (usuario_id, avaliacao_id),
    CONSTRAINT fk_usuarios_avaliacoes_usuario FOREIGN KEY (usuario_id)
        REFERENCES usuarios (usuario_id) ON DELETE CASCADE,
    CONSTRAINT fk_usuarios_avaliacoes_avaliacao FOREIGN KEY (avaliacao_id)
        REFERENCES avaliacoes (avaliacao_id) ON DELETE CASCADE,
    CONSTRAINT ck_usuarios_avaliacoes_nota CHECK (nota IS NULL OR nota BETWEEN 0 AND 10)
);
COMMENT ON TABLE usuarios_avaliacoes IS 'Participação de usuários em avaliações (N:N), com papel, nota e comentário.';

-- ---------------------------------------------------------------------
-- 17. competencias_trilhas (ligação N:N; CASCADE)
-- ---------------------------------------------------------------------
CREATE TABLE competencias_trilhas (
    competencias_id BIGINT NOT NULL,
    trilha_id       BIGINT NOT NULL,
    CONSTRAINT pk_competencias_trilhas PRIMARY KEY (competencias_id, trilha_id),
    CONSTRAINT fk_competencias_trilhas_competencia FOREIGN KEY (competencias_id)
        REFERENCES competencias (competencias_id) ON DELETE CASCADE,
    CONSTRAINT fk_competencias_trilhas_trilha FOREIGN KEY (trilha_id)
        REFERENCES trilhas (trilha_id) ON DELETE CASCADE
);
COMMENT ON TABLE competencias_trilhas IS 'Quais competências compõem cada trilha (N:N).';

-- =====================================================================
-- ÍNDICES
-- O PostgreSQL já cria índice para PK e UNIQUE, mas NÃO para FK.
-- Criamos só os que têm uso claro (JOINs e verificação de ON DELETE).
-- =====================================================================
CREATE INDEX idx_usuarios_equipe_id ON usuarios (equipe_id);
CREATE INDEX idx_gatilhos_usuario_id ON gatilhos (usuario_id);
CREATE INDEX idx_historicos_usuario_data ON historicos (usuario_id, data DESC);
CREATE INDEX idx_feedbacks_autor ON feedbacks (usuario_id_autor);
CREATE INDEX idx_feedbacks_destinatario ON feedbacks (usuario_id_destinatario);
CREATE INDEX idx_desenvolvimentos_usuario_meta ON desenvolvimentos (usuario_id, metas_id);
CREATE INDEX idx_desenvolvimentos_competencias_id ON desenvolvimentos (competencias_id);
CREATE INDEX idx_insights_equipe_id ON insights (equipe_id);
CREATE INDEX idx_insights_usuario_id ON insights (usuario_id);
CREATE INDEX idx_usuarios_avaliacoes_avaliacao_id ON usuarios_avaliacoes (avaliacao_id);
CREATE INDEX idx_usuarios_metas_metas_id ON usuarios_metas (metas_id);
CREATE INDEX idx_competencias_trilhas_trilha_id ON competencias_trilhas (trilha_id);

-- =====================================================================
-- VIEWS (valores calculados em vez de colunas)
-- =====================================================================

-- Usuários com idade calculada. Não expõe hash_senha nem foto.
CREATE VIEW vw_usuarios AS
SELECT u.usuario_id, u.numero_matricula, u.equipe_id, u.gerente, u.cpf, u.ativo,
       u.email, u.telefone, u.nivel_de_permissao, u.nome, u.data_nascimento,
       EXTRACT(YEAR FROM age(CURRENT_DATE, u.data_nascimento))::INT AS idade,
       u.data_entrada, u.data_saida, u.cargo, u.departamento
FROM usuarios u;

-- Equipes com tamanho calculado (conta apenas usuários ativos).
CREATE VIEW vw_equipes AS
SELECT e.equipe_id, e.nome_equipe,
       COUNT(u.usuario_id) FILTER (WHERE u.ativo) AS tamanho
FROM equipes e
LEFT JOIN usuarios u ON u.equipe_id = e.equipe_id
GROUP BY e.equipe_id, e.nome_equipe;