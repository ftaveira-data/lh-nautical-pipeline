-- Dimensão de clientes. Grão: um cliente.
--
-- O endereço principal é achatado aqui: cada cliente tem exatamente um
-- registro com is_primary = true, então o JOIN não multiplica linhas.

CREATE OR REPLACE VIEW analytics.dim_customer AS
SELECT
    c.id                                        AS cliente_id,
    COALESCE(c.trade_name, c.legal_name)        AS cliente,
    c.legal_name                                AS razao_social,
    c.person_type                               AS tipo_pessoa,
    CASE c.person_type
        WHEN 'PF' THEN 'Pessoa física'
        WHEN 'PJ' THEN 'Pessoa jurídica'
        ELSE c.person_type
    END                                         AS tipo_pessoa_desc,
    c.tax_id                                    AS documento,
    c.email,
    c.is_active                                 AS ativo,
    e.city                                      AS cidade,
    e.state                                     AS uf,
    e.postal_code                               AS cep,
    c.created_at::date                          AS data_cadastro
FROM raw.customers c
LEFT JOIN raw.addresses e
       ON e.customer_id = c.id
      AND e.is_primary;
