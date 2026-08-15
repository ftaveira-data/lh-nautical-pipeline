-- Dimensão de produtos. Grão: uma VARIANTE.
--
-- order_items aponta para product_variant_id, e o grão da dimensão precisa
-- ser o mesmo da chave que o fato carrega. São 500 produtos e 1.009
-- variantes; no grão de produto, SKU, preço e peso não teriam onde morar.
--
-- Produto, categoria e marca entram como atributos achatados. Mantê-las
-- como tabelas separadas seria snowflake, que degrada o desempenho no
-- Power BI sem ganho de espaço relevante — são 14 categorias e 4 marcas.

CREATE OR REPLACE VIEW analytics.dim_product AS
SELECT
    v.id                                        AS variante_id,
    v.sku,
    v.barcode_ean                               AS codigo_barras,
    v.sale_price                                AS preco_venda,
    v.cost_price                                AS preco_custo,
    v.sale_price - v.cost_price                 AS margem_bruta,
    v.weight_kg                                 AS peso_kg,
    v.is_active                                 AS variante_ativa,

    p.id                                        AS produto_id,
    p.name                                      AS produto,
    p.ncm_code                                  AS ncm,
    p.unit_of_measure                           AS unidade,
    p.is_active                                 AS produto_ativo,

    cat.id                                      AS categoria_id,
    cat.name                                    AS categoria,
    pai.name                                    AS categoria_pai,

    m.id                                        AS marca_id,
    m.name                                      AS marca,
    m.country                                   AS marca_pais
FROM raw.product_variants v
JOIN raw.products    p   ON p.id   = v.product_id
LEFT JOIN raw.categories cat ON cat.id = p.category_id
LEFT JOIN raw.categories pai ON pai.id = cat.parent_category_id
LEFT JOIN raw.brands     m   ON m.id   = p.brand_id;
