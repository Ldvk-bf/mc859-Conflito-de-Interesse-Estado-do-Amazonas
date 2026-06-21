"""
Anonimiza nomes de pessoas em todos os CSVs do projeto.

Substitui nomes por um código pseudônimo estável via SHA-256 truncado:
  "JOAO SILVA" → "PES-3F7A2B"

O mesmo nome sempre gera o mesmo código → integridade das referências cruzadas preservada.
Todos os outros campos (orgao, cargo, cnpj, score, valor…) são mantidos intactos.

Saídas:
  data/neo4j_anonimizado/          — espelho de data/neo4j/
  data/dados_anonimizados/         — espelho de dados_base/ e dados_derivados/
"""

import csv
import hashlib
import shutil
from pathlib import Path

# ── Helpers ───────────────────────────────────────────────────────────────────

def pseudonimo(nome: str) -> str:
    """Hash SHA-256 truncado, estável e irreversível."""
    h = hashlib.sha256(nome.strip().upper().encode()).hexdigest()[:6].upper()
    return f"PES-{h}"


def anonimizar_csv(src: Path, dest: Path, colunas: list[str],
                   delimiter: str = ",") -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    with open(src, encoding="utf-8", newline="") as fin, \
         open(dest, "w", encoding="utf-8", newline="") as fout:
        reader = csv.DictReader(fin, delimiter=delimiter)
        writer = csv.DictWriter(fout, fieldnames=reader.fieldnames,
                                delimiter=delimiter)
        writer.writeheader()
        for row in reader:
            for col in colunas:
                if col in row and row[col].strip():
                    row[col] = pseudonimo(row[col])
            writer.writerow(row)
    linhas = sum(1 for _ in open(dest, encoding="utf-8")) - 1
    print(f"  ✓ {dest}  ({linhas:,} linhas)")


def copiar(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)
    print(f"  · {dest}  (copiado sem alteração)")


# ── Neo4j ─────────────────────────────────────────────────────────────────────

def processar_neo4j() -> None:
    src  = Path("data/neo4j")
    dest = Path("data/neo4j_anonimizado")

    print("\n── data/neo4j → data/neo4j_anonimizado ──")

    anonimizar_csv(
        src / "nodes/pessoa.csv",
        dest / "nodes/pessoa.csv",
        colunas=["pessoaId:ID(Pessoa)", "nome", "nome_normalizado"],
    )
    anonimizar_csv(
        src / "relationships/trabalha_em.csv",
        dest / "relationships/trabalha_em.csv",
        colunas=[":START_ID(Pessoa)"],
    )
    anonimizar_csv(
        src / "relationships/socio_de.csv",
        dest / "relationships/socio_de.csv",
        colunas=[":START_ID(Pessoa)"],
    )
    anonimizar_csv(
        src / "relationships/possivel_mesmo_que.csv",
        dest / "relationships/possivel_mesmo_que.csv",
        colunas=[":START_ID(Pessoa)", ":END_ID(Pessoa)"],
    )

    # Arquivos sem dados pessoais — cópia direta
    for f in ["nodes/empresa.csv", "nodes/orgao.csv",
              "relationships/firmou_contrato.csv"]:
        copiar(src / f, dest / f)


# ── dados_base ────────────────────────────────────────────────────────────────

def processar_dados_base() -> None:
    src  = Path("data/dados_base")
    dest = Path("data/dados_anonimizados/dados_base")

    print("\n── data/dados_base → data/dados_anonimizados/dados_base ──")

    # funcionarios: colunas "nome" e "nome_normalizado"
    anonimizar_csv(
        src / "nome_funcionario-orgao_publico(funcionarios).csv",
        dest / "nome_funcionario-orgao_publico(funcionarios).csv",
        colunas=["nome", "nome_normalizado"],
    )

    # socios (delimitador ;): coluna "nome_socio"
    anonimizar_csv(
        src / "nome_socio-empresa(socios).csv",
        dest / "nome_socio-empresa(socios).csv",
        colunas=["nome_socio"],
        delimiter=";",
    )

    # socios faltantes (delimitador ;): coluna "nome_socio"
    anonimizar_csv(
        src / "nome_socio-empresa(socios)_faltantes.csv",
        dest / "nome_socio-empresa(socios)_faltantes.csv",
        colunas=["nome_socio"],
        delimiter=";",
    )


# ── dados_derivados ───────────────────────────────────────────────────────────

def processar_dados_derivados() -> None:
    src  = Path("data/dados_derivados")
    dest = Path("data/dados_anonimizados/dados_derivados")

    print("\n── data/dados_derivados → data/dados_anonimizados/dados_derivados ──")

    for nome_arquivo in [
        "nome_funcionario-nome_socio.csv",
        "nome_funcionario-nome_socio (old_matchs).csv",
    ]:
        origem = src / nome_arquivo
        if not origem.exists():
            print(f"  ⚠ não encontrado: {origem}")
            continue
        anonimizar_csv(
            origem,
            dest / nome_arquivo,
            colunas=["nome_funcionario_normalizado", "nome_socio_normalizado"],
        )


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print("Iniciando anonimização...\n")
    processar_neo4j()
    processar_dados_base()
    processar_dados_derivados()
    print("\nConcluído.")
    print("  data/neo4j_anonimizado/")
    print("  data/dados_anonimizados/")


if __name__ == "__main__":
    main()
