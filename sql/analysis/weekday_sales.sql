-- Média de vendas por dia da semana nas lojas físicas.
--
-- Depende de analytics.dim_calendar.
--
-- O filtro de loja física é channel = 'pos' em orders. A coluna
-- location_type de locations tem apenas 'store' e 'warehouse', e não
-- corresponde ao canal: 7.495 pedidos 'pos' apontam para armazém.

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
GROUP BY c.dia_semana_num, c.dia_semana
ORDER BY media_diaria ASC;
