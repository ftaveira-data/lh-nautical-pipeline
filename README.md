# LH Nautical — pipeline analítico

Pipeline de ponta a ponta sobre os dados de uma varejista de equipamentos
náuticos: inferência de schema a partir dos CSVs, carga em PostgreSQL,
modelagem dimensional em views e um relatório em Power BI.

Todo o ambiente sobe com Docker. Nenhuma etapa depende de configuração manual
do banco.

---

## Arquitetura

```
data/raw/*.csv
      │
      │  src/infer_schema.py          leitura integral, tipagem por eliminação
      ▼
sql/ddl/schema.sql                    24 tabelas, 21 chaves primárias
      │
      │  src/load_to_postgres.py      COPY FROM STDIN, transação única
      ▼
schema raw                            433.424 linhas, cópia fiel do arquivo
      │
      │  sql/analytics/*.sql          views dimensionais
      ▼
schema analytics                      5 dimensões + 3 fatos
      │
      ▼
powerbi/                              relatório de 7 páginas
```

A separação em dois schemas é deliberada. O `raw` guarda o dado como ele
chegou, sem nenhuma transformação — é a referência para auditar qualquer
número. O `analytics` guarda as decisões de modelagem e limpeza, todas
documentadas no cabeçalho de cada view.

---

## Pré-requisitos

| Ferramenta | Versão |
|---|---|
| Docker Desktop | qualquer versão com `docker compose` |
| Python | 3.13 |
| Power BI Desktop | opcional, apenas para abrir o `.pbix` |

Os CSVs de origem devem estar em `data/raw/`. Eles não são versionados.

---

## Execução

### 1. Subir o banco

```bash
docker compose up -d
```

Sobe um PostgreSQL 16 no container `lh_nautical_db`, exposto na porta
**5444** do host. A porta não é a padrão de propósito, para não conflitar com
uma instalação local de PostgreSQL.

O serviço tem `healthcheck`: aguarde o container ficar `healthy` antes de
seguir.

```bash
docker compose ps
```

### 2. Configurar as credenciais

```bash
cp .env.example .env
```

Edite o `.env` com a senha definida no `docker-compose.yml`. O arquivo está no
`.gitignore` e nunca deve ser versionado.

### 3. Instalar as dependências

```bash
python -m venv .venv
.venv\Scripts\activate          # Windows
pip install -r requirements.txt
```

### 4. Gerar o schema

```bash
python src/infer_schema.py
```

Lê todos os CSVs de `data/raw/` e escreve `sql/ddl/schema.sql`.

Este script usa **apenas a biblioteca padrão** do Python — sem pandas, dask ou
polars. A tipagem é feita por eliminação de candidatos, lendo todas as linhas
de cada arquivo. Amostragem não serve aqui: afirmar o tipo de uma coluna é uma
afirmação universal, e basta um valor contrário para derrubá-la.

Parâmetros opcionais:

```bash
python src/infer_schema.py --entrada data/raw --saida sql/ddl/schema.sql
```

### 5. Criar as tabelas

```bash
docker exec -i lh_nautical_db psql -U lighthouse -d lh_nautical < sql/ddl/schema.sql
```

### 6. Carregar os dados

```bash
python src/load_to_postgres.py
```

Carrega as 24 tabelas via `COPY FROM STDIN` dentro de uma única transação. Ao
final, compara a contagem de linhas de cada CSV com a da tabela e aborta se
houver divergência.

Saída esperada: **433.424 linhas**.

### 7. Criar as views analíticas

```bash
for %f in (sql\analytics\*.sql) do docker exec -i lh_nautical_db psql -U lighthouse -d lh_nautical < %f
```

No Linux ou Git Bash:

```bash
for f in sql/analytics/*.sql; do
  docker exec -i lh_nautical_db psql -U lighthouse -d lh_nautical < "$f"
done
```

Ordem importa: `dim_calendar.sql` cria o schema `analytics` e deve rodar
primeiro.

### 8. Rodar as análises

```bash
python src/demand_forecast.py
python src/product_recommender.py
```

Ambos leem os CSVs diretamente e rodam sem depender do banco.

```bash
python src/demand_forecast.py --produto "Bússola de Bordo 702" --janela 3
python src/product_recommender.py --produto "Motor de Popa 1949" --top 5
```

---

## Estrutura

```
lh-nautical-pipeline/
├── docker-compose.yml          PostgreSQL 16 na porta 5444
├── requirements.txt
├── .env.example
│
├── data/raw/                   CSVs de origem (não versionados)
│
├── src/
│   ├── infer_schema.py         inferência de tipos, stdlib apenas
│   ├── load_to_postgres.py     carga via COPY
│   ├── demand_forecast.py      média móvel de 3 meses
│   └── product_recommender.py  similaridade de cosseno
│
├── sql/
│   ├── ddl/schema.sql          gerado por infer_schema.py
│   ├── exploratory/            perfilamento de orders
│   ├── analysis/               consultas de negócio
│   └── analytics/              views dimensionais
│
├── powerbi/
│   ├── lh-nautical-theme.json  tema visual
│   └── *.pdf                   exportação do relatório
│
└── docs/
    └── findings.md             achados da análise exploratória
```

---

## Modelo dimensional

Constelação de fatos com dimensões conformadas.

**Dimensões**

| View | Grão | Observação |
|---|---|---|
| `dim_calendar` | dia | cobre todos os fatos, inclusive devoluções posteriores à última venda |
| `dim_customer` | cliente | |
| `dim_product` | **variante** | `order_items` referencia a variante, não o produto |
| `dim_location` | local | lojas e armazéns |
| `dim_employee` | funcionário | inclui membro `-1` "Sem vendedor" |

**Fatos**

| View | Grão | Responde |
|---|---|---|
| `fct_orders` | pedido | faturamento, desconto, ticket médio |
| `fct_order_items` | item | mix, volume, receita por categoria |
| `fct_returns` | item devolvido | devoluções e motivos |

### Decisões que valem registro

**O grão de `dim_product` é a variante, não o produto.** São 500 produtos e
1.009 variantes. Como `order_items` guarda `product_variant_id`, a dimensão
precisa do mesmo grão da chave que o fato carrega. No grão de produto, SKU,
preço e peso não teriam onde morar.

**Categoria e marca entram achatadas na dimensão de produto.** Mantê-las
separadas seria snowflake, que degrada o desempenho no Power BI sem ganho
relevante de espaço — são 14 categorias e 4 marcas.

**Nenhum pedido é excluído dos fatos.** Cancelados e rascunhos permanecem, e a
coluna `eh_receita_realizada` deixa o filtro explícito para quem consulta.
Esses dois status somam 14,8% do valor bruto; escondê-los na view tornaria a
diferença invisível.

**A limpeza mora nas views, não na raw.** `fct_returns` normaliza 32 variações
de motivo em 7 categorias reais, e guarda as duas colunas — `motivo_original`
e `motivo` — para que a transformação seja auditável sem sair do modelo.

**`dim_calendar` cobre mais que o período de vendas.** Existem devoluções
posteriores à última venda registrada. Um calendário construído só a partir
de `orders` deixaria essas linhas órfãs. A coluna `eh_periodo_de_vendas`
marca o recorte que as análises de venda usam.

---

## Relatório

Sete páginas: capa, visão geral, vendas, clientes, produtos, qualidade e
documentação do modelo.

A página de documentação é gerada pelas funções `INFO.VIEW.*` do DAX — ela lê
o próprio modelo semântico e se atualiza sozinha conforme novas medidas são
criadas.

Tema visual em `powerbi/lh-nautical-theme.json`.

---

## Notas de operação

**Parar o ambiente sem perder os dados:**

```bash
docker compose down
```

**Parar e apagar tudo, inclusive o volume:**

```bash
docker compose down -v
```

O volume se chama `lh_nautical_pgdata`. Enquanto ele existir, o banco é
recriado com os dados intactos.

**Recarregar do zero:** os scripts de carga fazem `TRUNCATE` antes de cada
tabela, então `load_to_postgres.py` pode ser executado quantas vezes for
necessário sem duplicar linhas.
