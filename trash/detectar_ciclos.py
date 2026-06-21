"""
Detecção de ciclos de conflito de interesse em grafo heterogêneo (via merges pandas).

Padrões detectados:
  Triângulo — mesma Pessoa com TRABALHA_EM(Orgao) e SOCIO_DE(Empresa)
              onde Orgao FIRMOU_CONTRATO Empresa, durante o período do vínculo.

  Quadrado  — Pessoa A com TRABALHA_EM(Orgao), Pessoa B com SOCIO_DE(Empresa),
              onde Orgao FIRMOU_CONTRATO Empresa, e A POSSIVEL_MESMO_QUE B.

Filtros obrigatórios em ambos:
  - data do contrato dentro de [periodo_inicio, periodo_fim] do vínculo
    (periodo_fim vazio = vínculo ativo, tratado como futuro distante)
  - valor_final > 100.000

Estratégia: merges relacionais sucessivos (sem travessia nó a nó).
"""

import pandas as pd
from pathlib import Path

# ── Caminhos ──────────────────────────────────────────────────────────────────
DIR_NODES = Path("data/neo4j/nodes")
DIR_RELS  = Path("data/neo4j/relationships")
DIR_SAIDA = Path("data/dados_derivados")

SAIDA_TRIANGULOS = DIR_SAIDA / "ciclos_triangulos.csv"
SAIDA_QUADRADOS  = DIR_SAIDA / "ciclos_quadrados.csv"

VALOR_MINIMO = 100_000.0
DATA_FUTURA  = pd.Timestamp("2099-12-31")   # periodo_fim vazio = ativo


# ── Helpers de parsing ────────────────────────────────────────────────────────

def parse_valor(serie: pd.Series) -> pd.Series:
    """'1.234.567,89' → 1234567.89"""
    return (
        serie.astype(str)
        .str.replace(r"\.", "", regex=True)
        .str.replace(",", ".", regex=False)
        .pipe(pd.to_numeric, errors="coerce")
    )


def parse_periodo(serie: pd.Series, fim: bool = False) -> pd.Series:
    """
    'YYYY-MM' → Timestamp no 1º dia do mês.
    Se fim=True e valor vazio/nulo → DATA_FUTURA.
    """
    if fim:
        serie = serie.fillna("").str.strip()
        vazio = serie == ""
        ts = pd.to_datetime(serie.where(~vazio), format="%Y-%m", errors="coerce")
        # Avança para o último instante do mês (DD 28–31 não importa; usamos >= início)
        ts = ts + pd.offsets.MonthEnd(0)
        ts = ts.where(~vazio, DATA_FUTURA)
        return ts
    return pd.to_datetime(serie, format="%Y-%m", errors="coerce")


def parse_data_contrato(serie: pd.Series) -> pd.Series:
    """'DD/MM/AAAA' → Timestamp"""
    return pd.to_datetime(serie, format="%d/%m/%Y", errors="coerce")


def parse_score(serie: pd.Series) -> pd.Series:
    """'98,59' → 98.59"""
    return serie.astype(str).str.replace(",", ".", regex=False).pipe(pd.to_numeric, errors="coerce")


# ── Carregamento ──────────────────────────────────────────────────────────────

def carregar():
    # Nós
    pessoa  = pd.read_csv(DIR_NODES / "pessoa.csv").rename(columns={
        "pessoaId:ID(Pessoa)": "pessoaId",
    })
    empresa = pd.read_csv(DIR_NODES / "empresa.csv").rename(columns={
        "empresaId:ID(Empresa)": "empresaId",
    })
    orgao   = pd.read_csv(DIR_NODES / "orgao.csv").rename(columns={
        "orgaoId:ID(Orgao)": "orgaoId",
    })

    # Relacionamentos
    te = pd.read_csv(DIR_RELS / "trabalha_em.csv").rename(columns={
        ":START_ID(Pessoa)": "pessoaId",
        ":END_ID(Orgao)":    "orgaoId",
    }).drop(columns=[":TYPE"], errors="ignore")
    te["periodo_inicio"] = parse_periodo(te["periodo_inicio"])
    te["periodo_fim"]    = parse_periodo(te["periodo_fim"], fim=True)

    fc = pd.read_csv(DIR_RELS / "firmou_contrato.csv").rename(columns={
        ":START_ID(Orgao)":    "orgaoId",
        ":END_ID(Empresa)":    "empresaId",
    }).drop(columns=[":TYPE"], errors="ignore")
    fc["data"]        = parse_data_contrato(fc["data"])
    fc["valor_final"] = parse_valor(fc["valor_final"])

    sd = pd.read_csv(DIR_RELS / "socio_de.csv").rename(columns={
        ":START_ID(Pessoa)":   "pessoaId",
        ":END_ID(Empresa)":    "empresaId",
    }).drop(columns=[":TYPE"], errors="ignore")

    pmq = pd.read_csv(DIR_RELS / "possivel_mesmo_que.csv").rename(columns={
        ":START_ID(Pessoa)": "pessoaId_A",
        ":END_ID(Pessoa)":   "pessoaId_B",
    }).drop(columns=[":TYPE"], errors="ignore")
    pmq["score"] = parse_score(pmq["score"])

    return pessoa, empresa, orgao, te, fc, sd, pmq


# ── Filtros comuns ────────────────────────────────────────────────────────────

def filtrar_periodo_e_valor(df: pd.DataFrame) -> pd.DataFrame:
    """
    Mantém linhas onde:
      - data do contrato cai dentro do período do vínculo
      - valor_final > VALOR_MINIMO
    """
    dentro = (df["data"] >= df["periodo_inicio"]) & (df["data"] <= df["periodo_fim"])
    valor  = df["valor_final"] > VALOR_MINIMO
    return df[dentro & valor].copy()


# ── Triângulos ────────────────────────────────────────────────────────────────
#
#   Pessoa──TRABALHA_EM──▶Orgao
#     │                     │
#     SOCIO_DE         FIRMOU_CONTRATO
#     ▼                     ▼
#   Empresa◀─────────────────
#
# Merge plan:
#   te ⋈ fc  (on orgaoId)            → (pessoa, orgao, empresa, contrato)
#   ⋈ sd     (on pessoaId + empresaId) → mesma pessoa é sócia da mesma empresa
#   filtrar  período + valor

def detectar_triangulos(te, fc, sd, orgao, empresa):
    print("Detectando triângulos...")

    # te ⋈ fc on orgaoId
    base = te.merge(fc, on="orgaoId", suffixes=("_vinculo", "_contrato"))

    # Filtra período e valor antes de continuar (reduz tamanho do DF)
    base = filtrar_periodo_e_valor(base)
    print(f"  Após filtro período+valor: {len(base):,} candidatos")

    # ⋈ sd on (pessoaId, empresaId) — mesma pessoa, mesma empresa
    tri = base.merge(sd, on=["pessoaId", "empresaId"], suffixes=("", "_sd"))

    # Enriquece com nome do órgão e razão social
    tri = (
        tri
        .merge(orgao.rename(columns={"nome": "orgao_nome"}), on="orgaoId", how="left")
        .merge(empresa[["empresaId", "razao_social"]], on="empresaId", how="left")
    )

    # Colunas de saída
    colunas = [
        "pessoaId", "orgaoId", "orgao_nome", "empresaId", "razao_social",
        "periodo_inicio", "periodo_fim", "cargo", "vinculo", "lotacao",
        "data", "valor_final", "descricao", "orgao_original",
        "qualificacao", "cpf_parcial",
    ]
    colunas = [c for c in colunas if c in tri.columns]
    tri = tri[colunas].drop_duplicates()

    print(f"  Triângulos encontrados: {len(tri):,}")
    return tri


# ── Quadrados ─────────────────────────────────────────────────────────────────
#
#   Pessoa_A──TRABALHA_EM──▶Orgao──FIRMOU_CONTRATO──▶Empresa
#       │                                                 │
#   POSSIVEL_MESMO_QUE                              SOCIO_DE
#       │                                                 │
#   Pessoa_B◀────────────────────────────────────────────
#
# Merge plan:
#   te ⋈ fc      (on orgaoId)        → (pessoaA, orgao, empresa, contrato)
#   filtrar      período + valor
#   ⋈ sd         (on empresaId)      → pessoaB é sócia da empresa  [pessoaA ≠ pessoaB]
#   ⋈ pmq        (on pessoaA ↔ pessoaB, simétrico)

def detectar_quadrados(te, fc, sd, pmq, orgao, empresa):
    print("Detectando quadrados...")

    # te ⋈ fc on orgaoId → (pessoaA, orgaoId, empresaId, contrato)
    base = te.merge(fc, on="orgaoId", suffixes=("_vinculo", "_contrato"))
    base = filtrar_periodo_e_valor(base)
    print(f"  Após filtro período+valor: {len(base):,} candidatos")

    # ⋈ sd on empresaId → pessoaB é sócia da mesma empresa
    base = base.merge(
        sd.rename(columns={"pessoaId": "pessoaId_B"}),
        on="empresaId",
        suffixes=("", "_sd"),
    )

    # Descarta linhas onde A = B (triângulo, não quadrado)
    base = base[base["pessoaId"] != base["pessoaId_B"]].copy()
    base = base.rename(columns={"pessoaId": "pessoaId_A"})

    # POSSIVEL_MESMO_QUE é simétrica — normaliza para ter ambas direções
    pmq_inv = pmq.rename(columns={"pessoaId_A": "pessoaId_B", "pessoaId_B": "pessoaId_A"})
    pmq_sym = pd.concat([pmq, pmq_inv], ignore_index=True).drop_duplicates(
        subset=["pessoaId_A", "pessoaId_B"]
    )

    # ⋈ pmq on (pessoaId_A, pessoaId_B)
    quad = base.merge(pmq_sym, on=["pessoaId_A", "pessoaId_B"])

    # Enriquece
    quad = (
        quad
        .merge(orgao.rename(columns={"nome": "orgao_nome"}), on="orgaoId", how="left")
        .merge(empresa[["empresaId", "razao_social"]], on="empresaId", how="left")
    )

    colunas = [
        "pessoaId_A", "pessoaId_B", "score", "metodo",
        "orgaoId", "orgao_nome", "empresaId", "razao_social",
        "periodo_inicio", "periodo_fim", "cargo", "vinculo", "lotacao",
        "data", "valor_final", "descricao", "orgao_original",
        "qualificacao", "cpf_parcial",
    ]
    colunas = [c for c in colunas if c in quad.columns]
    quad = quad[colunas].drop_duplicates()

    print(f"  Quadrados encontrados: {len(quad):,}")
    return quad


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print("Carregando CSVs...")
    pessoa, empresa, orgao, te, fc, sd, pmq = carregar()
    print(f"  pessoas:           {len(pessoa):,}")
    print(f"  empresas:          {len(empresa):,}")
    print(f"  orgaos:            {len(orgao):,}")
    print(f"  trabalha_em:       {len(te):,}")
    print(f"  firmou_contrato:   {len(fc):,}")
    print(f"  socio_de:          {len(sd):,}")
    print(f"  possivel_mesmo_que:{len(pmq):,}")
    print(f"  Filtro valor:      > R$ {VALOR_MINIMO:,.0f}\n")

    # Pré-filtra contratos abaixo do valor mínimo para reduzir junções
    fc = fc[fc["valor_final"] > VALOR_MINIMO].copy()
    print(f"  Contratos > R$ {VALOR_MINIMO:,.0f}: {len(fc):,}\n")

    triangulos = detectar_triangulos(te, fc, sd, orgao, empresa)
    quadrados  = detectar_quadrados(te, fc, sd, pmq, orgao, empresa)

    # Serializa timestamps de volta para string legível
    for df in [triangulos, quadrados]:
        for col in ["periodo_inicio", "periodo_fim", "data"]:
            if col in df.columns:
                if col == "periodo_fim":
                    df[col] = df[col].apply(
                        lambda t: "" if t == DATA_FUTURA else t.strftime("%Y-%m") if pd.notna(t) else ""
                    )
                elif col == "periodo_inicio":
                    df[col] = df[col].dt.strftime("%Y-%m")
                else:
                    df[col] = df[col].dt.strftime("%d/%m/%Y")
        if "valor_final" in df.columns:
            df["valor_final"] = df["valor_final"].map(
                lambda v: f"{v:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".") if pd.notna(v) else ""
            )

    DIR_SAIDA.mkdir(exist_ok=True)
    triangulos.to_csv(SAIDA_TRIANGULOS, index=False)
    quadrados.to_csv(SAIDA_QUADRADOS, index=False)

    print(f"\nArquivos gerados:")
    print(f"  {SAIDA_TRIANGULOS}  ({len(triangulos):,} linhas)")
    print(f"  {SAIDA_QUADRADOS}   ({len(quadrados):,} linhas)")

    if len(triangulos):
        print("\nExemplos de triângulos:")
        cols = ["pessoaId", "orgao_nome", "razao_social", "valor_final", "data"]
        cols = [c for c in cols if c in triangulos.columns]
        print(triangulos[cols].head(5).to_string(index=False))

    if len(quadrados):
        print("\nExemplos de quadrados:")
        cols = ["pessoaId_A", "pessoaId_B", "score", "orgao_nome", "razao_social", "valor_final"]
        cols = [c for c in cols if c in quadrados.columns]
        print(quadrados[cols].head(5).to_string(index=False))


if __name__ == "__main__":
    main()
