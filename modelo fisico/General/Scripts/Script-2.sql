

-- =====================================================================
-- MODELO FÍSICO — PostgreSQL
-- Script 2 de 2: regras de cardinalidade mínima "1" (lado N).
-- Execute DEPOIS do script 01.
--
-- Regras impostas:
--   * equipes     -> toda equipe tem ao menos 1 usuário
--   * avaliacoes  -> toda avaliação tem ao menos 1 participante
--   * trilhas     -> toda trilha tem ao menos 1 competência
--   * gatilhos    -> todo gatilho tem exatamente 1 alerta (o "exatamente"
--                    vem do UNIQUE em alertas.gatilho_id)
--   (Usuário -> Metas NÃO é imposta: usuário pode existir sem meta.)
--
-- COMO FUNCIONA: são "constraint triggers" DEFERIDAS. O PostgreSQL só
-- verifica a regra no COMMIT. Por isso, o registro pai e o primeiro
-- filho devem ser criados NA MESMA TRANSAÇÃO:
--
--   BEGIN;
--   INSERT INTO equipes (nome_equipe) VALUES ('Equipe A');
--   INSERT INTO usuarios (...) VALUES (...);
--   COMMIT;
--
-- No DBeaver, em modo "Auto-commit", cada comando é confirmado sozinho
-- e a regra falharia. Use BEGIN ... COMMIT explícito.
-- =====================================================================

-- Verifica, ao inserir o PAI, se já existe ao menos um FILHO.
-- Argumentos: tabela_filho, coluna_fk_no_filho, coluna_pk_no_pai
CREATE FUNCTION fn_pai_exige_filho() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    filho_tabela TEXT := TG_ARGV[0];
    filho_fk     TEXT := TG_ARGV[1];
    pai_pk       TEXT := TG_ARGV[2];
    pai_id       BIGINT := (to_jsonb(NEW) ->> TG_ARGV[2])::BIGINT;
    existe       BOOLEAN;
BEGIN
    EXECUTE format('SELECT EXISTS (SELECT 1 FROM %I WHERE %I = $1)', filho_tabela, filho_fk)
        INTO existe USING pai_id;
    IF NOT existe THEN
        RAISE EXCEPTION 'Cardinalidade mínima violada: % (id %) precisa de ao menos um registro em %',
            TG_TABLE_NAME, pai_id, filho_tabela
            USING ERRCODE = '23514';
    END IF;
    RETURN NULL;
END;
$$;

-- Verifica, ao remover/mover um FILHO, se o PAI (que ainda existe)
-- não ficou sem filhos.
-- Argumentos: tabela_pai, coluna_pk_no_pai, tabela_filho, coluna_fk_no_filho
CREATE FUNCTION fn_filho_mantem_pai() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    pai_tabela   TEXT := TG_ARGV[0];
    pai_pk       TEXT := TG_ARGV[1];
    filho_tabela TEXT := TG_ARGV[2];
    filho_fk     TEXT := TG_ARGV[3];
    pai_id       BIGINT := (to_jsonb(OLD) ->> TG_ARGV[3])::BIGINT;
    pai_existe   BOOLEAN;
    filho_existe BOOLEAN;
BEGIN
    EXECUTE format('SELECT EXISTS (SELECT 1 FROM %I WHERE %I = $1)', pai_tabela, pai_pk)
        INTO pai_existe USING pai_id;
    IF pai_existe THEN
        EXECUTE format('SELECT EXISTS (SELECT 1 FROM %I WHERE %I = $1)', filho_tabela, filho_fk)
            INTO filho_existe USING pai_id;
        IF NOT filho_existe THEN
            RAISE EXCEPTION 'Cardinalidade mínima violada: % (id %) ficaria sem registros em %',
                pai_tabela, pai_id, filho_tabela
                USING ERRCODE = '23514';
        END IF;
    END IF;
    RETURN NULL;
END;
$$;

-- equipes (1,N) usuarios
CREATE CONSTRAINT TRIGGER ctg_equipes_exige_usuario
    AFTER INSERT ON equipes
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
    EXECUTE FUNCTION fn_pai_exige_filho('usuarios', 'equipe_id', 'equipe_id');
CREATE CONSTRAINT TRIGGER ctg_usuarios_mantem_equipe
    AFTER DELETE OR UPDATE OF equipe_id ON usuarios
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
    EXECUTE FUNCTION fn_filho_mantem_pai('equipes', 'equipe_id', 'usuarios', 'equipe_id');

-- avaliacoes (1,N) participantes
CREATE CONSTRAINT TRIGGER ctg_avaliacoes_exige_participante
    AFTER INSERT ON avaliacoes
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
    EXECUTE FUNCTION fn_pai_exige_filho('usuarios_avaliacoes', 'avaliacao_id', 'avaliacao_id');
CREATE CONSTRAINT TRIGGER ctg_usuarios_avaliacoes_mantem_avaliacao
    AFTER DELETE OR UPDATE OF avaliacao_id ON usuarios_avaliacoes
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
    EXECUTE FUNCTION fn_filho_mantem_pai('avaliacoes', 'avaliacao_id', 'usuarios_avaliacoes', 'avaliacao_id');

-- trilhas (1,N) competencias
CREATE CONSTRAINT TRIGGER ctg_trilhas_exige_competencia
    AFTER INSERT ON trilhas
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
    EXECUTE FUNCTION fn_pai_exige_filho('competencias_trilhas', 'trilha_id', 'trilha_id');
CREATE CONSTRAINT TRIGGER ctg_competencias_trilhas_mantem_trilha
    AFTER DELETE OR UPDATE OF trilha_id ON competencias_trilhas
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
    EXECUTE FUNCTION fn_filho_mantem_pai('trilhas', 'trilha_id', 'competencias_trilhas', 'trilha_id');

-- gatilhos (1,1) alertas
CREATE CONSTRAINT TRIGGER ctg_gatilhos_exige_alerta
    AFTER INSERT ON gatilhos
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
    EXECUTE FUNCTION fn_pai_exige_filho('alertas', 'gatilho_id', 'gatilho_id');
CREATE CONSTRAINT TRIGGER ctg_alertas_mantem_gatilho
    AFTER DELETE OR UPDATE OF gatilho_id ON alertas
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
    EXECUTE FUNCTION fn_filho_mantem_pai('gatilhos', 'gatilho_id', 'alertas', 'gatilho_id');

