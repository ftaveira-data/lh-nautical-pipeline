"""
infer_schema.py — geração automática de DDL a partir de arquivos CSV.

Lê os CSVs de um diretório, detecta o tipo de cada coluna analisando
TODAS as linhas e gera um único schema.sql para PostgreSQL.

Usa apenas biblioteca padrão: csv, os, re, datetime, argparse, pathlib.
"""

import re
from datetime import datetime
import csv
import re
from pathlib import Path
from datetime import datetime

# --- Padrao Reconhecimento 

RE_INTEIRO = re.compile(r"^[+-]?\d+$")
RE_DECIMAL = re.compile(r"^[+-]?\d+\.\d+$")
RE_IDENTIFICADOR = re.compile(
    r"(^|_)(cpf|cnpj|tax_id|ncm_code|barcode_ean|postal_code|number)$"
)

BOOLEANOS = {"TRUE", "FALSE", "T", "F"}

FORMATO_DATA = "%Y-%m-%d"
FORMATO_TIMESTAMP = "%Y-%m-%d %H:%M:%S"


# --- Testar Tipo 

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

# --- Acumulador por coluna 

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
    """
    Acumula evidências sobre uma coluna sem guardar os valores.
    A memória não cresce com o tamanho do arquivo.
    """

    def __init__(self, nome: str):
        self.nome = nome
        self.candidatos = set(VERIFICADORES)  # tudo é possível no início
        self.aceita_nulo = False
        self.viu_algum_valor = False
        self.maior_magnitude = 0
        self.max_digitos_inteiros = 0
        self.max_casas_decimais = 0
        self.max_comprimento = 0

    def observar(self, valor: str) -> None:
        if valor == "":
            # Vazio é ausência de valor, não valor de tipo errado.
            # Não elimina candidato nenhum: só marca a coluna como nullable.
            self.aceita_nulo = True
            return

        self.viu_algum_valor = True
        self.max_comprimento = max(self.max_comprimento, len(valor))

        # O coração do algoritmo: sobrevive quem aceita este valor.
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

        return "TEXT"  # nenhum candidato sobreviveu    

# --- Leitura dos arquivos 

def listar_csvs(diretorio: Path) -> list[Path]:
    """Ordenado para que a mesma entrada gere sempre o mesmo schema.sql."""
    return sorted(diretorio.glob("*.csv"))


def nome_tabela(caminho: Path) -> str:
    """orders.csv -> orders"""
    return caminho.stem.lower()


def analisar_csv(caminho: Path) -> tuple[list[Coluna], int]:
    """
    Percorre o arquivo inteiro uma vez, alimentando um acumulador por coluna.

    csv.reader devolve uma linha por vez: o arquivo nunca fica inteiro
    na memória, então o custo não cresce com o tamanho do CSV.
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