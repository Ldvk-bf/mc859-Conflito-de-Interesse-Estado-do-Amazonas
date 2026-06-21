"""
Prepara os CSVs de importação para o Neo4j.

Estrutura gerada em data/neo4j/:
  nodes/
    pessoa.csv              — nós Pessoa (funcionários + sócios unificados)
    orgao.csv               — nós Orgao
    empresa.csv             — nós Empresa
  relationships/
    trabalha_em.csv         — (Pessoa)-[:TRABALHA_EM]->(Orgao)
    socio_de.csv            — (Pessoa)-[:SOCIO_DE]->(Empresa)
    firmou_contrato.csv     — (Orgao)-[:FIRMOU_CONTRATO]->(Empresa)
    possivel_mesmo_que.csv  — (Pessoa)-[:POSSIVEL_MESMO_QUE]->(Pessoa)
                              apenas para matches token_igual e fuzzy

Regra de identidade:
  - Matches "exato": funcionário e sócio têm o mesmo nome_normalizado
    → são o MESMO nó Pessoa (sem relação extra)
  - Matches "token_igual" / "fuzzy": nomes diferentes
    → nós distintos + relação POSSIVEL_MESMO_QUE com score e metodo

Compatível com neo4j-admin database import e LOAD CSV.
"""

import csv
import re
import unicodedata
from collections import defaultdict
from pathlib import Path

# ── Entradas ──────────────────────────────────────────────────────────────────
FUNCIONARIOS = Path("data/dados_base/nome_funcionario-orgao_publico(funcionarios).csv")
SOCIOS       = Path("data/dados_base/nome_socio-empresa(socios).csv")
CONTRATOS    = Path("data/dados_base/orgao_publico-empresa(contratos).csv")
MATCHES      = Path("data/dados_derivados/nome_funcionario-nome_socio.csv")
INSTITUTIONS = Path("data/dados_derivados/instituto_contrato-folha_pagamento.csv")

# ── Saída ─────────────────────────────────────────────────────────────────────
OUT = Path("data/neo4j")


# ── Helpers ───────────────────────────────────────────────────────────────────

def normalizar(s: str) -> str:
    s = s.strip().upper()
    s = unicodedata.normalize("NFD", s)
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    return re.sub(r"\s+", " ", re.sub(r"[^A-Z0-9\s]", " ", s)).strip()


def normalizar_cnpj(cnpj: str) -> str:
    """Remove formatação e valida: retorna string vazia se não tiver 14 dígitos."""
    digits = re.sub(r"\D", "", cnpj.strip())
    if len(digits) != 14:
        return ""  # CPF (11 dígitos), dado corrompido (7 dígitos) ou inválido
    return digits


def salvar(caminho: Path, fieldnames: list[str], rows: list[dict]) -> None:
    caminho.parent.mkdir(parents=True, exist_ok=True)
    with open(caminho, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(rows)
    print(f"  ✓ {caminho.relative_to(Path('.'))} — {len(rows):,} linhas")


# ── Mapeamento orgao_contrato → orgao_folha ───────────────────────────────────

def carregar_mapa_orgaos(caminho: Path) -> dict[str, str]:
    """
    Retorna {orgao_contrato_normalizado: orgao_folha_principal}.
    Quando há múltiplas folhas (CASA_CIVIL, SEGOV) pega a primeira.
    """
    mapa = {}
    with open(caminho, encoding="utf-8", newline="") as f:
        reader = csv.reader(f, delimiter="|")
        next(reader)
        for row in reader:
            if len(row) < 2:
                continue
            chave = normalizar(row[0])
            folha = row[1].split(",")[0].strip().upper()
            folha = re.sub(r"[^A-Z0-9_]", "", folha).strip()
            if chave and folha:
                mapa[chave] = folha
    return mapa


def orgao_folha(orgao_contrato: str, mapa: dict[str, str]) -> str:
    """Resolve o nome do órgão do contrato para o ID canônico da folha."""
    chave = normalizar(orgao_contrato)
    if chave in mapa:
        return mapa[chave]
    # fallback: prefixo
    for k, v in mapa.items():
        if chave.startswith(k) or k.startswith(chave):
            return v
    # sem mapeamento: usa o próprio nome normalizado
    return normalizar(orgao_contrato).replace(" ", "_")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print("Carregando mapeamento de órgãos...")
    mapa_orgaos = carregar_mapa_orgaos(INSTITUTIONS)

    # ──────────────────────────────────────────────────────────────────────────
    # 1. Carrega fontes
    # ──────────────────────────────────────────────────────────────────────────
    print("Carregando funcionários...")
    with open(FUNCIONARIOS, encoding="utf-8", newline="") as f:
        funcionarios = list(csv.DictReader(f))

    print("Carregando sócios...")
    with open(SOCIOS, encoding="utf-8", newline="") as f:
        socios = list(csv.DictReader(f, delimiter=";"))

    print("Carregando contratos...")
    with open(CONTRATOS, encoding="utf-8", newline="") as f:
        contratos = list(csv.DictReader(f, delimiter=";"))

    print("Carregando matches...")
    with open(MATCHES, encoding="utf-8", newline="") as f:
        matches = list(csv.DictReader(f))

    # ──────────────────────────────────────────────────────────────────────────
    # 2. Nós: Orgao
    # ──────────────────────────────────────────────────────────────────────────
    print("\nConstruindo nós...")

    orgaos: dict[str, dict] = {}

    # Orgaos da folha de pagamento (nomes canônicos das pastas)
    for r in funcionarios:
        oid = r["orgao"].strip().upper()
        if oid and oid not in orgaos:
            orgaos[oid] = {"orgaoId:ID(Orgao)": oid, "nome": r["orgao"].strip()}

    # Orgaos dos contratos (mapeados para o ID canônico da folha)
    for r in contratos:
        oid = orgao_folha(r["Orgao_Publico"], mapa_orgaos)
        if oid and oid not in orgaos:
            orgaos[oid] = {"orgaoId:ID(Orgao)": oid, "nome": oid}

    # ──────────────────────────────────────────────────────────────────────────
    # 3. Nós: Empresa
    #    Lookup de razao_social: socios têm o nome, contratos não.
    #    Monta dicionário cnpj → razao_social antes de criar os nós.
    # ──────────────────────────────────────────────────────────────────────────
    razao_por_cnpj: dict[str, str] = {}
    for r in socios:
        cnpj = normalizar_cnpj(r["cnpj_empresa"])
        if cnpj and not razao_por_cnpj.get(cnpj):
            razao_por_cnpj[cnpj] = r["razao_social"].strip()

    empresas: dict[str, dict] = {}

    for r in socios:
        cnpj = normalizar_cnpj(r["cnpj_empresa"])
        if cnpj and cnpj not in empresas:
            empresas[cnpj] = {
                "empresaId:ID(Empresa)": cnpj,
                "cnpj": cnpj,
                "razao_social": r["razao_social"].strip(),
            }

    for r in contratos:
        cnpj = normalizar_cnpj(r["CNPJ_Fornecedor"])
        if cnpj and cnpj not in empresas:
            empresas[cnpj] = {
                "empresaId:ID(Empresa)": cnpj,
                "cnpj": cnpj,
                "razao_social": razao_por_cnpj.get(cnpj, ""),
            }

    # ──────────────────────────────────────────────────────────────────────────
    # 4. Nós: Pessoa
    #    ID = nome_normalizado
    #    Matches "exato": funcionário e sócio compartilham o mesmo nome_normalizado
    #    → mesmo nó, sem duplicata
    # ──────────────────────────────────────────────────────────────────────────
    pessoas: dict[str, dict] = {}

    # Funcionários
    for r in funcionarios:
        pid = r["nome_normalizado"].strip()
        if not pid:
            continue
        if pid not in pessoas:
            pessoas[pid] = {
                "pessoaId:ID(Pessoa)": pid,
                "nome":            r["nome"].strip(),
                "nome_normalizado": pid,
                "tipo":            "funcionario",
            }

    # Sócios (normaliza o nome para criar/mergear o nó)
    for r in socios:
        nome_raw  = r["nome_socio"].strip()
        nome_norm = normalizar(nome_raw)
        nome_norm = re.sub(r"\s+", " ", re.sub(r"[^A-Z\s]", "", nome_norm)).strip()
        if not nome_norm:
            continue
        if nome_norm in pessoas:
            # Já existe como funcionário — promove para "ambos"
            pessoas[nome_norm]["tipo"] = "ambos"
        else:
            pessoas[nome_norm] = {
                "pessoaId:ID(Pessoa)": nome_norm,
                "nome":            nome_raw,
                "nome_normalizado": nome_norm,
                "tipo":            "socio",
            }

    # ──────────────────────────────────────────────────────────────────────────
    # 5. Relacionamento: TRABALHA_EM
    # ──────────────────────────────────────────────────────────────────────────
    trabalha_em = []
    for r in funcionarios:
        pid = r["nome_normalizado"].strip()
        oid = r["orgao"].strip().upper()
        if not pid or not oid:
            continue
        trabalha_em.append({
            ":START_ID(Pessoa)":  pid,
            ":END_ID(Orgao)":     oid,
            ":TYPE":              "TRABALHA_EM",
            "periodo_inicio":     r.get("periodo_inicio", ""),
            "periodo_fim":        r.get("periodo_fim", ""),
            "lotacao":            r.get("lotacao", ""),
            "cargo":              r.get("cargo", ""),
            "funcao":             r.get("funcao", ""),
            "vinculo":            r.get("vinculo", ""),
            "remuneracao_total":  r.get("remuneracao_total", ""),
        })

    # ──────────────────────────────────────────────────────────────────────────
    # 6. Relacionamento: SOCIO_DE
    # ──────────────────────────────────────────────────────────────────────────
    socio_de = []
    for r in socios:
        nome_raw  = r["nome_socio"].strip()
        nome_norm = normalizar(nome_raw)
        nome_norm = re.sub(r"\s+", " ", re.sub(r"[^A-Z\s]", "", nome_norm)).strip()
        cnpj      = normalizar_cnpj(r["cnpj_empresa"])
        if not nome_norm or not cnpj:
            continue
        socio_de.append({
            ":START_ID(Pessoa)":   nome_norm,
            ":END_ID(Empresa)":    cnpj,
            ":TYPE":               "SOCIO_DE",
            "qualificacao":        r.get("qualificacao", "").strip(),
            "cpf_parcial":         r.get("cpf_cnpj_socio", "").strip(),
        })

    # ──────────────────────────────────────────────────────────────────────────
    # 7. Relacionamento: FIRMOU_CONTRATO
    # ──────────────────────────────────────────────────────────────────────────
    firmou_contrato = []
    for r in contratos:
        oid  = orgao_folha(r["Orgao_Publico"], mapa_orgaos)
        cnpj = normalizar_cnpj(r["CNPJ_Fornecedor"])
        if not oid or not cnpj:
            continue
        firmou_contrato.append({
            ":START_ID(Orgao)":    oid,
            ":END_ID(Empresa)":    cnpj,
            ":TYPE":               "FIRMOU_CONTRATO",
            "orgao_original":      r["Orgao_Publico"].strip(),
            "data":                r.get("Data_Assinatura", "").strip(),
            "descricao":           r.get("Descricao_Contrato", "").strip(),
            "valor_final":         r.get("Valor_Final", "").strip(),
        })

    # ──────────────────────────────────────────────────────────────────────────
    # 8. Relacionamento: POSSIVEL_MESMO_QUE
    #    Apenas para matches não-exatos (token_igual, fuzzy)
    #    Matches exatos já compartilham o mesmo nó — não precisam de relação
    # ──────────────────────────────────────────────────────────────────────────
    possivel_mesmo_que = []
    for r in matches:
        metodo = r.get("metodo", "").strip()
        if metodo == "exato":
            continue  # mesmo nó, sem relação

        pid_func  = r["nome_funcionario_normalizado"].strip()
        pid_socio = r["nome_socio_normalizado"].strip()

        if not pid_func or not pid_socio or pid_func == pid_socio:
            continue

        possivel_mesmo_que.append({
            ":START_ID(Pessoa)": pid_func,
            ":END_ID(Pessoa)":   pid_socio,
            ":TYPE":             "POSSIVEL_MESMO_QUE",
            "score":             r.get("score", ""),
            "metodo":            metodo,
        })

    # ──────────────────────────────────────────────────────────────────────────
    # 9. Salva todos os arquivos
    # ──────────────────────────────────────────────────────────────────────────
    print("\nSalvando arquivos...")

    salvar(
        OUT / "nodes" / "pessoa.csv",
        ["pessoaId:ID(Pessoa)", "nome", "nome_normalizado", "tipo"],
        list(pessoas.values()),
    )
    salvar(
        OUT / "nodes" / "orgao.csv",
        ["orgaoId:ID(Orgao)", "nome"],
        list(orgaos.values()),
    )
    salvar(
        OUT / "nodes" / "empresa.csv",
        ["empresaId:ID(Empresa)", "cnpj", "razao_social"],
        list(empresas.values()),
    )
    salvar(
        OUT / "relationships" / "trabalha_em.csv",
        [":START_ID(Pessoa)", ":END_ID(Orgao)", ":TYPE",
         "periodo_inicio", "periodo_fim", "lotacao", "cargo", "funcao", "vinculo", "remuneracao_total"],
        trabalha_em,
    )
    salvar(
        OUT / "relationships" / "socio_de.csv",
        [":START_ID(Pessoa)", ":END_ID(Empresa)", ":TYPE",
         "qualificacao", "cpf_parcial"],
        socio_de,
    )
    salvar(
        OUT / "relationships" / "firmou_contrato.csv",
        [":START_ID(Orgao)", ":END_ID(Empresa)", ":TYPE",
         "orgao_original", "data", "descricao", "valor_final"],
        firmou_contrato,
    )
    salvar(
        OUT / "relationships" / "possivel_mesmo_que.csv",
        [":START_ID(Pessoa)", ":END_ID(Pessoa)", ":TYPE", "score", "metodo"],
        possivel_mesmo_que,
    )

    # ── Resumo ────────────────────────────────────────────────────────────────
    funcionarios_tipo = sum(1 for p in pessoas.values() if p["tipo"] == "funcionario")
    socios_tipo       = sum(1 for p in pessoas.values() if p["tipo"] == "socio")
    ambos_tipo        = sum(1 for p in pessoas.values() if p["tipo"] == "ambos")

    print(f"""
Resumo dos nós:
  Pessoa   : {len(pessoas):>8,}  (funcionario: {funcionarios_tipo:,} | socio: {socios_tipo:,} | ambos: {ambos_tipo:,})
  Orgao    : {len(orgaos):>8,}
  Empresa  : {len(empresas):>8,}

Resumo das relações:
  TRABALHA_EM         : {len(trabalha_em):>8,}
  SOCIO_DE            : {len(socio_de):>8,}
  FIRMOU_CONTRATO     : {len(firmou_contrato):>8,}
  POSSIVEL_MESMO_QUE  : {len(possivel_mesmo_que):>8,}

Pessoas tipo "ambos" (match exato — mesmo nó no grafo): {ambos_tipo:,}
""")


if __name__ == "__main__":
    main()
