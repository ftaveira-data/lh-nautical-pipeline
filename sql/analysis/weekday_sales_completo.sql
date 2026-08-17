-- =========================================================================
-- Dia da semana com menor média de vendas nas lojas físicas
--
-- Arquivo autocontido: cria a dimensão de calendário e roda a análise em
-- sequência. No repositório as duas partes vivem separadas, em
-- sql/analytics/dim_calendar.sql e sql/analysis/weekday_sales.sql.
-- =========================================================================


-- -------------------------------------------------------------------------
-- PARTE 1 — Dimensão de calendário
--
-- Cobre todos os dias entre a primeira e a última data de QUALQUER fato,
-- não apenas de vendas: existem 17 devoluções em janeiro de 2027,
-- posteriores à última venda registrada. Um calendário construído só a
-- partir de orders deixaria essas linhas sem correspondência, e o Power BI
-- criaria um membro "(Em branco)" para acomodá-las.
--
-- A coluna eh_periodo_de_vendas marca o intervalo entre a primeira e a
-- última venda. A dimensão descreve o universo inteiro; quem recorta é a
-- consulta.
--
-- É uma view para acompanhar a extensão do período conforme novos
-- registros entram.
-- -------------------------------------------------------------------------

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
    -- Traduzido por CASE em vez de to_char porque o locale do servidor não
    -- é garantido: a imagem do Postgres sobe com locale C.
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


-- -------------------------------------------------------------------------
-- PARTE 2 — Média de vendas por dia da semana nas lojas físicas
--
-- O filtro de loja física é channel = 'pos' em orders. A coluna
-- location_type de locations tem apenas 'store' e 'warehouse', e não
-- corresponde ao canal: 7.495 pedidos 'pos' apontam para armazém.
-- -------------------------------------------------------------------------

WITH vendas_diarias AS (
    SELECT
        placed_at::date AS data,
        SUM(total)      AS valor
    FROM raw.orders
    WHERE channel = 'pos'
    GROUP BY placed_at::date
)

SELECT
    c.dia_semana_num,
    c.dia_semana,
    COUNT(*)                              AS dias_no_periodo,
    COUNT(v.data)                         AS dias_com_venda,
    COUNT(*) - COUNT(v.data)              AS dias_sem_venda,
    SUM(COALESCE(v.valor, 0))             AS total_vendido,

    -- Média correta: dias sem venda entram como zero.
    ROUND(AVG(COALESCE(v.valor, 0)), 2)   AS media_diaria,

    -- Média que o LEFT JOIN produziria sem o COALESCE. AVG ignora NULL,
    -- então os dias sem venda somem do denominador. Fica aqui para
    -- dimensionar o erro do cálculo original.
    ROUND(AVG(v.valor), 2)                AS media_sem_dias_zerados

FROM analytics.dim_calendar c
LEFT JOIN vendas_diarias    v ON v.data = c.data

-- A dimensão cobre até janeiro de 2027 porque existem devoluções
-- posteriores à última venda. A premissa da análise é o intervalo entre
-- a primeira e a última venda, então o recorte é declarado aqui.
WHERE c.eh_periodo_de_vendas

GROUP BY c.dia_semana_num, c.dia_semana
ORDER BY media_diaria ASC;
