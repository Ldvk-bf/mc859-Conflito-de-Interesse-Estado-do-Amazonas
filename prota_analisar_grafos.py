"""
Análise dos grafos de conflito de interesse — Amazonas

Gera para cada grafo:
  1. Introdução com descrição e link do repositório
  2. Tamanho: vértices, arestas, grau médio
  3. Distribuição de graus (histograma linear + log-log)
  4. Número de componentes conexas
  5. Distribuição dos tamanhos das componentes (se > 1)

Grafos analisados:
  - grafo_geral.gexf               : grafo completo (~153k nós)

Saídas em data/analise/
"""

from collections import Counter
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import networkx as nx
import numpy as np

# ── Configurações ─────────────────────────────────────────────────────────────

IN   = Path("data/grafo")
RELAT = Path("data/analise")
RELAT.mkdir(parents=True, exist_ok=True)

REPOSITORIO = "https://github.com/ludivikdepaula/scrapping_contratos_gov_am"

GRAFOS = {
    "grafo_geral": {
        "arquivo": IN / "grafo_geral.gexf",
        "titulo":  "Grafo Geral — Servidores, Órgãos e Empresas (AM)",
    },
}

INTRODUCAO = """
INTRODUÇÃO
──────────
Este projeto investiga conflitos de interesse na administração pública do Estado
do Amazonas, cruzando dados da folha de pagamento de servidores públicos com o
quadro societário de empresas que possuem contratos com órgãos estaduais.

Os dados foram coletados de fontes abertas:
  • Folha de pagamento (funcionários e vínculos por órgão)
  • Quadro societário de empresas (sócios e CNPJs via Receita Federal / BrasilAPI)
  • Contratos firmados entre órgãos públicos e fornecedores

O grafo modela três tipos de entidades (vértices):
  • Pessoa  — servidores públicos e/ou sócios de empresas
  • Orgao   — órgãos da administração estadual
  • Empresa — empresas fornecedoras com CNPJ válido

E quatro tipos de relações (arestas):
  • TRABALHA_EM        — servidor vinculado a um órgão
  • SOCIO_DE           — pessoa como sócia de uma empresa
  • FIRMOU_CONTRATO    — órgão que contratou uma empresa
  • POSSIVEL_MESMO_QUE — possível correspondência entre cadastros (fuzzy matching)

Repositório com código e instâncias:
  {repo}
""".format(repo=REPOSITORIO)


# ── Helpers ───────────────────────────────────────────────────────────────────

def linha(c="─", n=62):
    return c * n


def fmt(v):
    if isinstance(v, float):
        return f"{v:,.4f}"
    return f"{v:,}"


# ── Análise por grafo ─────────────────────────────────────────────────────────

def analisar(chave: str, cfg: dict):
    caminho = cfg["arquivo"]
    titulo  = cfg["titulo"]

    if not caminho.exists():
        print(f"⚠  Arquivo não encontrado: {caminho}")
        return

    print(f"\n{linha('═')}")
    print(f"  {titulo}")
    print(f"{linha('═')}")
    print(f"  Carregando {caminho.name}...")

    G = nx.read_gexf(caminho)

    # ── 2. Tamanho do grafo ───────────────────────────────────────────────────
    n       = G.number_of_nodes()
    m       = G.number_of_edges()
    graus   = [d for _, d in G.degree()]
    grau_medio = sum(graus) / n if n else 0

    cats  = Counter(d.get("categoria", "?") for _, d in G.nodes(data=True))
    tipos = Counter(d.get("tipo", "?") for _, _, d in G.edges(data=True))

    bloco_tamanho = f"""
2. TAMANHO DO GRAFO
{linha()}
  Vértices (total) : {fmt(n)}
    • Pessoa        : {fmt(cats.get('Pessoa',  0))}
    • Orgao         : {fmt(cats.get('Orgao',   0))}
    • Empresa       : {fmt(cats.get('Empresa', 0))}

  Arestas  (total) : {fmt(m)}
    • TRABALHA_EM        : {fmt(tipos.get('TRABALHA_EM',        0))}
    • SOCIO_DE           : {fmt(tipos.get('SOCIO_DE',           0))}
    • FIRMOU_CONTRATO    : {fmt(tipos.get('FIRMOU_CONTRATO',    0))}
    • POSSIVEL_MESMO_QUE : {fmt(tipos.get('POSSIVEL_MESMO_QUE', 0))}

  Grau médio       : {grau_medio:.4f}
  Grau máximo      : {fmt(max(graus))}
  Grau mediana     : {float(np.median(graus)):.1f}
"""
    print(bloco_tamanho)

    # ── 3. Distribuição de graus ──────────────────────────────────────────────
    print("  Gerando distribuição de graus...")
    fig, axes = plt.subplots(1, 2, figsize=(14, 5))
    fig.suptitle(f"3. Distribuição de Graus — {titulo}", fontsize=12, fontweight="bold")

    ax1 = axes[0]
    bins = min(80, max(graus) + 1)
    ax1.hist(graus, bins=bins, color="#2563eb", edgecolor="white", linewidth=0.3, alpha=0.85)
    ax1.axvline(grau_medio, color="#dc2626", linestyle="--", linewidth=1.5,
                label=f"Grau médio = {grau_medio:.2f}")
    ax1.set_xlabel("Grau do vértice")
    ax1.set_ylabel("Número de vértices")
    ax1.set_title("Escala linear")
    ax1.legend(fontsize=9)
    ax1.yaxis.set_major_formatter(ticker.FuncFormatter(lambda x, _: f"{int(x):,}"))

    ax2 = axes[1]
    cont = Counter(graus)
    xs, ys = zip(*sorted(cont.items()))
    ax2.scatter(xs, ys, s=14, color="#2563eb", alpha=0.75)
    ax2.set_xscale("log")
    ax2.set_yscale("log")
    ax2.set_xlabel("Grau do vértice (escala log)")
    ax2.set_ylabel("Número de vértices (escala log)")
    ax2.set_title("Escala log-log")
    ax2.grid(True, alpha=0.3)

    plt.tight_layout()
    fig_grau = RELAT / f"3_distribuicao_graus_{chave}.png"
    plt.savefig(fig_grau, dpi=150, bbox_inches="tight")
    plt.close()
    print(f"  ✓ {fig_grau}")

    # ── 4. Componentes conexas ────────────────────────────────────────────────
    ccs     = list(nx.connected_components(G))
    n_cc    = len(ccs)
    tam_ccs = sorted([len(c) for c in ccs], reverse=True)
    gigante = tam_ccs[0]

    bloco_cc = f"""
4. COMPONENTES CONEXAS
{linha()}
  Número de componentes      : {fmt(n_cc)}
  Componente gigante         : {fmt(gigante)} vértices  ({gigante/n*100:.2f}% do grafo)
  Componentes de tamanho 2   : {sum(1 for t in tam_ccs if t == 2):,}
  Componentes de tamanho 1   : {sum(1 for t in tam_ccs if t == 1):,}
"""
    print(bloco_cc)

    # ── 5. Distribuição de tamanhos das componentes (se > 1) ─────────────────
    if n_cc > 1:
        print("  Gerando distribuição de componentes...")
        sem_gigante = [t for t in tam_ccs[1:]]
        cont_tam    = Counter(sem_gigante)

        # Agrupa tamanhos > 50 em "50+"
        xs_plot = sorted(k for k in cont_tam if k <= 50)
        ys_plot = [cont_tam[k] for k in xs_plot]
        grandes = sum(v for k, v in cont_tam.items() if k > 50)

        fig, ax = plt.subplots(figsize=(12, 5))
        if xs_plot:
            ax.bar(xs_plot, ys_plot, color="#2563eb",
                   edgecolor="white", linewidth=0.4, alpha=0.85,
                   width=0.6, label="Tamanho ≤ 50")
        if grandes:
            # barra categórica "50+" desenhada separada com offset numérico
            x_grandes = (max(xs_plot) + 3) if xs_plot else 3
            ax.bar([x_grandes], [grandes], color="#f59e0b",
                   edgecolor="white", linewidth=0.4, alpha=0.85,
                   width=0.6, label="Tamanho > 50")
            # substitui o tick numérico pelo rótulo "50+"
            todos_ticks = xs_plot + [x_grandes]
            todos_labels = [str(x) for x in xs_plot] + ["50+"]
        else:
            todos_ticks = xs_plot
            todos_labels = [str(x) for x in xs_plot]

        # Força ticks apenas nos valores inteiros reais (sem frações)
        ax.set_xticks(todos_ticks)
        ax.set_xticklabels(todos_labels, fontsize=9)
        # Padding lateral para as barras não ficarem coladas nas bordas
        if todos_ticks:
            margem = max(1, (max(todos_ticks) - min(todos_ticks)) * 0.05 + 0.8)
            ax.set_xlim(min(todos_ticks) - margem, max(todos_ticks) + margem)

        ax.set_xlabel("Tamanho da componente (número de vértices k)")
        ax.set_ylabel("Número de componentes com k vértices")
        ax.set_title(
            f"5. Distribuição dos Tamanhos das Componentes — {titulo}\n"
            f"(componente gigante omitida: {gigante:,} vértices = {gigante/n*100:.1f}% do grafo)",
            fontsize=10
        )
        ax.yaxis.set_major_formatter(ticker.FuncFormatter(lambda x, _: f"{int(x):,}"))
        ax.yaxis.set_major_locator(ticker.MaxNLocator(integer=True))
        ax.legend(fontsize=9)

        ax.annotate(
            f"Componente gigante:\n{gigante:,} vértices ({gigante/n*100:.1f}%)",
            xy=(0.98, 0.95), xycoords="axes fraction", ha="right", va="top",
            fontsize=9, color="#16a34a",
            bbox=dict(boxstyle="round,pad=0.3", facecolor="#dcfce7", alpha=0.85)
        )

        plt.tight_layout()
        fig_cc = RELAT / f"5_distribuicao_componentes_{chave}.png"
        plt.savefig(fig_cc, dpi=150, bbox_inches="tight")
        plt.close()
        print(f"  ✓ {fig_cc}")

        bloco_dist = f"""
5. DISTRIBUIÇÃO DOS TAMANHOS DAS COMPONENTES
{linha()}
  (excluindo a componente gigante com {gigante:,} vértices)

  Tam.  | Qtd. componentes
  ──────┼──────────────────"""
        for k in sorted(cont_tam)[:20]:
            bloco_dist += f"\n    {k:<4}  | {cont_tam[k]:,}"
        if grandes:
            bloco_dist += f"\n    50+   | {grandes:,}"
    else:
        bloco_dist = f"""
5. DISTRIBUIÇÃO DOS TAMANHOS DAS COMPONENTES
{linha()}
  O grafo possui apenas 1 componente conexa — todos os {n:,} vértices
  estão conectados em um único componente gigante.
  Não há distribuição de componentes a representar.
"""

    print(bloco_dist)

    # ── Salva relatório texto ─────────────────────────────────────────────────
    relat_path = RELAT / f"analise_{chave}.txt"
    with open(relat_path, "w", encoding="utf-8") as f:
        f.write(f"{'═'*62}\n")
        f.write(f"  {titulo}\n")
        f.write(f"{'═'*62}\n")
        f.write(INTRODUCAO)
        f.write(bloco_tamanho)
        f.write(f"\n  → Figura: 3_distribuicao_graus_{chave}.png\n")
        f.write(bloco_cc)
        f.write(bloco_dist)
        if n_cc > 1:
            f.write(f"\n  → Figura: 5_distribuicao_componentes_{chave}.png\n")

    print(f"\n  ✓ Relatório: {relat_path}")


# ── Main ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print(INTRODUCAO)
    for chave, cfg in GRAFOS.items():
        analisar(chave, cfg)

    print(f"\n{'═'*62}")
    print(f"  ✓ Todos os arquivos salvos em {RELAT}/")
    print(f"{'═'*62}")
