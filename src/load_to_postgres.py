"""
load_to_postgres.py — carga dos CSVs no PostgreSQL.

Lê os arquivos de um diretório e os insere nas tabelas correspondentes do
schema `raw`, sem qualquer transformação: o conteúdo vai do arquivo para o
banco byte a byte.

Pré-requisito: as tabelas já devem existir. Execute antes o
sql/ddl/schema.sql gerado por src/infer_schema.py.
"""

import argparse
import csv
import os
from pathlib import Path

import psycopg
from dotenv import load_dotenv

SCHEMA = "raw"


# --- Conexão --------------------------------------------------------------

def conectar() -> psycopg.Connection:
    """Credenciais vêm do .env, que não é versionado."""
    load_dotenv()
    return psycopg.connect(
        host=os.getenv("PGHOST", "localhost"),
        port=os.getenv("PGPORT", "5432"),
        dbname=os.getenv("PGDATABASE"),
        user=os.getenv("PGUSER"),
        password=os.getenv("PGPASSWORD"),
        client_encoding="UTF8",
    )


def tabelas_existentes(conexao: psycopg.Connection) -> set[str]:
    with conexao.cursor() as cursor:
        cursor.execute(
            "SELECT table_name FROM information_schema.tables "
            "WHERE table_schema = %s",
            (SCHEMA,),
        )
        return {linha[0] for linha in cursor.fetchall()}


def conferir_pre_requisitos(
    conexao: psycopg.Connection, arquivos: list[Path]
) -> None:
    """
    Falha cedo e com instrução: melhor parar aqui do que descobrir no meio
    da carga que metade das tabelas não existe.
    """
    existentes = tabelas_existentes(conexao)
    faltando = sorted(f.stem for f in arquivos if f.stem not in existentes)

    if faltando:
        raise SystemExit(
            f"Tabelas ausentes no schema '{SCHEMA}': {', '.join(faltando)}\n"
            f"Execute sql/ddl/schema.sql antes "
            f"(gerado por src/infer_schema.py)."
        )


# --- Carga ----------------------------------------------------------------

def ler_cabecalho(caminho: Path) -> list[str]:
    with caminho.open(newline="", encoding="utf-8") as arquivo:
        return next(csv.reader(arquivo))


def carregar_arquivo(conexao: psycopg.Connection, caminho: Path) -> int:
    """
    Envia o arquivo via COPY e devolve a contagem de linhas na tabela.

    O parsing fica a cargo do PostgreSQL: o Python só repassa os bytes.
    """
    tabela = caminho.stem
    colunas = ", ".join(f'"{c}"' for c in ler_cabecalho(caminho))

    comando = (
        f'COPY {SCHEMA}."{tabela}" ({colunas}) '
        f"FROM STDIN WITH (FORMAT csv, HEADER true)"
    )

    with conexao.cursor() as cursor:
        # Torna a carga repetível: rodar duas vezes não duplica linhas.
        cursor.execute(f'TRUNCATE TABLE {SCHEMA}."{tabela}"')

        with cursor.copy(comando) as copia, caminho.open("rb") as arquivo:
            while bloco := arquivo.read(65536):
                copia.write(bloco)

        cursor.execute(f'SELECT COUNT(*) FROM {SCHEMA}."{tabela}"')
        return cursor.fetchone()[0]


# --- Validação e execução -------------------------------------------------

def contar_linhas_csv(caminho: Path) -> int:
    """Linhas de dados, sem o cabeçalho."""
    with caminho.open(newline="", encoding="utf-8") as arquivo:
        leitor = csv.reader(arquivo)
        next(leitor, None)
        return sum(1 for _ in leitor)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Carrega os CSVs de um diretório nas tabelas do schema raw."
    )
    parser.add_argument("--entrada", type=Path, default=Path("data/raw"))
    args = parser.parse_args()

    arquivos = sorted(args.entrada.glob("*.csv"))
    if not arquivos:
        raise SystemExit(f"Nenhum CSV encontrado em {args.entrada}")

    with conectar() as conexao:
        conferir_pre_requisitos(conexao, arquivos)

        total = 0
        divergencias = []

        for caminho in arquivos:
            esperado = contar_linhas_csv(caminho)
            carregado = carregar_arquivo(conexao, caminho)
            total += carregado

            if carregado != esperado:
                divergencias.append((caminho.name, esperado, carregado))
            situacao = "ok" if carregado == esperado else "DIVERGENTE"
            print(f"  {caminho.stem:28} {carregado:>7} linhas  {situacao}")

        if divergencias:
            detalhe = "\n".join(
                f"  {nome}: esperado {e}, carregado {c}"
                for nome, e, c in divergencias
            )
            raise SystemExit(f"\nCarga abortada — contagem divergente:\n{detalhe}")

    print(f"\n{len(arquivos)} tabelas carregadas, {total} linhas no total.")


if __name__ == "__main__":
    main()
