-- Fato de devoluções. Grão: um item devolvido.
--
-- Terceiro fato da constelação. Compartilha dim_calendar, dim_customer,
-- dim_product e dim_location com os outros dois.
--
-- REGRA DE LIMPEZA APLICADA AQUI, NÃO NA RAW
--
-- A coluna returns.reason tem 32 valores distintos para 6 motivos reais.
-- As variações são erro de digitação ("Produto ccom defeito de fábrica"),
-- caixa alta ("COMPRA DUPLICADA"), espaço sobrando no início ou fim,
-- espaço duplicado no meio, e três formas de vazio ('', '—', '?').
--
-- Um GROUP BY sobre o valor original devolve 32 categorias e nenhuma
-- resposta. A view guarda as duas colunas — motivo_original e motivo —
-- para que a limpeza seja auditável: dá para comparar o antes e o depois
-- sem sair do modelo.
--
-- Os padrões de busca foram escolhidos sem acento de propósito, para não
-- depender da extensão unaccent. 'brica' cobre "fábrica", 'descri' cobre
-- "descrição". A regra de 'corresp' vem antes de qualquer coisa com 'cor'.

CREATE OR REPLACE VIEW analytics.fct_returns AS
WITH normalizado AS (
    SELECT
        ri.id                    AS item_devolucao_id,
        r.id                     AS devolucao_id,
        r.return_number          AS numero_devolucao,
        r.created_at::date       AS data,
        r.customer_id            AS cliente_id,
        r.received_at_location_id AS local_id,
        oi.product_variant_id    AS variante_id,
        o.id                     AS pedido_id,
        r.status,
        ri.action                AS acao,
        ri.quantity              AS quantidade,
        ri.unit_refund_amount    AS valor_unitario,
        ri.quantity * ri.unit_refund_amount AS valor_reembolso,
        r.reason                 AS motivo_original,
        -- minúsculas, sem espaço nas pontas, sem espaço duplicado no meio
        lower(regexp_replace(btrim(COALESCE(r.reason, '')), '\s+', ' ', 'g')) AS chave
    FROM raw.return_items ri
    JOIN raw.returns      r  ON r.id  = ri.return_id
    JOIN raw.order_items  oi ON oi.id = ri.order_item_id
    JOIN raw.orders       o  ON o.id  = oi.order_id
)

SELECT
    item_devolucao_id,
    devolucao_id,
    numero_devolucao,
    data,
    cliente_id,
    local_id,
    variante_id,
    pedido_id,
    status,
    acao,
    CASE acao
        WHEN 'refund'   THEN 'Reembolso'
        WHEN 'exchange' THEN 'Troca'
        ELSE acao
    END                       AS acao_desc,
    quantidade,
    valor_unitario,
    valor_reembolso,
    motivo_original,
    CASE
        WHEN chave IN ('', '-', '—', '?', 'outros') THEN 'Não informado'
        WHEN chave LIKE '%duplicad%'  THEN 'Compra duplicada'
        WHEN chave LIKE '%desist%'    THEN 'Cliente desistiu da compra'
        WHEN chave LIKE '%corresp%'
          OR chave LIKE '%descri%'    THEN 'Item não corresponde à descrição'
        WHEN chave LIKE '%avariad%'
          OR chave LIKE '%transporte%' THEN 'Produto avariado no transporte'
        WHEN chave LIKE '%tamanho%'   THEN 'Tamanho/cor incorretos'
        WHEN chave LIKE '%defeito%'
          OR chave LIKE '%brica%'     THEN 'Produto com defeito de fábrica'
        ELSE 'Não informado'
    END                       AS motivo,
    -- Marca as linhas em que a limpeza mudou o valor, para o visual de
    -- antes e depois na página de qualidade.
    motivo_original IS DISTINCT FROM CASE
        WHEN chave IN ('', '-', '—', '?', 'outros') THEN 'Não informado'
        WHEN chave LIKE '%duplicad%'  THEN 'Compra duplicada'
        WHEN chave LIKE '%desist%'    THEN 'Cliente desistiu da compra'
        WHEN chave LIKE '%corresp%'
          OR chave LIKE '%descri%'    THEN 'Item não corresponde à descrição'
        WHEN chave LIKE '%avariad%'
          OR chave LIKE '%transporte%' THEN 'Produto avariado no transporte'
        WHEN chave LIKE '%tamanho%'   THEN 'Tamanho/cor incorretos'
        WHEN chave LIKE '%defeito%'
          OR chave LIKE '%brica%'     THEN 'Produto com defeito de fábrica'
        ELSE 'Não informado'
    END                       AS motivo_foi_corrigido
FROM normalizado;
