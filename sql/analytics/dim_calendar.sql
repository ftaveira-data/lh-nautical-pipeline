-- Dimensão de calendário.
--
-- Cobre todos os dias entre a primeira e a última data presente em
-- QUALQUER fato, não apenas em vendas. Devoluções acontecem depois da
-- compra: existem 17 devoluções em janeiro de 2027, posteriores à última
-- venda registrada. Um calendário construído só a partir de orders
-- deixaria essas linhas sem correspondência na dimensão, e o Power BI
-- criaria um membro "(Em branco)" para acomodá-las.
--
-- A coluna eh_periodo_de_vendas marca o recorte que a análise por dia da
-- semana usa: o intervalo entre a primeira e a última venda. A dimensão
-- descreve o universo inteiro; quem filtra é a consulta.
--
-- Construída como view para acompanhar automaticamente a extensão do
-- período conforme novos registros entram.

CREATE SCHEMA IF NOT EXISTS analytics;

DROP VIEW IF EXISTS analytics.dim_calendar;

CREATE VIEW analytics.dim_calendar AS
WITH limites AS (
    SELECT
        (SELECT MIN(placed_at)::date  FROM raw.orders)  AS primeira_venda,
        (SELECT MAX(placed_at)::date  FROM raw.orders)  AS ultima_venda,
        (SELECT MIN(created_at)::date FROM raw.returns) AS primeira_devolucao,
        (SELECT MAX(created_at)::date FROM raw.returns) AS ultima_devolucao
),

periodo AS (
    SELECT
        LEAST(primeira_venda, primeira_devolucao) AS inicio,
        GREATEST(ultima_venda, ultima_devolucao)  AS fim,
        primeira_venda,
        ultima_venda
    FROM limites
),

dias AS (
    SELECT
        generate_series(inicio, fim, INTERVAL '1 day')::date AS data,
        primeira_venda,
        ultima_venda
    FROM periodo
)

SELECT
    data,
    EXTRACT(YEAR    FROM data)::int              AS ano,
    EXTRACT(QUARTER FROM data)::int              AS trimestre,
    EXTRACT(MONTH   FROM data)::int              AS mes,
    EXTRACT(DAY     FROM data)::int              AS dia,
    EXTRACT(DOY     FROM data)::int              AS dia_do_ano,
    EXTRACT(WEEK    FROM data)::int              AS semana_do_ano,
    EXTRACT(ISODOW  FROM data)::int              AS dia_semana_num,

    -- ISODOW: 1 = segunda ... 7 = domingo.
    -- Traduzido por CASE em vez de to_char porque o locale do servidor
    -- não é garantido — a imagem do Postgres sobe com locale C.
    CASE EXTRACT(ISODOW FROM data)
        WHEN 1 THEN 'Segunda-feira'
        WHEN 2 THEN 'Terça-feira'
        WHEN 3 THEN 'Quarta-feira'
        WHEN 4 THEN 'Quinta-feira'
        WHEN 5 THEN 'Sexta-feira'
        WHEN 6 THEN 'Sábado'
        WHEN 7 THEN 'Domingo'
    END                                          AS dia_semana,

    CASE EXTRACT(MONTH FROM data)
        WHEN  1 THEN 'Janeiro'   WHEN  2 THEN 'Fevereiro'
        WHEN  3 THEN 'Março'     WHEN  4 THEN 'Abril'
        WHEN  5 THEN 'Maio'      WHEN  6 THEN 'Junho'
        WHEN  7 THEN 'Julho'     WHEN  8 THEN 'Agosto'
        WHEN  9 THEN 'Setembro'  WHEN 10 THEN 'Outubro'
        WHEN 11 THEN 'Novembro'  WHEN 12 THEN 'Dezembro'
    END                                          AS mes_nome,

    EXTRACT(ISODOW FROM data) >= 6               AS eh_fim_de_semana,
    data BETWEEN primeira_venda AND ultima_venda AS eh_periodo_de_vendas,
    DATE_TRUNC('month', data)::date              AS primeiro_dia_do_mes
FROM dias;
