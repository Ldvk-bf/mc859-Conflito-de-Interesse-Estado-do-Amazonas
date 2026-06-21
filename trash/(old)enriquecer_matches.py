"""
Enriquece matches_nomes.csv com dados dos contratos firmados pelas empresas.

Mudanças em relação à versão anterior:
  1. Uma linha por contrato — a descrição, data e valor de cada contrato aparecem
     individualmente, não agregados.
  2. Mapeamento via institutions.csv — resolve casos como "MAT ANA BRAGA" → SES,
     onde o nome no contrato é diferente da pasta da folha de pagamento.

Saída: data/matches_com_contratos.csv
"""

import csv
import re
import unicodedata
from collections import defaultdict
from pathlib import Path

MATCHES      = Path("data/dados_derivados/nome_funcionario-nome_socio.csv")
CONTRATOS    = Path("data/dados_base/orgao_publico-empresa(contratos).csv")
INSTITUTIONS = Path("data/dados_derivados/instituto_contrato-folha_pagamento.csv")
SAIDA        = Path("data/dados_derivados/matches_com_contratos.csv")

COLUNAS_SAIDA = [
    # ── Funcionário ──────────────────────────────────────────────────────────
    "nome_funcionario", "orgao", "lotacao_funcionario",
    "periodo_inicio", "periodo_fim", "cargo", "vinculo",
    # ── Sócio / Empresa ──────────────────────────────────────────────────────
    "nome_socio", "cnpj_empresa", "razao_social", "qualificacao",
    # ── Qualidade do match de nome ───────────────────────────────────────────
    "score", "metodo",
    # ── Contrato (uma linha por contrato) ────────────────────────────────────
    "orgao_contrato", "data_contrato", "descricao_contrato",
    "valor_unitario", "valor_final",
    # ── Flag de conflito ─────────────────────────────────────────────────────
    "conflito_direto",   # SIM = empresa contratou com o mesmo órgão do funcionário
]


# ── Helpers ───────────────────────────────────────────────────────────────────

def normalizar_cnpj(cnpj: str) -> str:
    return re.sub(r"\D", "", cnpj.strip())


def normalizar_texto(s: str) -> str:
    """Maiúsculo, sem acento, sem pontuação, espaços simples."""
    s = s.strip().upper()
    s = unicodedata.normalize("NFD", s)
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    s = re.sub(r"[^A-Z0-9\s]", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def parsear_valor(v: str) -> float:
    if not v:
        return 0.0
    v = v.strip().replace(".", "").replace(",", ".")
    try:
        return float(v)
    except ValueError:
        return 0.0


def formatar_valor(v: float) -> str:
    """Float → formato brasileiro: 1234567.89 → '1.234.567,89'"""
    return f"{v:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


# ── Carregamento do mapeamento de órgãos ─────────────────────────────────────

def carregar_mapeamento_orgaos(caminho: Path) -> dict[str, set[str]]:
    """
    Lê institutions.csv e constrói:
      {orgao_contrato_normalizado: {folha_orgao1, folha_orgao2, ...}}

    Exemplos do CSV:
      MAT ANA BRAGA | SES | MATERNIDADE ANA BRAGA
      CASA CIVIL (SEGOV) | CASA_CIVIL, SEGOV | -

    O campo folha_pag_responsavel pode ter múltiplos valores separados por vírgula.
    """
    mapa: dict[str, set[str]] = defaultdict(set)

    with open(caminho, encoding="utf-8", newline="") as f:
        # Separador é " | " (com espaços)
        reader = csv.reader(f, delimiter="|")
        next(reader)  # pula header
        for row in reader:
            if len(row) < 2:
                continue
            orgao_contrato = normalizar_texto(row[0])
            folhas = [r.strip().upper() for r in row[1].split(",") if r.strip()]
            for folha in folhas:
                # Remove caracteres inválidos mantendo underscores (nomes de pastas)
                folha_norm = re.sub(r"[^A-Z0-9_\s]", "", folha).strip()
                if folha_norm:
                    mapa[orgao_contrato].add(folha_norm)

    return mapa


def folhas_do_contrato(orgao_contrato: str,
                        mapa: dict[str, set[str]]) -> set[str]:
    """
    Retorna o conjunto de pastas da folha que correspondem ao órgão do contrato.
    Tenta match exato primeiro; se não encontrar, tenta match por prefixo
    (cobre variantes como "CETAM (CETAM)" quando no mapa está "CETAM").
    """
    chave = normalizar_texto(orgao_contrato)

    if chave in mapa:
        return mapa[chave]

    # Fallback: procura no mapa alguma chave que seja prefixo ou vice-versa
    for k, folhas in mapa.items():
        if chave.startswith(k) or k.startswith(chave):
            return folhas

    return set()


# ── Carregamento dos contratos ────────────────────────────────────────────────

def carregar_contratos(caminho: Path) -> dict[str, list[dict]]:
    """Retorna {cnpj_normalizado: [contratos]}."""
    por_cnpj: dict[str, list[dict]] = defaultdict(list)
    with open(caminho, encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f, delimiter=";"):
            cnpj = normalizar_cnpj(row.get("CNPJ_Fornecedor", ""))
            if not cnpj:
                continue
            por_cnpj[cnpj].append({
                "orgao_contrato": row.get("Orgao_Publico", "").strip(),
                "data":           row.get("Data_Assinatura", "").strip(),
                "descricao":      row.get("Descricao_Contrato", "").strip(),
                "valor_unitario": parsear_valor(row.get("Valor_Unitario", "")),
                "valor_final":    parsear_valor(row.get("Valor_Final", "")),
            })
    return por_cnpj


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print("Carregando mapeamento de órgãos (institutions.csv)...")
    mapa_orgaos = carregar_mapeamento_orgaos(INSTITUTIONS)
    print(f"  {len(mapa_orgaos):,} órgãos de contrato mapeados")

    print("\nCarregando contratos...")
    contratos_por_cnpj = carregar_contratos(CONTRATOS)
    total = sum(len(v) for v in contratos_por_cnpj.values())
    print(f"  {total:,} contratos | {len(contratos_por_cnpj):,} empresas")

    print(f"\nCarregando matches de {MATCHES}...")
    with open(MATCHES, encoding="utf-8", newline="") as f:
        matches = list(csv.DictReader(f))
    print(f"  {len(matches):,} matches")

    print("\nEnriquecendo e expandindo por contrato...")

    resultados = []
    sem_contrato = 0
    conflitos_diretos = 0
    linhas_conflito = 0

    for match in matches:
        cnpj        = normalizar_cnpj(match.get("cnpj_empresa", ""))
        orgao_func  = match.get("orgao", "").strip().upper()  # ex: "SES", "FCECON"

        contratos_empresa = contratos_por_cnpj.get(cnpj, [])

        # Campos comuns do match (funcionário + sócio + score)
        base = {
            "nome_funcionario":   match.get("nome_funcionario", ""),
            "orgao":              match.get("orgao", ""),
            "lotacao_funcionario": match.get("lotacao", ""),
            "periodo_inicio":     match.get("periodo_inicio", ""),
            "periodo_fim":        match.get("periodo_fim", ""),
            "cargo":              match.get("cargo", ""),
            "vinculo":            match.get("vinculo", ""),
            "nome_socio":         match.get("nome_socio", ""),
            "cnpj_empresa":       match.get("cnpj_empresa", ""),
            "razao_social":       match.get("razao_social", ""),
            "qualificacao":       match.get("qualificacao", ""),
            "score":              match.get("score", ""),
            "metodo":             match.get("metodo", ""),
        }

        if not contratos_empresa:
            sem_contrato += 1
            resultados.append({
                **base,
                "orgao_contrato":    "",
                "data_contrato":     "",
                "descricao_contrato": "",
                "valor_unitario":    "",
                "valor_final":       "",
                "conflito_direto":   "NAO",
            })
            continue

        # Verifica se algum contrato é com o mesmo órgão do funcionário
        encontrou_conflito = False
        for c in contratos_empresa:
            folhas_contrato = folhas_do_contrato(c["orgao_contrato"], mapa_orgaos)

            # Conflito direto: a folha do funcionário está no conjunto de folhas
            # que o institutions.csv associa ao órgão do contrato
            conflito = orgao_func in folhas_contrato

            if conflito:
                if not encontrou_conflito:
                    encontrou_conflito = True
                    conflitos_diretos += 1
                linhas_conflito += 1

            resultados.append({
                **base,
                "orgao_contrato":     c["orgao_contrato"],
                "data_contrato":      c["data"],
                "descricao_contrato": c["descricao"],
                "valor_unitario":     formatar_valor(c["valor_unitario"]),
                "valor_final":        formatar_valor(c["valor_final"]),
                "conflito_direto":    "SIM" if conflito else "NAO",
            })

    # Ordena: conflitos primeiro, depois score desc, depois data desc
    resultados.sort(key=lambda r: (
        0 if r["conflito_direto"] == "SIM" else 1,
        -float(str(r.get("score") or "0").replace(",", ".")),
        r.get("data_contrato", ""),
    ))

    SAIDA.parent.mkdir(exist_ok=True)
    with open(SAIDA, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=COLUNAS_SAIDA)
        writer.writeheader()
        writer.writerows(resultados)

    print(f"\nResultados:")
    print(f"  Linhas totais geradas:          {len(resultados):,}")
    print(f"  Matches sem contrato:           {sem_contrato:,}")
    print(f"  Pessoas com conflito direto:    {conflitos_diretos:,}")
    print(f"  Linhas de conflito direto:      {linhas_conflito:,}")
    print(f"\nArquivo gerado: {SAIDA}")

    # Preview
    conflitos = [r for r in resultados if r["conflito_direto"] == "SIM"]
    print(f"\n{'='*90}")
    print(f"PREVIEW — primeiros conflitos diretos")
    print(f"{'='*90}")
    for r in conflitos[:12]:
        print(
            f"\n  [{r['score']} | {r['metodo']}] {r['nome_funcionario']}\n"
            f"  Órgão func : {r['orgao']} ({r['periodo_inicio']} → {r['periodo_fim']}) | {r['cargo']}\n"
            f"  Empresa    : {r['razao_social']} ({r['cnpj_empresa']}) | {r['qualificacao']}\n"
            f"  Contrato   : {r['orgao_contrato']} | {r['data_contrato']} | R$ {r['valor_final']}\n"
            f"  Descrição  : {r['descricao_contrato'][:100]}"
        )


if __name__ == "__main__":
    main()
