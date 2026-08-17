-- Fato de pedidos. Grão: um pedido.
--
-- É aqui que moram faturamento, desconto e ticket médio. Somar valor de
-- pedido no fato de itens contaria o mesmo total uma vez por item.
--
-- Nenhum pedido é excluído: o fato carrega tudo e o filtro é decisão de
-- quem consulta. A coluna eh_receita_realizada existe para tornar essa
-- decisão explícita — cancelados e rascunhos têm total preenchido e
-- representam 14,8% do valor somado.

-- DROP antes do CREATE: o PostgreSQL só aceita CREATE OR REPLACE VIEW
-- quando as colunas novas entram no fim da lista, e status_desc nasce
-- ao lado da coluna que ela traduz.
DROP VIEW IF EXISTS analytics.fct_orders;

CREATE VIEW analytics.fct_orders AS
SELECT
    o.id                                        AS pedido_id,
    o.order_number                              AS numero_pedido,
    o.placed_at::date                           AS data,
    o.customer_id                               AS cliente_id,
    o.location_id                               AS local_id,
    COALESCE(o.salesperson_id, -1)              AS funcionario_id,

    o.channel                                   AS canal,
    CASE o.channel
        WHEN 'pos'       THEN 'Loja física'
        WHEN 'ecommerce' THEN 'E-commerce'
        ELSE o.channel
    END                                         AS canal_desc,

    o.status,
    CASE o.status
        WHEN 'paid'      THEN 'Pago'
        WHEN 'confirmed' THEN 'Confirmado'
        WHEN 'cancelled' THEN 'Cancelado'
        WHEN 'draft'     THEN 'Rascunho'
        ELSE o.status
    END                                         AS status_desc,

    o.status IN ('paid', 'confirmed')           AS eh_receita_realizada,

    o.subtotal,
    o.discount_amount                           AS desconto,
    o.total
FROM raw.orders o;
