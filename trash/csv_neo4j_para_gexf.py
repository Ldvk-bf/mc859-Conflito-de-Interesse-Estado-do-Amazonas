"""
Converte o CSV exportado do Neo4j (query de conflito de interesse)
para GraphML e GEXF, usando os dados exatos do banco.

Entrada : neo4j_query_table_data_2026-4-25-2.csv
           colunas: p, o, e, t (TRABALHA_EM), f (FIRMOU_CONTRATO), s (SOCIO_DE)
Saídas  : data/gexf/conflito_interesse.graphml
           data/gexf/conflito_interesse.gexf
"""

import csv
import re
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import networkx as nx
from collections import Counter

ENTRADA = Path("/Users/ludivikdepaula/Downloads/neo4j_query_table_data_2026-4-25-3.csv")
OUT     = Path("data/gexf")
OUT.mkdir(parents=True, exist_ok=True)


def parse_props(texto: str) -> dict:
    """Extrai propriedades de uma string Neo4j como {chave: valor, ...}"""
    m = re.search(r'\{(.+)\}', texto, re.DOTALL)
    if not m:
        return {}
    conteudo = m.group(1)
    props = {}
    # Divide em "chave: valor" separando nos pontos onde aparece ", palavra:"
    # Isso preserva vírgulas dentro dos valores (ex: valor_final: 97.317,60)
    partes = re.split(r',\s*(?=\w+\s*:)', conteudo)
    for parte in partes:
        if ':' not in parte:
            continue
        chave, _, valor = parte.partition(':')
        props[chave.strip()] = valor.strip()
    return props


def parse_node_id(texto: str, tipo: str) -> str:
    """Extrai o ID único do nó."""
    props = parse_props(texto)
    if tipo == "Pessoa":
        return props.get("pessoaId", props.get("nome_normalizado", ""))
    if tipo == "Orgao":
        return props.get("orgaoId", "")
    if tipo == "Empresa":
        return props.get("empresaId", props.get("cnpj", ""))
    return ""


def main():
    print(f"Lendo {ENTRADA}...")
    G = nx.Graph()

    nos_pessoa  = {}  # id → props
    nos_orgao   = {}
    nos_empresa = {}
    arestas_te  = []  # TRABALHA_EM
    arestas_fc  = []  # FIRMOU_CONTRATO
    arestas_sd  = []  # SOCIO_DE

    with open(ENTRADA, encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            # ── Nós ──────────────────────────────────────────────────────────
            pp = parse_props(row["p"])
            pid = pp.get("pessoaId", "")

            oo = parse_props(row["o"])
            oid = oo.get("orgaoId", "")

            ee = parse_props(row["e"])
            eid = ee.get("empresaId", ee.get("cnpj", ""))

            if not pid or not oid or not eid:
                continue

            nos_pessoa[pid]   = pp
            nos_orgao[oid]    = oo
            nos_empresa[eid]  = ee

            # ── Arestas ───────────────────────────────────────────────────────
            te = parse_props(row["t"])
            fc = parse_props(row["f"])
            sd = parse_props(row["s"])

            arestas_te.append((pid, oid, te))
            arestas_fc.append((oid, eid, fc))
            arestas_sd.append((pid, eid, sd))

    # ── Adiciona nós ao grafo ────────────────────────────────────────────────
    for pid, pp in nos_pessoa.items():
        G.add_node(pid,
                   label=pp.get("nome", pid),
                   categoria="Pessoa",
                   tipo=pp.get("tipo", ""),
                   nome_normalizado=pp.get("nome_normalizado", ""))

    for oid, oo in nos_orgao.items():
        G.add_node(oid,
                   label=oo.get("nome", oid),
                   categoria="Orgao")

    for eid, ee in nos_empresa.items():
        G.add_node(eid,
                   label=ee.get("razao_social", eid),
                   categoria="Empresa",
                   cnpj=ee.get("cnpj", eid))

    # ── Adiciona arestas (deduplicadas por par de nós) ───────────────────────
    pares_te = set()
    for pid, oid, props in arestas_te:
        if (pid, oid) not in pares_te:
            pares_te.add((pid, oid))
            G.add_edge(pid, oid, tipo="TRABALHA_EM",
                       cargo=props.get("cargo", ""),
                       periodo_inicio=props.get("periodo_inicio", ""),
                       periodo_fim=props.get("periodo_fim", ""),
                       lotacao=props.get("lotacao", ""),
                       vinculo=props.get("vinculo", ""))

    pares_fc = set()
    for oid, eid, props in arestas_fc:
        if (oid, eid) not in pares_fc:
            pares_fc.add((oid, eid))
            G.add_edge(oid, eid, tipo="FIRMOU_CONTRATO",
                       data=props.get("data", ""),
                       valor_final=props.get("valor_final", ""),
                       orgao_original=props.get("orgao_original", ""))

    pares_sd = set()
    for pid, eid, props in arestas_sd:
        if (pid, eid) not in pares_sd:
            pares_sd.add((pid, eid))
            G.add_edge(pid, eid, tipo="SOCIO_DE",
                       qualificacao=props.get("qualificacao", ""))

    print(f"\nGrafo de conflito (dados diretos do Neo4j):")
    print(f"  Vértices : {G.number_of_nodes():,}")
    cats = Counter(d.get("categoria") for _, d in G.nodes(data=True))
    print(f"    Pessoa  : {cats['Pessoa']:,}")
    print(f"    Orgao   : {cats['Orgao']:,}")
    print(f"    Empresa : {cats['Empresa']:,}")
    print(f"  Arestas  : {G.number_of_edges():,}")
    tipos = Counter(d.get("tipo") for _, _, d in G.edges(data=True))
    print(f"    TRABALHA_EM     : {tipos['TRABALHA_EM']:,}")
    print(f"    FIRMOU_CONTRATO : {tipos['FIRMOU_CONTRATO']:,}")
    print(f"    SOCIO_DE        : {tipos['SOCIO_DE']:,}")

    # ── Componentes ──────────────────────────────────────────────────────────
    ccs = list(nx.connected_components(G))
    tam_ccs = sorted([len(c) for c in ccs], reverse=True)
    print(f"\n  Componentes conexas : {len(ccs)}")
    print(f"  Maior componente   : {tam_ccs[0]:,} vértices")

    # ── Grau médio ───────────────────────────────────────────────────────────
    graus = [d for _, d in G.degree()]
    grau_medio = sum(graus) / len(graus)
    print(f"  Grau médio         : {grau_medio:.4f}")

    # ── Exporta ──────────────────────────────────────────────────────────────
    print("\nExportando...")
    # nx.write_graphml(G, OUT / "conflito_interesse.graphml")
    # print(f"  ✓ {OUT}/conflito_interesse.graphml")
    nx.write_gexf(G, OUT / "conflito_interesse.gexf")
    print(f"  ✓ {OUT}/conflito_interesse.gexf")

    # ── Distribuição de graus ─────────────────────────────────────────────────
    fig, axes = plt.subplots(1, 2, figsize=(14, 5))
    fig.suptitle("Distribuição de Graus — Subgrafo de Conflito de Interesse AM", fontsize=13)

    ax1 = axes[0]
    ax1.hist(graus, bins=min(50, max(graus)+1), color="#2563eb",
             edgecolor="white", linewidth=0.3, alpha=0.85)
    ax1.axvline(grau_medio, color="#dc2626", linestyle="--", linewidth=1.5,
                label=f"Grau médio = {grau_medio:.2f}")
    ax1.set_xlabel("Grau do vértice")
    ax1.set_ylabel("Número de vértices")
    ax1.set_title("Escala linear")
    ax1.legend()
    ax1.yaxis.set_major_formatter(ticker.FuncFormatter(lambda x, _: f"{int(x):,}"))

    ax2 = axes[1]
    cont = Counter(graus)
    xs, ys = zip(*sorted(cont.items()))
    ax2.scatter(xs, ys, s=15, color="#2563eb", alpha=0.7)
    ax2.set_xscale("log"); ax2.set_yscale("log")
    ax2.set_xlabel("Grau (log)"); ax2.set_ylabel("Frequência (log)")
    ax2.set_title("Escala log-log")
    ax2.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig(OUT / "grau_distribuicao.png", dpi=150, bbox_inches="tight")
    plt.close()
    print(f"  ✓ {OUT}/grau_distribuicao.png")

    # ── Distribuição de componentes ───────────────────────────────────────────
    if len(ccs) > 1:
        fig, ax = plt.subplots(figsize=(10, 4))
        cont_tam = Counter(tam_ccs[1:])  # exclui componente gigante
        xs = sorted(cont_tam)
        ys = [cont_tam[x] for x in xs]
        ax.bar(xs, ys, color="#2563eb", edgecolor="white", linewidth=0.3)
        ax.set_xlabel("Tamanho da componente (k vértices)")
        ax.set_ylabel("Número de componentes")
        ax.set_title("Distribuição de componentes (excluindo a gigante)")
        ax.annotate(f"Componente gigante: {tam_ccs[0]} vértices",
                    xy=(0.98, 0.95), xycoords="axes fraction", ha="right",
                    fontsize=9, color="#16a34a",
                    bbox=dict(boxstyle="round", facecolor="#dcfce7", alpha=0.8))
        plt.tight_layout()
        plt.savefig(OUT / "componentes_distribuicao.png", dpi=150, bbox_inches="tight")
        plt.close()
        print(f"  ✓ {OUT}/componentes_distribuicao.png")


if __name__ == "__main__":
    main()
