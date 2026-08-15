-- Fato de itens de pedido. Grão: um item.
--
-- Quantidade, preço unitário e valor de linha só existem neste grão. É
-- aqui que se responde mix de produto e volume por categoria.
--
-- Data, cliente e local são trazidos do pedido para que dim_calendar,
-- dim_customer e dim_location filtrem os dois fatos da mesma forma. É a
-- denormalização que torna as dimensões conformadas.
--
-- A soma de valor_linha corresponde ao subtotal do pedido, não ao total:
-- o desconto é aplicado no pedido e não rateado nos itens.

CREATE OR REPLACE VIEW analytics.fct_order_items AS
SELECT
    i.id                                        AS item_id,
    i.order_id                                  AS pedido_id,
    o.placed_at::date                           AS data,
    o.customer_id                               AS cliente_id,
    o.location_id                               AS local_id,
    COALESCE(o.salesperson_id, -1)              AS funcionario_id,
    i.product_variant_id                        AS variante_id,

    o.channel                                   AS canal,
    o.status,
    o.status IN ('paid', 'confirmed')           AS eh_receita_realizada,

    i.quantity                                  AS quantidade,
    i.unit_price                                AS preco_unitario,
    i.line_total                                AS valor_linha
FROM raw.order_items i
JOIN raw.orders o ON o.id = i.order_id;
