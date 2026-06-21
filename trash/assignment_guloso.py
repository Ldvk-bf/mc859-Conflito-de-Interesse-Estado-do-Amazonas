"""
Algoritmo guloso de assignment para o matching funcionário × sócio.

Problema: após o fuzzy matching, um funcionário pode competir com outros
pela mesma identidade de sócio, e um sócio pode ter sido matcheado por
múltiplos funcionários. Queremos 1 associação por pessoa de cada lado.

Estratégia gulosa (não garante ótimo global, mas é O(n log n) e ótimo local):
  1. Ordena todos os matches por score DESC (melhor match primeiro)
  2. Percorre a lista em ordem:
       - Se nenhum dos dois lados já foi atribuído → aceita o par
       - Caso contrário → descarta (o lado ocupado já tem um match melhor)

Identidades:
  - Funcionário  → nome_funcionario_normalizado  (uma pessoa, um nome)
  - Sócio        → nome_socio_normalizado         (mesma pessoa em vários CNPJs
                                                    ainda é a mesma pessoa)

Entrada:  data/dados_derivados/nome_funcionario-nome_socio.csv
Saída:    data/dados_derivados/assignment_final.csv
          data/dados_derivados/assignment_descartados.csv  (perderam a competição)
"""

import csv
from pathlib import Path

ENTRADA     = Path("data/dados_derivados/nome_funcionario-nome_socio.csv")
SAIDA       = Path("data/dados_derivados/assignment_final.csv")
DESCARTADOS = Path("data/dados_derivados/assignment_descartados.csv")

COLUNAS = [
    "nome_funcionario_normalizado",
    "orgao",
    "nome_socio_normalizado",
    "cnpj_empresa",
    "razao_social",
    "score",
    "metodo",
]

COLUNAS_DESCARTADOS = COLUNAS + ["motivo_descarte"]


def parse_score(s: str) -> float:
    return float(str(s).replace(",", "."))


def main():
    print(f"Lendo matches de {ENTRADA}...")
    with open(ENTRADA, encoding="utf-8", newline="") as f:
        matches = list(csv.DictReader(f))
    print(f"  {len(matches):,} matches lidos")

    # Ordena por score desc — a chave da gulodice
    matches.sort(key=lambda r: -parse_score(r["score"]))

    atribuidos_func:  set[str] = set()  # nome_funcionario_normalizado já usado
    atribuidos_socio: set[str] = set()  # nome_socio_normalizado já usado

    aceitos    = []
    descartados = []

    for match in matches:
        func  = match["nome_funcionario_normalizado"]
        socio = match["nome_socio_normalizado"]

        func_livre  = func  not in atribuidos_func
        socio_livre = socio not in atribuidos_socio

        if func_livre and socio_livre:
            atribuidos_func.add(func)
            atribuidos_socio.add(socio)
            aceitos.append(match)
        else:
            # Registra o motivo para análise posterior
            if not func_livre and not socio_livre:
                motivo = "funcionario_e_socio_ja_atribuidos"
            elif not func_livre:
                motivo = "funcionario_ja_atribuido"
            else:
                motivo = "socio_ja_atribuido"
            descartados.append({**match, "motivo_descarte": motivo})

    # ── Relatório ──────────────────────────────────────────────────────────────
    print(f"\nResultado do assignment guloso:")
    print(f"  Pares aceitos:     {len(aceitos):,}")
    print(f"  Pares descartados: {len(descartados):,}")
    print(f"  Funcionários únicos atribuídos: {len(atribuidos_func):,}")
    print(f"  Sócios únicos atribuídos:       {len(atribuidos_socio):,}")

    if descartados:
        from collections import Counter
        motivos = Counter(r["motivo_descarte"] for r in descartados)
        print(f"\n  Motivos de descarte:")
        for motivo, qtd in motivos.most_common():
            print(f"    {motivo}: {qtd:,}")

    # Distribuição de scores dos aceitos
    faixas = {"100 (exato)": 0, "95 (token_igual)": 0, "93-94": 0, "92": 0}
    for r in aceitos:
        s = parse_score(r["score"])
        m = r["metodo"]
        if m == "exato":
            faixas["100 (exato)"] += 1
        elif m == "token_igual":
            faixas["95 (token_igual)"] += 1
        elif s >= 93:
            faixas["93-94"] += 1
        else:
            faixas["92"] += 1
    print(f"\n  Distribuição de scores (aceitos):")
    for faixa, qtd in faixas.items():
        print(f"    Score {faixa}: {qtd:,}")

    # ── Escrita ────────────────────────────────────────────────────────────────
    SAIDA.parent.mkdir(exist_ok=True)

    with open(SAIDA, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=COLUNAS)
        writer.writeheader()
        writer.writerows(aceitos)
    print(f"\nAssignment final:   {SAIDA}")

    with open(DESCARTADOS, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=COLUNAS_DESCARTADOS)
        writer.writeheader()
        writer.writerows(descartados)
    print(f"Descartados:        {DESCARTADOS}")

    print("\nExemplos aceitos:")
    for r in aceitos[:10]:
        print(f"  [{r['score']:>6} | {r['metodo']:<12}] "
              f"{r['nome_funcionario_normalizado'][:35]:<35}  ↔  "
              f"{r['nome_socio_normalizado'][:35]:<35}")


if __name__ == "__main__":
    main()
