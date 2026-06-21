"""
Anonimiza os arquivos GEXF substituindo o nome das pessoas por um hash curto.

  - Apenas nós com categoria == "Pessoa" são anonimizados
  - Órgãos e Empresas mantêm seus nomes (já são dados públicos)
  - A tabela de mapeamento (nome → hash) fica SOMENTE no computador local
    e está listada no .gitignore

Hash usado: SHA-256 truncado para N hex chars (padrão 9 = 36 bits).
  Com 149k pessoas a probabilidade de colisão é < 0,5%.
  Se colisão detectada, sobe automaticamente para 10 chars.

Saídas:
  data/gexf/grafo_geral_anonimo.gexf.gz
  data/gexf/conflito_interesse_small_anonimo.gexf.gz
  data/privado/tabela_hash_pessoas.csv   ← NÃO subir para o GitHub
"""

import csv
import gzip
import hashlib
import shutil
from pathlib import Path

import networkx as nx

# ── Configurações ─────────────────────────────────────────────────────────────

OUT     = Path("data/gexf")
PRIVADO = Path("data/privado")   # pasta que deve estar no .gitignore
PRIVADO.mkdir(parents=True, exist_ok=True)

HASH_CHARS_INICIAL = 10   # tenta primeiro com 9; sobe para 10 se houver colisão

GRAFOS = [
    OUT / "grafo_geral.gexf",
    OUT / "conflito_interesse_small.gexf",
]

TABELA_HASH = PRIVADO / "tabela_hash_pessoas.csv"


# ── Hash ──────────────────────────────────────────────────────────────────────

def hash_nome(nome: str, n_chars: int) -> str:
    """Retorna os primeiros n_chars do SHA-256 do nome em hexadecimal maiúsculo."""
    return hashlib.sha256(nome.encode("utf-8")).hexdigest()[:n_chars].upper()


# ── Coleta todos os nomes de Pessoa de todos os grafos ────────────────────────

def coletar_nomes(grafos: list[Path]) -> set[str]:
    nomes = set()
    for caminho in grafos:
        if not caminho.exists():
            print(f"⚠  Não encontrado: {caminho}")
            continue
        print(f"  Lendo {caminho.name}...")
        G = nx.read_gexf(caminho)
        for _, data in G.nodes(data=True):
            if data.get("categoria") == "Pessoa":
                label = data.get("label", "")
                if label:
                    nomes.add(label)
    return nomes


# ── Constrói tabela hash sem colisões ─────────────────────────────────────────

def construir_tabela(nomes: set[str]) -> tuple[dict[str, str], int]:
    """
    Retorna (tabela nome→hash, n_chars usado).
    Aumenta n_chars automaticamente se houver colisão.
    """
    n = HASH_CHARS_INICIAL
    while True:
        tabela: dict[str, str] = {}
        inverso: dict[str, str] = {}   # hash → nome (para detectar colisão)
        colisoes = 0

        for nome in nomes:
            h = hash_nome(nome, n)
            if h in inverso and inverso[h] != nome:
                colisoes += 1
            else:
                inverso[h] = nome
                tabela[nome] = h

        if colisoes == 0:
            print(f"  Hash de {n} chars — {len(tabela):,} pessoas — 0 colisões ✓")
            return tabela, n
        else:
            print(f"  Hash de {n} chars — {colisoes} colisões detectadas → tentando {n+1}...")
            n += 1


# ── Anonimiza um grafo e salva comprimido ─────────────────────────────────────

def anonimizar(caminho: Path, tabela: dict[str, str]) -> Path:
    print(f"\n  Anonimizando {caminho.name}...")
    G = nx.read_gexf(caminho)

    # 1. Atualiza label e limpa campos identificadores nos atributos do nó
    substituidos = 0
    for node_id, data in G.nodes(data=True):
        if data.get("categoria") == "Pessoa":
            label = data.get("label", "")
            h = tabela.get(label)
            if h:
                data["label"] = h
                data.pop("nome_normalizado", None)
                substituidos += 1

    # 2. Remapeia os IDs dos nós Pessoa → hash
    #    nx.relabel_nodes atualiza automaticamente todas as arestas
    mapa_ids = {}
    for node_id, data in G.nodes(data=True):
        if data.get("categoria") == "Pessoa":
            label_hash = data.get("label", "")  # já é o hash após passo 1
            if label_hash:
                mapa_ids[node_id] = label_hash

    G = nx.relabel_nodes(G, mapa_ids)

    saida = OUT / (caminho.stem + "_anonimo.gexf")
    saida_gz = OUT / (caminho.stem + "_anonimo.gexf.gz")

    nx.write_gexf(G, saida)

    # Comprime e remove o não-comprimido
    with open(saida, "rb") as f_in, gzip.open(saida_gz, "wb") as f_out:
        shutil.copyfileobj(f_in, f_out)
    saida.unlink()

    tamanho = saida_gz.stat().st_size / 1_048_576
    print(f"  ✓ {saida_gz.name}  ({tamanho:.1f} MB)  — {substituidos:,} pessoas substituídas")
    return saida_gz


# ── Salva tabela de mapeamento ────────────────────────────────────────────────

def salvar_tabela(tabela: dict[str, str], n_chars: int):
    with open(TABELA_HASH, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["nome_original", f"hash_sha256_{n_chars}chars"])
        for nome, h in sorted(tabela.items()):
            w.writerow([nome, h])
    print(f"\n  ✓ Tabela salva em {TABELA_HASH}  ({len(tabela):,} entradas)")
    print(f"     ⚠  NÃO suba esse arquivo para o GitHub!")


# ── .gitignore ────────────────────────────────────────────────────────────────

def garantir_gitignore():
    gitignore = Path(".gitignore")
    linhas_novas = [
        "# Dados privados — tabela de anonimização",
        "data/privado/",
        "# GEXFs originais grandes (use os _anonimo.gexf.gz)",
        "data/grafo/grafo_geral.gexf",
        "data/grafo/grafo_geral_label_orgao.gexf",
    ]
    existentes = set()
    if gitignore.exists():
        existentes = set(gitignore.read_text(encoding="utf-8").splitlines())

    novas = [l for l in linhas_novas if l not in existentes]
    if novas:
        with open(gitignore, "a", encoding="utf-8") as f:
            f.write("\n" + "\n".join(novas) + "\n")
        print(f"  ✓ .gitignore atualizado com {len(novas)} entradas")
    else:
        print("  ✓ .gitignore já estava atualizado")


# ── Main ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("1. Coletando nomes de todos os grafos...")
    nomes = coletar_nomes(GRAFOS)
    print(f"  Total de pessoas únicas: {len(nomes):,}")

    print("\n2. Construindo tabela hash...")
    tabela, n_chars = construir_tabela(nomes)

    print("\n3. Anonimizando grafos...")
    for caminho in GRAFOS:
        if caminho.exists():
            anonimizar(caminho, tabela)

    print("\n4. Salvando tabela de mapeamento (local)...")
    salvar_tabela(tabela, n_chars)

    # print("\n5. Atualizando .gitignore...")
    # garantir_gitignore()

    print(f"""
{'═'*60}
  Concluído!

  Arquivos para subir no GitHub / Zenodo:
    data/grafo/*_anonimo.gexf.gz

  Arquivo SOMENTE LOCAL (não subir):
    {TABELA_HASH}

  Para reverter um hash de volta ao nome:
    grep <hash> {TABELA_HASH}
{'═'*60}
""")
