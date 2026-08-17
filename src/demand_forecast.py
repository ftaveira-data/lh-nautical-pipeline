"""
demand_forecast.py — previsão de demanda mensal por média móvel.

Baseline de 3 meses treinado até 31/12/2025 e avaliado no primeiro
trimestre de 2026, para um produto específico.

Lê os CSVs diretamente para que o script rode sem depender de banco.
"""

import argparse
from pathlib import Path

import pandas as pd

PRODUTO = "Bússola de Bordo 702"
FIM_DO_TREINO = "2025-12"
MESES_DE_TESTE = ["2026-01", "2026-02", "2026-03"]
JANELA = 3


def carregar_serie_mensal(diretorio: Path, produto: str) -> pd.Series:
    """
    Unidades vendidas por mês do produto informado.

    Existe mais de um product_id com o mesmo nome no catálogo, então o
    filtro é por nome e todas as variantes encontradas são somadas: a
    demanda do produto é o que sai com aquele nome, independente de
    quantos cadastros existam por trás.
    """
    produtos = pd.read_csv(diretorio / "products.csv", encoding="utf-8")
    variantes = pd.read_csv(diretorio / "product_variants.csv", encoding="utf-8")
    pedidos = pd.read_csv(diretorio / "orders.csv", encoding="utf-8")
    itens = pd.read_csv(diretorio / "order_items.csv", encoding="utf-8")

    ids_produto = produtos.loc[produtos["name"] == produto, "id"]
    if ids_produto.empty:
        raise SystemExit(f"Produto não encontrado no catálogo: {produto!r}")

    ids_variante = variantes.loc[
        variantes["product_id"].isin(ids_produto), "id"
    ]

    vendas = (
        itens.loc[itens["product_variant_id"].isin(ids_variante)]
        .merge(
            pedidos[["id", "placed_at"]].rename(columns={"id": "order_id"}),
            on="order_id",
        )
    )

    vendas["mes"] = pd.to_datetime(vendas["placed_at"]).dt.to_period("M")
    serie = vendas.groupby("mes")["quantity"].sum()

    # Meses sem nenhuma venda não geram linha no agrupamento. Precisam
    # entrar como zero, senão a média móvel pula buracos do calendário.
    periodo = pd.period_range(serie.index.min(), serie.index.max(), freq="M")
    return serie.reindex(periodo, fill_value=0).astype(int)


def prever(serie: pd.Series, fim_do_treino: str, meses: list[str],
           janela: int) -> pd.Series:
    """
    Média das últimas `janela` observações do período de treino.

    O corte é aplicado antes de qualquer cálculo: nenhum valor posterior a
    `fim_do_treino` entra na média, nem mesmo os meses já previstos. É o
    que mantém a separação entre treino e teste.
    """
    treino = serie.loc[: pd.Period(fim_do_treino, freq="M")]
    if len(treino) < janela:
        raise SystemExit(
            f"Série de treino tem {len(treino)} meses, "
            f"insuficiente para uma janela de {janela}."
        )

    media_movel = treino.tail(janela).mean()
    indice = pd.PeriodIndex(meses, freq="M")
    return pd.Series(media_movel, index=indice, name="previsto")


def avaliar(previsto: pd.Series, real: pd.Series) -> pd.DataFrame:
    comparacao = pd.DataFrame({"previsto": previsto, "real": real})
    comparacao["erro_absoluto"] = (comparacao["real"] - comparacao["previsto"]).abs()
    return comparacao


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Previsão de demanda mensal por média móvel."
    )
    parser.add_argument("--entrada", type=Path, default=Path("data/raw"))
    parser.add_argument("--produto", default=PRODUTO)
    parser.add_argument("--janela", type=int, default=JANELA)
    args = parser.parse_args()

    serie = carregar_serie_mensal(args.entrada, args.produto)
    treino = serie.loc[: pd.Period(FIM_DO_TREINO, freq="M")]

    previsto = prever(serie, FIM_DO_TREINO, MESES_DE_TESTE, args.janela)
    real = serie.reindex(previsto.index, fill_value=0).rename("real")
    comparacao = avaliar(previsto, real)

    mae = comparacao["erro_absoluto"].mean()
    total_previsto = previsto.sum()

    print(f"Produto: {args.produto}")
    print(f"Série: {serie.index.min()} a {serie.index.max()} "
          f"({len(serie)} meses, {serie.sum()} unidades)")
    print(f"\nÚltimos {args.janela} meses de treino:")
    print(treino.tail(args.janela).to_string())
    print(f"\nMédia móvel = {treino.tail(args.janela).mean():.2f} unidades/mês")
    print("\nPrevisão x realizado:")
    print(comparacao.round(2).to_string())
    print(f"\nMAE .................. {mae:.2f} unidades")
    print(f"Total previsto no Q1 . {total_previsto:.2f} -> {round(total_previsto)}")
    print(f"Total realizado ...... {real.sum()}")


if __name__ == "__main__":
    main()
