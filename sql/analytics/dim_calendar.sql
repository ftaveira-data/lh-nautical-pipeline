-- Dimensão de calendário.
--
-- Cobre todos os dias entre a primeira e a última venda registrada,
-- inclusive os dias sem nenhum pedido. É essa continuidade que permite
-- distinguir "vendeu zero" de "não há linha na tabela".
--
-- Construída como view para acompanhar automaticamente a extensão do
-- período conforme novos pedidos entram.

CREATE SCHEMA IF NOT EXISTS analytics;

CREATE OR REPLACE VIEW analytics.dim_calendar AS
WITH periodo AS (
    SELECT
        MIN(placed_at)::date AS inicio,
        MAX(placed_at)::date AS fim
    FROM raw.orders
),

dias AS (
    SELECT generate_series(inicio, fim, INTERVAL '1 day')::date AS data
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
    DATE_TRUNC('month', data)::date              AS primeiro_dia_do_mes
FROM dias;
