"""
Desambiguação 1-para-1 de matches fuzzy (Sócio <-> Funcionário).

Duas estratégias:
  1. greedy()  - guloso simples: rápido, mas pode ser subótimo
  2. optimal() - ótimo global via algoritmo Húngaro aplicado por
                 componente conexo do grafo de conflitos (rápido,
                 pois os conflitos formam ilhas pequenas)

Entrada esperada: DataFrame com colunas ['socio', 'funcionario', 'score'].
"""

import pandas as pd
import numpy as np
from scipy.optimize import linear_sum_assignment
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components


# ---------------------------------------------------------------------------
# 1) VERSÃO GULOSA (baseline — sua ideia original)
# ---------------------------------------------------------------------------
def greedy(df: pd.DataFrame) -> pd.DataFrame:
    """Ordena por score desc e aceita pares enquanto ambos os lados
    estiverem livres. Desempate estável: score, depois ordem original."""
    df = df.sort_values("score", ascending=False, kind="mergesort")
    usados_socio, usados_func = set(), set()
    manter = []
    for row in df.itertuples():
        if row.socio not in usados_socio and row.funcionario not in usados_func:
            manter.append(row.Index)
            usados_socio.add(row.socio)
            usados_func.add(row.funcionario)
    return df.loc[manter].sort_values("score", ascending=False)


# ---------------------------------------------------------------------------
# 2) VERSÃO ÓTIMA (Húngaro por componente conexo)
# ---------------------------------------------------------------------------
def optimal(df: pd.DataFrame) -> pd.DataFrame:
    """Maximiza a soma total de scores garantindo relação 1-para-1.

    Estratégia:
      - codifica sócios e funcionários como inteiros
      - acha componentes conexos do grafo bipartido de candidatos
      - resolve o problema de atribuição (Húngaro) dentro de cada
        componente que tiver conflito; componentes triviais passam direto
    """
    df = df.reset_index(drop=True).copy()

    # Codificação inteira dos dois lados
    socios = pd.Categorical(df["socio"])
    funcs = pd.Categorical(df["funcionario"])
    s_idx = socios.codes                      # 0..n_s-1
    f_idx = funcs.codes                       # 0..n_f-1
    n_s, n_f = len(socios.categories), len(funcs.categories)

    # Grafo bipartido: nós 0..n_s-1 são sócios, n_s..n_s+n_f-1 são funcionários
    grafo = coo_matrix(
        (np.ones(len(df)), (s_idx, f_idx + n_s)),
        shape=(n_s + n_f, n_s + n_f),
    )
    n_comp, labels = connected_components(grafo, directed=False)

    # Componente de cada aresta (par candidato) = componente do seu sócio
    df["_comp"] = labels[s_idx]
    df["_s"] = s_idx
    df["_f"] = f_idx

    manter = []
    for _, grupo in df.groupby("_comp", sort=False):
        if len(grupo) == 1:
            # Sem conflito: aceita direto
            manter.append(grupo.index[0])
            continue

        # Submatriz local de scores (sócios x funcionários do componente)
        s_locais = grupo["_s"].unique()
        f_locais = grupo["_f"].unique()
        s_map = {v: i for i, v in enumerate(s_locais)}
        f_map = {v: i for i, v in enumerate(f_locais)}

        # Matriz com score 0 onde não há candidatura (par "proibido")
        M = np.zeros((len(s_locais), len(f_locais)))
        idx_lookup = {}
        for idx, s, f, sc in zip(
            grupo.index, grupo["_s"], grupo["_f"], grupo["score"]
        ):
            i, j = s_map[s], f_map[f]
            M[i, j] = sc
            idx_lookup[(i, j)] = idx

        # Húngaro maximizando a soma de scores
        lin, col = linear_sum_assignment(M, maximize=True)
        for i, j in zip(lin, col):
            if M[i, j] > 0:  # descarta atribuições a pares inexistentes
                manter.append(idx_lookup[(i, j)])

    return (
        df.loc[manter]
        .drop(columns=["_comp", "_s", "_f"])
        .sort_values("score", ascending=False)
        .reset_index(drop=True)
    )


# ---------------------------------------------------------------------------
# DEMONSTRAÇÃO: caso em que o guloso perde para o ótimo
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    df = pd.DataFrame(
        {
            "socio": ["A", "A", "B", "MARIA DE FATIMA DE O FERREIRA"] * 1
            + ["MARIA DE FATIMA DE O FERREIRA"] * 4,
            "funcionario": [
                "X", "Y", "X", "MARIA DE FATIMA DE OLIVEIRA FERREIRA",
                "MARIA DE FATIMA O FERREIRA",
                "MARIA FATIMA DE OLIVEIRA FERREIRA",
                "MARIA DE FATIMA FERREIRA",
                "MARIA D FATIMA DE O FERREIRA",
            ],
            "score": [90, 89, 88, 97, 96, 95, 93, 92],
        }
    )

    g = greedy(df)
    o = optimal(df)

    print("=== GULOSO ===")
    print(g.to_string(index=False))
    print(f"Soma de scores: {g['score'].sum()} | pares: {len(g)}\n")

    print("=== ÓTIMO (Húngaro por componente) ===")
    print(o.to_string(index=False))
    print(f"Soma de scores: {o['score'].sum()} | pares: {len(o)}")