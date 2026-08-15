-- Dimensão de locais. Grão: um local.
--
-- Inclui lojas e armazéns. Dimensão descreve o universo; filtrar é
-- trabalho da consulta. Sete tabelas apontam para locations, e a maioria
-- fala de armazém — recortar aqui mutilaria as outras análises.
--
-- Atenção: location_type NÃO corresponde ao canal de venda. Existem 7.495
-- pedidos com channel = 'pos' cujo location_type é 'warehouse'.

CREATE OR REPLACE VIEW analytics.dim_location AS
SELECT
    l.id                                        AS local_id,
    l.name                                      AS local,
    l.location_type                             AS tipo,
    CASE l.location_type
        WHEN 'store'     THEN 'Loja'
        WHEN 'warehouse' THEN 'Armazém'
        ELSE l.location_type
    END                                         AS tipo_desc,
    l.city                                      AS cidade,
    l.state                                     AS uf,
    l.postal_code                               AS cep,
    l.is_active                                 AS ativo
FROM raw.locations l;
