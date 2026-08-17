-- Dimensão de funcionários. Grão: um funcionário.
--
-- Inclui um membro artificial de id -1 para os pedidos sem vendedor, que
-- são 24.131 dos 48.998. Sem ele, o fato ficaria com chave nula e o Power
-- BI criaria uma categoria em branco, que o usuário não sabe interpretar.
-- Com ele, a ausência vira um rótulo explícito e filtrável.

CREATE OR REPLACE VIEW analytics.dim_employee AS
SELECT
    -1                          AS funcionario_id,
    'Sem vendedor'              AS funcionario,
    'Não aplicável'             AS cargo,
    NULL::int                   AS local_id,
    NULL::date                  AS data_admissao,
    TRUE                        AS ativo

UNION ALL

SELECT
    e.id                        AS funcionario_id,
    e.full_name                 AS funcionario,
    e.role                      AS cargo,
    e.primary_location_id       AS local_id,
    e.hire_date                 AS data_admissao,
    e.is_active                 AS ativo
FROM raw.employees e;
