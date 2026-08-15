"""
product_recommender.py — recomendação por similaridade de cosseno.

Constrói uma matriz binária cliente x produto a partir do histórico de
compras e ranqueia os produtos mais parecidos com um item de referência,
medindo o quanto compartilham a mesma base de compradores.

Lê os CSVs diretamente para que o script rode sem depender de banco.
"""

import argparse
from pathlib import Path

import numpy as np
import pandas as pd

PRODUTO_REFERENCIA = "Motor de Popa 1949"
TOP_N = 5


def carregar_matriz(diretorio: Path) -> tuple[pd.DataFrame, pd.Series]:
    """
    Matriz binária de clientes (linhas) por produtos (colunas).

    A célula vale 1 se o cliente comprou o produto ao menos uma vez e 0
    caso contrário — quantidade é ignorada de propósito. O que interessa
    é quem comprou o quê, não quanto.

    order_items registra a variante, então é preciso subir até o produto
    antes de montar a matriz.
    """
    produtos = pd.read_csv(diretorio / "products.csv", encoding="utf-8")
    variantes = pd.read_csv(diretorio / "product_variants.csv", encoding="utf-8")
    pedidos = pd.read_csv(diretorio / "orders.csv", encoding="utf-8")
    itens = pd.read_csv(diretorio / "order_items.csv", encoding="utf-8")

    compras = (
        itens[["order_id", "product_variant_id"]]
        .merge(
            variantes[["id", "product_id"]],
            left_on="product_variant_id",
            right_on="id",
        )
        .merge(
            pedidos[["id", "customer_id"]],
            left_on="order_id",
            right_on="id",
            suffixes=("_variante", "_pedido"),
        )
    )

    matriz = (
        pd.crosstab(compras["customer_id"], compras["product_id"])
        .clip(upper=1)
        .astype(np.int8)
    )

    nomes = produtos.set_index("id")["name"]
    return matriz, nomes


def similaridade_cosseno(matriz: pd.DataFrame) -> pd.DataFrame:
    """
    Similaridade de cosseno entre colunas (produto x produto).

    Normalizando cada coluna para comprimento 1, o produto escalar entre
    duas colunas passa a ser o próprio cosseno do ângulo entre elas. Para
    vetores binários isso equivale a
    |compradores em comum| / raiz(|compradores A| * |compradores B|).
    """
    m = matriz.to_numpy(dtype=np.float64)
    normas = np.linalg.norm(m, axis=0)
    normas[normas == 0] = 1.0                      # produto sem comprador
    unitaria = m / normas
    return pd.DataFrame(
        unitaria.T @ unitaria,
        index=matriz.columns,
        columns=matriz.columns,
    )


def resolver_produto(nomes: pd.Series, nome: str) -> int:
    ids = nomes.index[nomes == nome].tolist()
    if not ids:
        raise SystemExit(f"Produto não encontrado: {nome!r}")
    if len(ids) > 1:
        raise SystemExit(
            f"Nome ambíguo: {nome!r} corresponde aos ids {ids}. "
            f"Informe o id desejado."
        )
    return ids[0]


def ranquear(similaridades: pd.DataFrame, matriz: pd.DataFrame,
             nomes: pd.Series, referencia: int, top_n: int) -> pd.DataFrame:
    linha = similaridades.loc[referencia].drop(index=referencia)
    melhores = linha.nlargest(top_n)

    compradores_ref = matriz[referencia] == 1
    return pd.DataFrame({
        "product_id": melhores.index,
        "produto": nomes.reindex(melhores.index).to_numpy(),
        "similaridade": melhores.to_numpy().round(4),
        "clientes_em_comum": [
            int((compradores_ref & (matriz[p] == 1)).sum()) for p in melhores.index
        ],
        "compradores": [int(matriz[p].sum()) for p in melhores.index],
    }).reset_index(drop=True)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Recomenda produtos por similaridade de cosseno."
    )
    parser.add_argument("--entrada", type=Path, default=Path("data/raw"))
    parser.add_argument("--produto", default=PRODUTO_REFERENCIA)
    parser.add_argument("--top", type=int, default=TOP_N)
    args = parser.parse_args()

    matriz, nomes = carregar_matriz(args.entrada)
    referencia = resolver_produto(nomes, args.produto)
    similaridades = similaridade_cosseno(matriz)
    ranking = ranquear(similaridades, matriz, nomes, referencia, args.top)

    clientes, produtos = matriz.shape
    print(f"Matriz: {clientes} clientes x {produtos} produtos "
          f"(densidade {matriz.to_numpy().mean():.1%})")
    print(f"Referência: {args.produto} (id {referencia}, "
          f"{int(matriz[referencia].sum())} compradores)\n")
    print(f"{args.top} produtos mais similares:")
    print(ranking.to_string(index=False))


if __name__ == "__main__":
    main()
