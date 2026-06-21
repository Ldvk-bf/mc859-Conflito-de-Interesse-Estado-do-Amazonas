"""
Exporta o grafo de conflito de interesse para GraphML e GEXF.
Gera também as estatísticas e visualizações para a entrega parcial.

Saídas:
  data/gexf/grafo_geral.gexf
  data/gexf/grau_distribuicao.png
  data/gexf/componentes_distribuicao.png
  data/gexf/estatisticas.txt
"""

import csv
import re
from collections import Counter
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import networkx as nx

NEO4J = Path("data/neo4j")
OUT   = Path("data/gexf")
OUT.mkdir(parents=True, exist_ok=True)

# ── 1. Constrói o grafo ───────────────────────────────────────────────────────

print("Construindo grafo...")
# MultiGraph: permite múltiplas arestas entre o mesmo par de nós
# (ex: um órgão pode ter vários contratos com a mesma empresa)
G = nx.MultiGraph()

# Nós: Pessoa
with open(NEO4J / "nodes" / "pessoa.csv", encoding="utf-8") as f:
    for r in csv.DictReader(f):
        G.add_node(r["pessoaId:ID(Pessoa)"],
                   label=r["nome"],
                   tipo=r["tipo"],
                   categoria="Pessoa")

# Nós: Orgao
with open(NEO4J / "nodes" / "orgao.csv", encoding="utf-8") as f:
    for r in csv.DictReader(f):
        G.add_node(r["orgaoId:ID(Orgao)"],
                   label=r["nome"],
                   categoria="Orgao")

# Nós: Empresa
with open(NEO4J / "nodes" / "empresa.csv", encoding="utf-8") as f:
    for r in csv.DictReader(f):
        G.add_node(r["empresaId:ID(Empresa)"],
                   label=r["razao_social"],
                   cnpj=r["cnpj"],
                   categoria="Empresa")

# Arestas: TRABALHA_EM
with open(NEO4J / "relationships" / "trabalha_em.csv", encoding="utf-8") as f:
    for r in csv.DictReader(f):
        G.add_edge(r[":START_ID(Pessoa)"], r[":END_ID(Orgao)"],
                   tipo="TRABALHA_EM",
                   cargo=r.get("cargo", ""),
                   periodo_inicio=r.get("periodo_inicio", ""),
                   periodo_fim=r.get("periodo_fim", ""))

# Arestas: SOCIO_DE
with open(NEO4J / "relationships" / "socio_de.csv", encoding="utf-8") as f:
    for r in csv.DictReader(f):
        G.add_edge(r[":START_ID(Pessoa)"], r[":END_ID(Empresa)"],
                   tipo="SOCIO_DE",
                   qualificacao=r.get("qualificacao", ""))

# Arestas: FIRMOU_CONTRATO
with open(NEO4J / "relationships" / "firmou_contrato.csv", encoding="utf-8") as f:
    for r in csv.DictReader(f):
        G.add_edge(r[":START_ID(Orgao)"], r[":END_ID(Empresa)"],
                   tipo="FIRMOU_CONTRATO",
                   data=r.get("data", ""),
                   valor_final=r.get("valor_final", ""))

# Arestas: POSSIVEL_MESMO_QUE
with open(NEO4J / "relationships" / "possivel_mesmo_que.csv", encoding="utf-8") as f:
    for r in csv.DictReader(f):
        G.add_edge(r[":START_ID(Pessoa)"], r[":END_ID(Pessoa)"],
                   tipo="POSSIVEL_MESMO_QUE",
                   score=r.get("score", ""),
                   metodo=r.get("metodo", ""))

print(f"  Vértices (total) : {G.number_of_nodes():,}")
print(f"  Arestas  (total) : {G.number_of_edges():,}")

# ── 2. Exporta e GEXF ─────────────────────────────────────────────────

print("Exportando GEXF...")
nx.write_gexf(G, OUT / "grafo_geral.gexf")
print("  ✓ data/grafo/grafo_geral.gexf")

# ── 3. Estatísticas ───────────────────────────────────────────────────────────

print("\nCalculando estatísticas...")

n_vertices = G.number_of_nodes()
n_arestas  = G.number_of_edges()
grau_medio = (2 * n_arestas) / n_vertices if n_vertices else 0  # grau total / n

# Grau não-direcionado (in + out) para distribuição
graus = [d for _, d in G.degree()]
grau_medio_nd = sum(graus) / len(graus) if graus else 0

# Componentes conexas (grafo não-direcionado)
ccs = list(nx.connected_components(G))
n_cc = len(ccs)
tam_ccs = sorted([len(c) for c in ccs], reverse=True)

# Tipos de nós
cats = Counter(data.get("categoria", "?") for _, data in G.nodes(data=True))
tipos_aresta = Counter(data.get("tipo", "?") for _, _, data in G.edges(data=True))

stats = f"""
ESTATÍSTICAS DO GRAFO — Conflito de Interesse AM
=================================================

Vértices (nós)  : {n_vertices:,}
  Pessoa        : {cats['Pessoa']:,}
  Orgao         : {cats['Orgao']:,}
  Empresa       : {cats['Empresa']:,}

Arestas         : {n_arestas:,}
  TRABALHA_EM         : {tipos_aresta['TRABALHA_EM']:,}
  SOCIO_DE            : {tipos_aresta['SOCIO_DE']:,}
  FIRMOU_CONTRATO     : {tipos_aresta['FIRMOU_CONTRATO']:,}
  POSSIVEL_MESMO_QUE  : {tipos_aresta['POSSIVEL_MESMO_QUE']:,}

Grau médio (não-direcionado) : {grau_medio_nd:.4f}

Componentes conexas : {n_cc:,}
  Maior componente   : {tam_ccs[0]:,} vértices
  Tamanho 2          : {sum(1 for t in tam_ccs if t == 2):,} componentes
  Isoladas (tam. 1)  : {sum(1 for t in tam_ccs if t == 1):,} componentes
"""

print(stats)
with open(OUT / "estatisticas.txt", "w", encoding="utf-8") as f:
    f.write(stats)
print("  ✓ data/grafo/estatisticas.txt")

print(f"\n✓ Todos os arquivos salvos em {OUT}/")
