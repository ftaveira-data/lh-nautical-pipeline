-- =========================================================================
-- Segmentação de clientes por ticket médio e diversidade de categorias
--
-- Objetivo: identificar os clientes de maior valor por transação entre os
-- que circulam por praticamente todo o catálogo — não os que compraram
-- muito uma vez só.
--
-- Cadeia de chaves percorrida:
--   orders.customer_id
--     -> order_items.order_id
--        -> product_variants.id        (order_items guarda a VARIANTE)
--           -> products.product_id
--              -> categories.category_id
--
-- O elo em product_variants é obrigatório: order_items não tem product_id.
-- Pular essa tabela é o erro mais provável nesta consulta.
-- =========================================================================


-- -------------------------------------------------------------------------
-- 1. Ticket médio, diversidade e os 10 primeiros do ranking
--
-- As duas métricas vivem em GRÃOS DIFERENTES e por isso são calculadas em
-- CTEs separadas:
--
--   - faturamento e frequência são do grão PEDIDO
--   - diversidade de categorias é do grão ITEM
--
-- Se as duas fossem calculadas na mesma consulta, o JOIN com order_items
-- repetiria cada pedido uma vez por item, e SUM(total) contaria o mesmo
-- valor várias vezes. É o efeito de fan-out: a consulta roda, não acusa
-- erro nenhum, e devolve um faturamento inflado.
-- -------------------------------------------------------------------------

WITH metricas_pedido AS (
    -- Grão: um pedido por linha. Nenhum JOIN aqui, de propósito.
    SELECT
        customer_id,
        SUM(total) AS faturamento_total,
        COUNT(*)   AS frequencia
    FROM raw.orders
    GROUP BY customer_id
),

diversidade AS (
    -- Grão: um item por linha, colapsado em categorias distintas.
    SELECT
        o.customer_id,
        COUNT(DISTINCT p.category_id) AS diversidade_categorias
    FROM raw.orders o
    JOIN raw.order_items     oi ON oi.order_id           = o.id
    JOIN raw.product_variants v ON v.id                  = oi.product_variant_id
    JOIN raw.products         p ON p.id                  = v.product_id
    GROUP BY o.customer_id
)

SELECT
    m.customer_id,
    m.faturamento_total,
    m.frequencia,
    ROUND(m.faturamento_total / m.frequencia, 2) AS ticket_medio,
    d.diversidade_categorias
FROM metricas_pedido m
JOIN diversidade     d ON d.customer_id = m.customer_id
WHERE d.diversidade_categorias >= 13
ORDER BY
    ticket_medio DESC,
    m.customer_id ASC          -- desempate definido nas premissas
LIMIT 10;


-- -------------------------------------------------------------------------
-- 2. Categoria que concentra mais itens dentro do grupo dos 10
--
-- O ranking é reconstruído dentro da CTE `elite` para que a contagem de
-- itens seja restrita exatamente aos mesmos 10 clientes. Filtrar por
-- diversidade de novo no final não bastaria: traria os 1.971 clientes que
-- atendem ao critério, e não os 10 do topo.
-- -------------------------------------------------------------------------

WITH metricas_pedido AS (
    SELECT
        customer_id,
        SUM(total) AS faturamento_total,
        COUNT(*)   AS frequencia
    FROM raw.orders
    GROUP BY customer_id
),

diversidade AS (
    SELECT
        o.customer_id,
        COUNT(DISTINCT p.category_id) AS diversidade_categorias
    FROM raw.orders o
    JOIN raw.order_items     oi ON oi.order_id           = o.id
    JOIN raw.product_variants v ON v.id                  = oi.product_variant_id
    JOIN raw.products         p ON p.id                  = v.product_id
    GROUP BY o.customer_id
),

elite AS (
    SELECT m.customer_id
    FROM metricas_pedido m
    JOIN diversidade     d ON d.customer_id = m.customer_id
    WHERE d.diversidade_categorias >= 13
    ORDER BY
        m.faturamento_total / m.frequencia DESC,
        m.customer_id ASC
    LIMIT 10
)

SELECT
    c.id                  AS categoria_id,
    c.name                AS categoria,
    SUM(oi.quantity)      AS itens_comprados,
    COUNT(DISTINCT o.id)  AS pedidos_envolvidos
FROM elite e
JOIN raw.orders           o ON o.customer_id         = e.customer_id
JOIN raw.order_items     oi ON oi.order_id           = o.id
JOIN raw.product_variants v ON v.id                  = oi.product_variant_id
JOIN raw.products         p ON p.id                  = v.product_id
JOIN raw.categories       c ON c.id                  = p.category_id
GROUP BY c.id, c.name
ORDER BY itens_comprados DESC;
