"""
infer_schema.py — geração automática de DDL a partir de arquivos CSV.

Lê os CSVs de um diretório, detecta o tipo de cada coluna analisando
TODAS as linhas e gera um único schema.sql para PostgreSQL.

Usa apenas biblioteca padrão: csv, os, re, datetime, argparse, pathlib.
"""

import re
from datetime import datetime

# --- Reconhecimento 

RE_INTEIRO = re.compile(r"^[+-]?\d+$")
RE_DECIMAL = re.compile(r"^[+-]?\d+\.\d+$")

BOOLEANOS = {"TRUE", "FALSE", "T", "F"}

FORMATO_DATA = "%Y-%m-%d"
FORMATO_TIMESTAMP = "%Y-%m-%d %H:%M:%S"


# --- Tipo 

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