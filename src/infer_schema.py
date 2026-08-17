"""
infer_schema.py — geração automática de DDL a partir de arquivos CSV.

Lê os CSVs de um diretório, detecta o tipo de cada coluna analisando
TODAS as linhas e gera um único schema.sql para PostgreSQL.

Usa apenas biblioteca padrão: csv, os, re, datetime, argparse, pathlib.
"""

import argparse
import csv
import re
from datetime import datetime
from pathlib import Path


# --- Padrões de reconhecimento -------------------------------------------

RE_INTEIRO = re.compile(r"^[+-]?\d+$")
RE_DECIMAL = re.compile(r"^[+-]?\d+\.\d+$")
RE_IDENTIFICADOR = re.compile(
    r"(^|_)(cpf|cnpj|tax_id|ncm_code|barcode_ean|postal_code|number)$"
)

BOOLEANOS = {"TRUE", "FALSE", "T", "F"}

FORMATO_DATA = "%Y-%m-%d"
FORMATO_TIMESTAMP = "%Y-%m-%d %H:%M:%S"


# --- Testadores de tipo ---------------------------------------------------

def _tem_zero_a_esquerda(digitos: str) -> bool:
    """'007' sim, '0' não, '70' não."""
    return len(digitos) > 1 and digitos.startswith("0")


def eh_booleano(valor: str) -> bool:
    return valor.upper() in BOOLEANOS


def eh_inteiro(valor: str) -> bool:
    """
    Inteiro puro. Recusa zero à esquerda de propósito:
    barcode_ean = '0812356442423' é identificador, não número.
    Convertê-lo para INTEGER destruiria o dado.
    """
    if not RE_INTEIRO.match(valor):
        return False
    return not _tem_zero_a_esquerda(valor.lstrip("+-"))


def eh_decimal(valor: str) -> bool:
    if not RE_DECIMAL.match(valor):
        return False
    parte_inteira = valor.lstrip("+-").split(".")[0]
    return not _tem_zero_a_esquerda(parte_inteira)


def eh_numerico(valor: str) -> bool:
    """NUMERIC no PostgreSQL cobre inteiros e decimais."""
    return eh_inteiro(valor) or eh_decimal(valor)


def eh_data(valor: str) -> bool:
    """
    Regex sozinha não basta: '2023-02-30' casa com o padrão mas não existe.
    Quem valida de verdade é o strptime, que conhece o calendário.
    """
    try:
        datetime.strptime(valor, FORMATO_DATA)
        return True
    except ValueError:
        return False


def eh_timestamp(valor: str) -> bool:
    try:
        datetime.strptime(valor, FORMATO_TIMESTAMP)
        return True
    except ValueError:
        return False


# --- Acumulador por coluna ------------------------------------------------

VERIFICADORES = {
    "BOOLEAN": eh_booleano,
    "INTEGER": eh_inteiro,
    "NUMERIC": eh_numerico,
    "DATE": eh_data,
    "TIMESTAMP": eh_timestamp,
}

# Do mais específico para o mais genérico. Uma coluna de inteiros sobrevive
# como INTEGER e NUMERIC ao mesmo tempo; a ordem decide quem vence.
PRECEDENCIA = ["BOOLEAN", "INTEGER", "NUMERIC", "TIMESTAMP", "DATE"]

LIMITE_INTEGER = 2_147_483_647


class Coluna:
    """Acumula evidências sobre uma coluna sem guardar os valores lidos."""

    def __init__(self, nome: str):
        self.nome = nome
        self.candidatos = set(VERIFICADORES)
        self.aceita_nulo = False
        self.viu_algum_valor = False
        self.maior_magnitude = 0
        self.max_digitos_inteiros = 0
        self.max_casas_decimais = 0
        self.max_comprimento = 0
        # Só rastreia unicidade em colunas 'id': guardar todos os valores de
        # todas as colunas custaria memória sem necessidade.
        self.valores_vistos = set() if nome.lower() == "id" else None
        self.tem_duplicata = False

    def observar(self, valor: str) -> None:
        if valor == "":
            # Vazio é ausência de valor, não valor de tipo errado: marca a
            # coluna como nullable sem eliminar nenhum candidato.
            self.aceita_nulo = True
            return

        self.viu_algum_valor = True
        self.max_comprimento = max(self.max_comprimento, len(valor))

        if self.valores_vistos is not None:
            if valor in self.valores_vistos:
                self.tem_duplicata = True
            else:
                self.valores_vistos.add(valor)

        # Eliminação: sobrevive o tipo que aceita este valor.
        self.candidatos = {
            tipo for tipo in self.candidatos if VERIFICADORES[tipo](valor)
        }

        if "NUMERIC" in self.candidatos or "INTEGER" in self.candidatos:
            self._medir_numero(valor)

    def _medir_numero(self, valor: str) -> None:
        corpo = valor.lstrip("+-")
        if "." in corpo:
            inteira, decimal = corpo.split(".")
        else:
            inteira, decimal = corpo, ""
        self.max_digitos_inteiros = max(self.max_digitos_inteiros, len(inteira))
        self.max_casas_decimais = max(self.max_casas_decimais, len(decimal))
        if not decimal:
            self.maior_magnitude = max(self.maior_magnitude, abs(int(corpo)))

    def tipo_sql(self) -> str:
        if RE_IDENTIFICADOR.search(self.nome.lower()):
            return "TEXT"

        if not self.viu_algum_valor:
            return "TEXT"

        for tipo in PRECEDENCIA:
            if tipo in self.candidatos:
                if tipo == "INTEGER":
                    return "BIGINT" if self.maior_magnitude > LIMITE_INTEGER else "INTEGER"
                if tipo == "NUMERIC":
                    precisao = self.max_digitos_inteiros + self.max_casas_decimais
                    return f"NUMERIC({precisao}, {self.max_casas_decimais})"
                return tipo

        return "TEXT"

    def pode_ser_chave(self) -> bool:
        """
        Afirma apenas o que os dados provam: coluna chamada 'id',
        sem repetição e sem vazio em nenhuma linha do arquivo.
        """
        return (
            self.valores_vistos is not None
            and not self.tem_duplicata
            and not self.aceita_nulo
            and self.viu_algum_valor
        )


# --- Leitura dos arquivos -------------------------------------------------

def listar_csvs(diretorio: Path) -> list[Path]:
    """Ordenado para que a mesma entrada gere sempre o mesmo schema.sql."""
    return sorted(diretorio.glob("*.csv"))


def nome_tabela(caminho: Path) -> str:
    """orders.csv -> orders"""
    return caminho.stem.lower()


def analisar_csv(caminho: Path) -> tuple[list[Coluna], int]:
    """
    Percorre o arquivo inteiro uma vez, alimentando um acumulador por coluna.

    csv.reader devolve uma linha por vez: o arquivo nunca fica inteiro na
    memória, então o custo não cresce com o tamanho do CSV.
    """
    with caminho.open(newline="", encoding="utf-8") as arquivo:
        leitor = csv.reader(arquivo)

        try:
            cabecalho = next(leitor)
        except StopIteration:
            raise ValueError(f"{caminho.name}: arquivo vazio, sem cabeçalho")

        colunas = [Coluna(nome) for nome in cabecalho]
        total_linhas = 0

        # start=2 porque a linha 1 é o cabeçalho: o número reportado
        # em caso de erro precisa bater com o que o usuário vê no editor.
        for numero, linha in enumerate(leitor, start=2):
            if len(linha) != len(colunas):
                raise ValueError(
                    f"{caminho.name}: linha {numero} tem {len(linha)} campos, "
                    f"esperado {len(colunas)}"
                )
            total_linhas += 1
            for coluna, valor in zip(colunas, linha):
                coluna.observar(valor)

    return colunas, total_linhas


# --- Geração do DDL -------------------------------------------------------

SCHEMA_DESTINO = "raw"


def gerar_create_table(tabela: str, colunas: list[Coluna]) -> str:
    definicoes = []
    for coluna in colunas:
        nulidade = "" if coluna.aceita_nulo else " NOT NULL"
        definicoes.append(f'    "{coluna.nome}" {coluna.tipo_sql()}{nulidade}')

    chaves = [c.nome for c in colunas if c.pode_ser_chave()]
    if chaves:
        definicoes.append(f'    PRIMARY KEY ("{chaves[0]}")')

    corpo = ",\n".join(definicoes)
    return f'CREATE TABLE IF NOT EXISTS {SCHEMA_DESTINO}."{tabela}" (\n{corpo}\n);'


def gerar_schema(diretorio: Path) -> str:
    arquivos = listar_csvs(diretorio)
    if not arquivos:
        raise ValueError(f"nenhum CSV encontrado em {diretorio}")

    blocos = [
        "-- Gerado automaticamente por src/infer_schema.py.",
        "-- Tipos inferidos a partir de TODAS as linhas de cada arquivo.",
        f"-- Arquivos analisados: {len(arquivos)}",
        "",
        f"CREATE SCHEMA IF NOT EXISTS {SCHEMA_DESTINO};",
        "",
    ]

    for arquivo in arquivos:
        colunas, total = analisar_csv(arquivo)
        blocos.append(f"-- {arquivo.name}: {total} linhas")
        blocos.append(gerar_create_table(nome_tabela(arquivo), colunas))
        blocos.append("")

    return "\n".join(blocos)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Gera um schema.sql para PostgreSQL a partir de arquivos CSV."
    )
    parser.add_argument("--entrada", type=Path, default=Path("data/raw"))
    parser.add_argument("--saida", type=Path, default=Path("sql/ddl/schema.sql"))
    args = parser.parse_args()

    ddl = gerar_schema(args.entrada)
    args.saida.parent.mkdir(parents=True, exist_ok=True)
    args.saida.write_text(ddl, encoding="utf-8")

    print(f"Schema gerado em {args.saida}")


if __name__ == "__main__":
    main()
