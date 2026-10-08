CREATE TABLE clientes (
    id INTEGER PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    telefone VARCHAR(20) NOT NULL
);

CREATE TABLE servicos (
    id INTEGER PRIMARY KEY,
    descricao VARCHAR(100) NOT NULL,
    preco NUMERIC(8, 2) NOT NULL
);

CREATE TABLE agendamentos (
    id INTEGER PRIMARY KEY,
    cliente_id INTEGER NOT NULL REFERENCES clientes(id),
    servico_id INTEGER NOT NULL REFERENCES servicos(id),
    horario TIMESTAMP NOT NULL
);

INSERT INTO clientes (id, nome, telefone) VALUES
    (1, 'Cliente Ficticio 01', '0000000001'),
    (2, 'Cliente Ficticio 02', '0000000002'),
    (3, 'Cliente Ficticio 03', '0000000003');

INSERT INTO servicos (id, descricao, preco) VALUES
    (1, 'Corte demonstrativo', 25.00),
    (2, 'Barba demonstrativa', 15.00);

INSERT INTO agendamentos (id, cliente_id, servico_id, horario) VALUES
    (1, 1, 1, '2026-10-10 09:00:00'),
    (2, 2, 2, '2026-10-10 10:00:00'),
    (3, 3, 1, '2026-10-10 11:00:00');
