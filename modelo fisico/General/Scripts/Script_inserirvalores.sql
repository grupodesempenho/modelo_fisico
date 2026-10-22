BEGIN;

-- 1. Insere a Equipe Pai
INSERT INTO equipes (nome_equipe) 
VALUES ('Equipe de Desenvolvimento');

-- 2. Insere o Primeiro Usuário com todos os campos obrigatórios
INSERT INTO usuarios (
    numero_matricula, 
    equipe_id, 
    gerente, 
    cpf, 
    hash_senha, 
    ativo, 
    email, 
    nivel_de_permissao,
    nome, 
    data_nascimento,
    data_entrada,
    cargo,
    departamento
) 
VALUES (
    '12345', 
    currval(pg_get_serial_sequence('equipes', 'equipe_id')), 
    false, 
    '12345678900', 
    'hash_exemplo', 
    true, 
    'usuario@email.com', 
    'admin',
    'Luiz Silva', 
    '1995-05-20',
    CURRENT_DATE,
    'Desenvolvedor',
    'TI'
);

COMMIT;