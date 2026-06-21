"""
Matching por similaridade de nome entre sócios de empresas e funcionários públicos.

Entrada:
  data/dados_base/nome_funcionario-orgao_publico(funcionarios).csv
  data/dados_base/nome_socio-empresa(socios).csv

Saída:
  data/dados_derivados/nome_funcionario-nome_socio.csv

Pipeline:
  1. Normalizar      — remove acentos, pontuação, caixa alta, espaços duplos
  2. Match exato     — nome_normalizado idêntico, score 100
  3. Blocking        — índice invertido nos funcionários; candidatos com >= MIN_TOKENS_COMUNS
                       tokens significativos em comum com o sócio
  4. Fuzzy           — max(token_sort_ratio, token_set_ratio) sobre os candidatos
                       token_set_ratio lida com nomes abreviados/incompletos
                       token_sort_ratio lida com ordem diferente dos tokens
  5. Filtro 1º nome  — primeiro nome deve ser idêntico ou foneticamente equivalente (Soundex)
  6. Threshold       — ajustado pelo nº de tokens do sócio (nomes curtos exigem score maior)
  7. Dedup           — remove pares (funcionário, sócio, cnpj, orgao) duplicados

Iteração sobre sócios (lista menor, ~12k) contra índice de funcionários (~158k).
"""

import csv
import re
import sys
import unicodedata
from collections import defaultdict
from pathlib import Path

import jellyfish
from rapidfuzz import fuzz

# ── Configurações ──────────────────────────────────────────────────────────────
FOLHA      = Path("data/dados_base/nome_funcionario-orgao_publico(funcionarios).csv")
SOCIEDADES = Path("data/dados_base/nome_socio-empresa(socios).csv")
SAIDA      = Path("data/dados_derivados/nome_funcionario-nome_socio.csv")

# Threshold base; nomes curtos exigem mais (ver threshold_para)
SCORE_BASE        = 92
MIN_TOKENS_COMUNS = 2

STOPWORDS = {"DE", "DA", "DO", "DOS", "DAS", "E", "EM", "A", "O", "AS", "OS",
             "DI", "DU", "VAN", "VON", "EL"}

COLUNAS_SAIDA = [
    "nome_funcionario_normalizado",
    "orgao",
    "nome_socio_normalizado",
    "cnpj_empresa",
    "razao_social",
    "score",
    "metodo",
]
# ────────────────────────────────────────────────────────────────────────────────


def normalizar(nome: str) -> str:
    """Maiúsculo, sem acento, sem pontuação, espaços simples."""
    nome = nome.strip().upper()
    nome = unicodedata.normalize("NFD", nome)
    nome = "".join(c for c in nome if unicodedata.category(c) != "Mn")
    nome = re.sub(r"[^A-Z\s]", "", nome)
    return re.sub(r"\s+", " ", nome).strip()


def tokens_significativos(nome_norm: str) -> set[str]:
    return {t for t in nome_norm.split() if t not in STOPWORDS and len(t) > 1}


def threshold_para(n_tokens_socio: int) -> int:
    """
    Nomes curtos (2 tokens) têm muito mais chance de coincidência casual.
    Escala o threshold de acordo com o comprimento do nome do sócio.
    """
    if n_tokens_socio <= 2:
        return 95
    if n_tokens_socio == 3:
        return 93
    return SCORE_BASE  # 4+ tokens


def primeiro_nome_ok(pn_func: str, pn_socio: str) -> bool:
    """
    Retorna True se os primeiros nomes são idênticos ou foneticamente
    equivalentes via Soundex (captura CESAR/CEZAR, KELLY/KELLI etc.).
    """
    if not pn_func or not pn_socio:
        return False
    if pn_func == pn_socio:
        return True
    return jellyfish.soundex(pn_func) == jellyfish.soundex(pn_socio)


def carregar_socios() -> list[dict]:
    socios = []
    with open(SOCIEDADES, encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f, delimiter=";"):
            nome = r.get("nome_socio", "").strip()
            if not nome:
                continue
            upper = nome.upper()
            if any(x in upper for x in ("LTDA", "S/A", "EIRELI", "CIA ", "S.A", "ME ", "EPP")):
                continue
            norm = normalizar(nome)
            tokens = tokens_significativos(norm)
            partes = norm.split()
            socios.append({
                "nome_socio_normalizado": norm,
                "tokens":                tokens,
                "n_tokens":              len(partes),
                "primeiro_nome":         partes[0] if partes else "",
                "cnpj_empresa":          r.get("cnpj_empresa", "").strip(),
                "razao_social":          r.get("razao_social", "").strip(),
                "qualificacao":          r.get("qualificacao", "").strip(),
            })
    return socios


def carregar_funcionarios() -> list[dict]:
    with open(FOLHA, encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))
    resultado = []
    for r in rows:
        norm = r.get("nome_normalizado", "").strip()
        if not norm:
            continue
        partes = norm.split()
        resultado.append({
            "nome_normalizado": norm,
            "orgao":            r.get("orgao", "").strip(),
            "tokens":           tokens_significativos(norm),
            "n_tokens":         len(partes),
            "primeiro_nome":    partes[0] if partes else "",
        })
    return resultado


def construir_indice_funcionarios(funcs: list[dict]) -> dict[str, list[int]]:
    """Índice invertido: token → [índices de funcionários que têm esse token]."""
    indice: dict[str, list[int]] = defaultdict(list)
    for i, f in enumerate(funcs):
        for token in f["tokens"]:
            indice[token].append(i)
    return indice


def main():
    print("Carregando funcionários...")
    funcionarios = carregar_funcionarios()
    print(f"  {len(funcionarios):,} funcionários carregados")

    print("Construindo índice invertido de funcionários...")
    indice = construir_indice_funcionarios(funcionarios)
    print(f"  {len(indice):,} tokens indexados")

    # Lookup exato O(1) sobre funcionários
    exato_idx: dict[str, list[int]] = defaultdict(list)
    for i, f in enumerate(funcionarios):
        exato_idx[f["nome_normalizado"]].append(i)

    print(f"\nCarregando sócios de {SOCIEDADES}...")
    socios = carregar_socios()
    print(f"  {len(socios):,} sócios PF carregados")

    print(f"\nIniciando matching (score base: {SCORE_BASE})...")

    resultados = []
    sem_candidato = 0

    for n, socio in enumerate(socios, 1):
        if n % 2000 == 0:
            print(f"  [{n:,}/{len(socios):,}] matches até agora: {len(resultados):,}")

        nome_socio = socio["nome_socio_normalizado"]
        tokens_socio = socio["tokens"]
        pn_socio = socio["primeiro_nome"]
        threshold = threshold_para(socio["n_tokens"])

        # ── Camada 1: match exato ──────────────────────────────────────────────
        if nome_socio in exato_idx:
            for idx in exato_idx[nome_socio]:
                f = funcionarios[idx]
                resultados.append(_linha(f, socio, score=100, metodo="exato"))
            continue

        # ── Camada 2: blocking por índice invertido ────────────────────────────
        if len(tokens_socio) < 2:
            sem_candidato += 1
            continue

        contagem: dict[int, int] = defaultdict(int)
        for token in tokens_socio:
            for idx in indice.get(token, []):
                contagem[idx] += 1

        candidatos = [idx for idx, qtd in contagem.items() if qtd >= MIN_TOKENS_COMUNS]

        if not candidatos:
            sem_candidato += 1
            continue

        # ── Camada 3: fuzzy + filtro primeiro nome + threshold por tamanho ─────
        for idx in candidatos:
            f = funcionarios[idx]

            # Filtro de primeiro nome (exato ou Soundex) — condição obrigatória
            if not primeiro_nome_ok(f["primeiro_nome"], pn_socio):
                continue

            # max das duas métricas: token_sort lida com ordem, token_set com abreviações
            score_sort = fuzz.token_sort_ratio(nome_socio, f["nome_normalizado"])
            score_set  = fuzz.token_set_ratio(nome_socio, f["nome_normalizado"])
            score = max(score_sort, score_set)

            if score < threshold:
                continue

            # token_sort/set = 100 com tokens idênticos mas primeiro nome diferente
            # já foi filtrado acima; aqui reduzimos para 95 para distinguir do exato
            if score == 100:
                metodo      = "token_igual"
                score_final = 95
            else:
                metodo      = "fuzzy"
                score_final = score

            resultados.append(_linha(f, socio, score=score_final, metodo=metodo))

    # ── Deduplicação ───────────────────────────────────────────────────────────
    vistos: set[tuple] = set()
    dedup = []
    for r in resultados:
        chave = (r["nome_funcionario_normalizado"], r["nome_socio_normalizado"],
                 r["cnpj_empresa"], r["orgao"])
        if chave not in vistos:
            vistos.add(chave)
            dedup.append(r)

    dedup.sort(key=lambda r: -float(str(r["score"]).replace(",", ".")))

    # ── Relatório ──────────────────────────────────────────────────────────────
    faixas = {"100 (exato)": 0, "95 (token_igual)": 0, "93-94 (fuzzy alto)": 0,
              "92 (fuzzy base)": 0, "revisao_manual (<92 no exato)": 0}
    for r in dedup:
        s = float(str(r["score"]).replace(",", "."))
        m = r["metodo"]
        if m == "exato":
            faixas["100 (exato)"] += 1
        elif m == "token_igual":
            faixas["95 (token_igual)"] += 1
        elif s >= 93:
            faixas["93-94 (fuzzy alto)"] += 1
        else:
            faixas["92 (fuzzy base)"] += 1

    print(f"\nResultados:")
    print(f"  Total de matches: {len(dedup):,}")
    print(f"  Sócios sem candidato suficiente: {sem_candidato:,}")
    for faixa, qtd in faixas.items():
        print(f"  Score {faixa}: {qtd:,}")

    SAIDA.parent.mkdir(exist_ok=True)
    with open(SAIDA, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=COLUNAS_SAIDA)
        writer.writeheader()
        writer.writerows(dedup)

    print(f"\nArquivo gerado: {SAIDA}")
    print("\nExemplos de matches encontrados:")
    for r in dedup[:10]:
        print(f"  [{r['score']:>6} | {r['metodo']:<12}] "
              f"{r['nome_funcionario_normalizado'][:35]:<35} ({r['orgao'][:15]})"
              f"  ↔  {r['nome_socio_normalizado'][:35]:<35} ({r['razao_social'][:25]})")


def _linha(func: dict, socio: dict, score: int, metodo: str) -> dict:
    return {
        "nome_funcionario_normalizado": func["nome_normalizado"],
        "orgao":                       func["orgao"],
        "nome_socio_normalizado":      socio["nome_socio_normalizado"],
        "cnpj_empresa":                socio["cnpj_empresa"],
        "razao_social":                socio["razao_social"],
        "score":                       f"{score:.2f}".replace(".", ","),
        "metodo":                      metodo,
    }


if __name__ == "__main__":
    main()
