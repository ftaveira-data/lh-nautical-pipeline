-- =========================================================================
-- Perfilagem exploratória da tabela raw.orders
--
-- Objetivo: descrever volume, período coberto e distribuição de valores
-- sem alterar nada. Apenas leitura — nenhuma limpeza ou transformação.
-- =========================================================================


-- -------------------------------------------------------------------------
-- 1. Visão geral: volume e período
--
-- A contagem de colunas vem do catálogo do próprio banco (information_schema)
-- em vez de ser digitada à mão: assim o número acompanha a tabela caso ela
-- mude, e a consulta continua verdadeira sem manutenção.
-- -------------------------------------------------------------------------

SELECT
    (SELECT COUNT(*) FROM raw.orders)                    AS total_linhas,
    (SELECT COUNT(*)
       FROM information_schema.columns
      WHERE table_schema = 'raw'
        AND table_name   = 'orders')                     AS total_colunas,
    (SELECT MIN(created_at) FROM raw.orders)             AS data_minima,
    (SELECT MAX(created_at) FROM raw.orders)             AS data_maxima;


-- -------------------------------------------------------------------------
-- 2. Distribuição da coluna "total"
--
-- Além do que foi pedido (mínimo, máximo e média), a mediana e os quartis
-- entram para responder à Parte 3: média e mediana próximas indicam
-- distribuição simétrica; distantes, indicam cauda puxada por outliers.
-- -------------------------------------------------------------------------

SELECT
    MIN(total)                                            AS total_minimo,
    MAX(total)                                            AS total_maximo,
    ROUND(AVG(total), 2)                                  AS total_medio,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY total)   AS q1,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY total)   AS mediana,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total)   AS q3,
    ROUND(STDDEV_SAMP(total), 2)                          AS desvio_padrao
FROM raw.orders;


-- -------------------------------------------------------------------------
-- 3. Inventário de colunas: tipo e nulidade
--
-- O schema foi gerado a partir dos próprios dados, então "is_nullable"
-- não é uma promessa do modelador: é um fato observado no arquivo.
-- -------------------------------------------------------------------------

SELECT
    ordinal_position AS posicao,
    column_name      AS coluna,
    data_type        AS tipo,
    is_nullable      AS aceita_nulo
FROM information_schema.columns
WHERE table_schema = 'raw'
  AND table_name   = 'orders'
ORDER BY ordinal_position;


-- -------------------------------------------------------------------------
-- 4. Onde os nulos estão, e se há padrão por trás
--
-- Nulo não é necessariamente defeito. Se ele se concentrar num canal,
-- a ausência tem explicação de negócio em vez de ser falha de captura.
-- -------------------------------------------------------------------------

SELECT
    channel,
    COUNT(*)                                              AS pedidos,
    COUNT(salesperson_id)                                 AS com_vendedor,
    COUNT(*) - COUNT(salesperson_id)                      AS sem_vendedor,
    ROUND(100.0 * (COUNT(*) - COUNT(salesperson_id)) / COUNT(*), 1) AS pct_sem_vendedor
FROM raw.orders
GROUP BY channel
ORDER BY channel;


-- -------------------------------------------------------------------------
-- 5. Status: quanto do valor somado não é receita realizada
--
-- Somar "total" sem olhar o status é o erro mais caro possível nesta
-- tabela: pedidos cancelados e rascunhos têm valor preenchido.
-- -------------------------------------------------------------------------

SELECT
    status,
    COUNT(*)                                              AS pedidos,
    SUM(total)                                            AS valor_somado,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)    AS pct_pedidos,
    ROUND(100.0 * SUM(total) / SUM(SUM(total)) OVER (), 1) AS pct_valor
FROM raw.orders
GROUP BY status
ORDER BY valor_somado DESC;


-- -------------------------------------------------------------------------
-- 6. Distribuição temporal e registros com data futura
--
-- CURRENT_DATE é a referência: pedido criado depois de hoje não pode
-- ter acontecido. Se existir, a coluna de data não é confiável como
-- marca do momento do evento.
-- -------------------------------------------------------------------------

SELECT
    EXTRACT(YEAR FROM created_at)::int                    AS ano,
    COUNT(*)                                              AS pedidos,
    COUNT(*) FILTER (WHERE created_at > CURRENT_DATE)     AS com_data_futura
FROM raw.orders
GROUP BY ano
ORDER BY ano;


-- -------------------------------------------------------------------------
-- 7. Painel de integridade
--
-- Cada linha é uma hipótese de defeito. Zero significa que a hipótese
-- foi testada e não se confirmou — o que também é resultado.
-- -------------------------------------------------------------------------

SELECT
    COUNT(*)                                                     AS linhas,
    COUNT(*) - COUNT(DISTINCT id)                                AS ids_duplicados,
    COUNT(*) - COUNT(DISTINCT order_number)                      AS numeros_duplicados,
    COUNT(*) FILTER (WHERE total <= 0)                           AS total_zero_ou_negativo,
    COUNT(*) FILTER (WHERE discount_amount > subtotal)           AS desconto_maior_que_subtotal,
    COUNT(*) FILTER (WHERE total <> subtotal - discount_amount)  AS aritmetica_inconsistente,
    COUNT(*) FILTER (WHERE updated_at < created_at)              AS atualizado_antes_de_criado,
    COUNT(*) FILTER (WHERE placed_at = created_at)               AS placed_igual_created
FROM raw.orders;


-- -------------------------------------------------------------------------
-- 8. Outliers em "total" pelo critério do intervalo interquartil
--
-- Regra de Tukey: é atípico o que estiver a mais de 1,5 IQR fora dos
-- quartis. É um critério estatístico, não uma opinião sobre o valor.
-- -------------------------------------------------------------------------

WITH limites AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY total) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total) AS q3
    FROM raw.orders
)
SELECT
    l.q1,
    l.q3,
    l.q3 - l.q1                                   AS iqr,
    l.q1 - 1.5 * (l.q3 - l.q1)                    AS limite_inferior,
    l.q3 + 1.5 * (l.q3 - l.q1)                    AS limite_superior,
    COUNT(*) FILTER (
        WHERE o.total > l.q3 + 1.5 * (l.q3 - l.q1)
           OR o.total < l.q1 - 1.5 * (l.q3 - l.q1)
    )                                             AS pedidos_atipicos
FROM raw.orders o
CROSS JOIN limites l
GROUP BY l.q1, l.q3;
