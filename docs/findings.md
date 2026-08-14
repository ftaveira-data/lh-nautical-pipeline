# Achados da análise exploratória

## raw.orders

A tabela tem integridade estrutural boa, mas alguns pontos precisam ser
tratados antes de usar em análise.

### Volume e período

| Métrica | Valor |
|---|---|
| Linhas | 48.998 |
| Colunas | 13 |
| `created_at` mínimo | 2020-01-01 01:19:28 |
| `created_at` máximo | 2026-12-31 23:43:09 |

### Distribuição de `total`

| Métrica | Valor |
|---|---|
| Mínimo | R$ 32,62 |
| Máximo | R$ 127.262,02 |
| Média | R$ 28.704,99 |
| Mediana | R$ 25.917,84 |
| Q1 / Q3 | R$ 13.171,24 / R$ 40.941,88 |

### Outliers

Usando o critério de 1,5×IQR, 452 pedidos (0,9%) ficam acima de
R$ 82.597,85. Nenhum abaixo do limite inferior.

Não parecem erros. Média e mediana são próximas o suficiente para indicar
que não há valores extremos distorcendo o conjunto. O maior pedido é
plausível para uma loja que vende de bússola a motor de popa. Também não há
nenhum `total` zerado ou negativo, e a conta
`total = subtotal - discount_amount` fecha nas 48.998 linhas.

### Qualidade

Hipóteses de defeito testadas, todas com resultado zero:

- `id` duplicado
- `order_number` duplicado
- desconto maior que subtotal
- `updated_at` anterior a `created_at`

A única coluna com nulo é `salesperson_id`: 24.131 pedidos, 49,3% do total.
O padrão não é aleatório — 70,3% de ausência no e-commerce e 0% nas vendas
presenciais. Venda em loja tem vendedor, venda online não. Não é dado
faltando, é o desenho do processo.

O inverso chama mais atenção: 29,7% dos pedidos de e-commerce têm vendedor
preenchido. Pode ser venda assistida, mas é pergunta para o negócio.

### Pontos que comprometem a leitura temporal

- **4.281 pedidos (8,7%) têm `created_at` depois da data atual**, chegando
  a 31/12/2026. Data de criação no futuro não descreve algo que aconteceu.
- **`placed_at` e `created_at` são iguais nas 48.998 linhas.** As duas
  colunas deveriam significar coisas diferentes.
- O crescimento anual é liso demais: 4.466 pedidos em 2020 subindo até
  10.268 em 2026 sem nenhuma queda. Varejo real oscila.

### A armadilha do `status`

| Status | Pedidos | Valor somado | % do valor |
|---|---:|---:|---:|
| paid | 34.365 | R$ 985.741.294,26 | 70,1% |
| confirmed | 7.335 | R$ 213.625.785,28 | 15,2% |
| cancelled | 4.847 | R$ 137.418.441,62 | 9,8% |
| draft | 2.451 | R$ 69.701.680,64 | 5,0% |

Cancelados e rascunhos têm `total` preenchido como qualquer outro pedido e
somam 14,8% do valor (R$ 207,1 milhões). Um `SUM(total)` sem filtro de
status erra o faturamento em cerca de 17%.

### Conclusão

A tabela sustenta análise, desde que três decisões sejam explícitas: filtrar
por status, declarar a data de corte adotada e escolher entre `placed_at` e
`created_at`.

Sozinha ela não tem produto, categoria nem quantidade — isso está em
`order_items`, `product_variants`, `products` e `categories`. Qualquer
análise de mix ou margem exige percorrer essa cadeia de chaves.
