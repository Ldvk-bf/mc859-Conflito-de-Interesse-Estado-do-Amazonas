"""
Classifica os conflitos de interesse por categoria de suspeição.

Categorias:
  1. EMPRESA_PROPRIO_NOME  — empresa com nome/iniciais do funcionário
  2. ESTRUTURA_SISTEMICA   — empresa com muitos servidores do mesmo órgão como sócios
  3. SETOR_NAO_RELACIONADO — empresa de setor diferente da atividade do órgão
  4. MEDICO_INSTITUTO      — médico sócio de instituto/clínica que presta serviço ao órgão

Saída: data/conflitos_classificados.csv
"""

import csv
import re
import unicodedata
from collections import defaultdict
from pathlib import Path

NEO4J = Path("data/neo4j")
SAIDA = Path("data/conflitos_classificados.csv")

# ── Palavras que indicam empresa médica/saúde ────────────────────────────────
PALAVRAS_MEDICAS = {
    "MEDIC", "CLINICA", "CIRURGI", "PEDIATR", "GASTRO", "INSTITUTO DE",
    "ANESTESIO", "ORTOPED", "TRAUMA", "GINECOL", "OBSTET", "CARDIO",
    "NEURO", "OFTALM", "DERMATO", "ONCOL", "HEMATO", "UROLOG", "NEFROL",
    "PULMO", "INTENSIV", "ENFERMEI", "FISIOTER", "FARMAC", "LABORATOR",
    "IMAGEM", "RADIOLOG", "SAUDE", "HEALTH", "HOSPITAL", "MATERNIDADE",
    "COOPERATIVA DE ENFERM", "COOPERATIVA MEDIC",
}

# ── Palavras de conselhos escolares / associações (baixa suspeição) ──────────
BAIXA_SUSPEICAO = {
    "CONSELHO ESCOLAR", "ASSOCIACAO PESTALOZZI", "COOPERATIVA VERDE",
    "COOPERATIVA MISTA DOS PROD", "ASSOCIACAO DA COMUNIDADE",
    "ASSOC DE PAIS", "ASSOC PAIS MESTRES", "FORUM NACIONAL",
    "FUNDACAO UNIVERSITAS", "INSTITUTO EUVALDO LODI",
    "ASSOCIACAO DOS PROCURADORES",
}


def normalizar(s: str) -> str:
    s = s.strip().upper()
    s = unicodedata.normalize("NFD", s)
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    return re.sub(r"\s+", " ", re.sub(r"[^A-Z0-9\s]", " ", s)).strip()


def iniciais(nome: str) -> set[str]:
    """Gera variações de iniciais do nome para comparar com nome da empresa."""
    tokens = [t for t in nome.split() if len(t) > 1 and t not in
              {"DE", "DA", "DO", "DOS", "DAS", "E", "EM", "A", "O"}]
    if len(tokens) < 2:
        return set()
    # Ex: SUELY CALAZANS BELEM DE OLIVEIRA → "S C B O", "SCB"
    ini = "".join(t[0] for t in tokens)
    return {ini, " ".join(t[0] for t in tokens)}


def empresa_tem_nome_funcionario(nome_func: str, razao_social: str) -> bool:
    """Verifica se razão social contém nome/sobrenome/iniciais do funcionário."""
    tokens_func = [t for t in nome_func.split()
                   if len(t) > 3 and t not in
                   {"DE", "DA", "DO", "DOS", "DAS", "E", "EM", "JOSE",
                    "MARIA", "JOAO", "ANA", "ANTONIO", "FRANCISCO"}]
    empresa_norm = normalizar(razao_social)

    # Sobrenome principal na empresa
    for token in tokens_func[1:]:  # pula o primeiro nome
        if token in empresa_norm:
            return True

    # Iniciais na empresa
    for ini in iniciais(nome_func):
        if empresa_norm.startswith(ini):
            return True

    return False


def is_medica(razao_social: str) -> bool:
    rs = razao_social.upper()
    return any(p in rs for p in PALAVRAS_MEDICAS)


def is_baixa_suspeicao(razao_social: str) -> bool:
    rs = razao_social.upper()
    return any(p in rs for p in BAIXA_SUSPEICAO)


def parsear_valor(v: str) -> float:
    if not v:
        return 0.0
    try:
        return float(v.strip().replace(".", "").replace(",", "."))
    except ValueError:
        return 0.0


def formatar_valor(v: float) -> str:
    return f"{v:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


def data_para_anomes(data: str) -> str:
    """Converte DD/MM/AAAA → AAAA-MM para comparação com periodo_inicio/fim."""
    data = data.strip()
    if not data:
        return ""
    partes = data.split("/")
    if len(partes) == 3:
        return f"{partes[2]}-{partes[1]}"
    return ""


def temporalidade_contrato(data_contrato: str, periodo_inicio: str, periodo_fim: str) -> str:
    """
    Classifica o contrato em relação ao período de trabalho:
      DURANTE     — contrato assinado enquanto o funcionário estava no órgão
      APOS_SAIDA  — contrato assinado depois que o funcionário saiu
      ANTES_ENTRADA — contrato anterior à entrada do funcionário
      SEM_DATA    — falta alguma data para comparar
    """
    anomes_contrato = data_para_anomes(data_contrato)
    if not anomes_contrato or not periodo_inicio or not periodo_fim:
        return "SEM_DATA"
    if anomes_contrato < periodo_inicio:
        return "ANTES_ENTRADA"
    if anomes_contrato <= periodo_fim:
        return "DURANTE"
    return "APOS_SAIDA"


def main():
    print("Carregando nós...")
    pessoas = {}
    with open(NEO4J / "nodes" / "pessoa.csv", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            pid = r["pessoaId:ID(Pessoa)"]
            pessoas[pid] = r

    empresas = {}
    with open(NEO4J / "nodes" / "empresa.csv", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            eid = r["empresaId:ID(Empresa)"]
            empresas[eid] = r

    orgaos = {}
    with open(NEO4J / "nodes" / "orgao.csv", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            oid = r["orgaoId:ID(Orgao)"]
            orgaos[oid] = r

    print("Carregando relacionamentos...")
    # trabalha_em: pessoa → orgao
    trabalha_em: dict[str, list[dict]] = defaultdict(list)
    with open(NEO4J / "relationships" / "trabalha_em.csv", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            trabalha_em[r[":START_ID(Pessoa)"]].append(r)

    # socio_de: pessoa → empresa
    socio_de: dict[str, list[str]] = defaultdict(list)
    with open(NEO4J / "relationships" / "socio_de.csv", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            socio_de[r[":START_ID(Pessoa)"]].append(r[":END_ID(Empresa)"])

    # firmou_contrato: orgao → empresa, com detalhes
    firmou_contrato: dict[tuple, list[dict]] = defaultdict(list)
    with open(NEO4J / "relationships" / "firmou_contrato.csv", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            chave = (r[":START_ID(Orgao)"], r[":END_ID(Empresa)"])
            firmou_contrato[chave].append(r)

    # Índice empresa → set de orgaos que contrataram
    empresa_orgaos: dict[str, set[str]] = defaultdict(set)
    for (oid, eid), contratos in firmou_contrato.items():
        empresa_orgaos[eid].add(oid)

    # Índice empresa → set de funcionários sócios por orgao
    empresa_socios_por_orgao: dict[str, dict[str, set]] = defaultdict(lambda: defaultdict(set))

    print("Detectando conflitos e classificando...")
    conflitos = []

    for pid, emp_list in socio_de.items():
        pessoa = pessoas.get(pid)
        if not pessoa:
            continue

        orgaos_func = trabalha_em.get(pid, [])
        if not orgaos_func:
            continue

        for eid in emp_list:
            empresa = empresas.get(eid)
            if not empresa:
                continue

            for te in orgaos_func:
                oid = te[":END_ID(Orgao)"]
                chave = (oid, eid)
                contratos = firmou_contrato.get(chave, [])
                if not contratos:
                    continue

                # Acumula para detecção de estrutura sistêmica
                empresa_socios_por_orgao[eid][oid].add(pid)

                razao = empresa["razao_social"]
                nome_func = pessoa["nome"]
                nome_norm = pessoa["nome_normalizado"]
                periodo_inicio = te.get("periodo_inicio", "")
                periodo_fim    = te.get("periodo_fim", "")

                # Classifica cada contrato por temporalidade
                durante, apos, antes, sem_data = [], [], [], []
                for c in contratos:
                    t = temporalidade_contrato(c["data"], periodo_inicio, periodo_fim)
                    if t == "DURANTE":
                        durante.append(c)
                    elif t == "APOS_SAIDA":
                        apos.append(c)
                    elif t == "ANTES_ENTRADA":
                        antes.append(c)
                    else:
                        sem_data.append(c)

                total_valor        = sum(parsear_valor(c["valor_final"]) for c in contratos)
                valor_durante      = sum(parsear_valor(c["valor_final"]) for c in durante)
                valor_apos         = sum(parsear_valor(c["valor_final"]) for c in apos)

                # Órgãos originais (nome exato no arquivo de contratos)
                orgaos_originais = " | ".join(sorted({
                    c.get("orgao_original", "") for c in contratos
                    if c.get("orgao_original")
                }))

                conflitos.append({
                    "_pid": pid,
                    "_eid": eid,
                    "_oid": oid,
                    "funcionario": nome_func,
                    "orgao_folha": oid,
                    "orgao_contrato_original": orgaos_originais,
                    "cargo": te.get("cargo", ""),
                    "lotacao": te.get("lotacao", ""),
                    "vinculo": te.get("vinculo", ""),
                    "periodo_inicio": periodo_inicio,
                    "periodo_fim": periodo_fim,
                    "cnpj_empresa": empresa["cnpj"],
                    "razao_social": razao,
                    "num_contratos": len(contratos),
                    "num_contratos_durante": len(durante),
                    "num_contratos_apos_saida": len(apos),
                    "valor_total_fmt": formatar_valor(total_valor),
                    "valor_durante_fmt": formatar_valor(valor_durante),
                    "valor_apos_saida_fmt": formatar_valor(valor_apos),
                    "valor_total": total_valor,
                    "datas_durante": " | ".join(sorted({c["data"] for c in durante if c["data"]})),
                    "datas_apos_saida": " | ".join(sorted({c["data"] for c in apos if c["data"]})),
                    "descricoes": " | ".join({c["descricao"][:80] for c in contratos if c["descricao"]}),
                    "_is_medica": is_medica(razao),
                    "_is_baixa": is_baixa_suspeicao(razao),
                    "_tem_nome": empresa_tem_nome_funcionario(nome_norm, razao),
                })

    # ── Classificação ─────────────────────────────────────────────────────────
    for c in conflitos:
        eid, oid = c["_eid"], c["_oid"]
        num_socios_mesmo_orgao = len(empresa_socios_por_orgao[eid][oid])

        if c["_tem_nome"]:
            c["categoria"] = "EMPRESA_PROPRIO_NOME"
            c["prioridade"] = 1
        elif num_socios_mesmo_orgao >= 10:
            c["categoria"] = "ESTRUTURA_SISTEMICA"
            c["prioridade"] = 2
            c["_num_socios_orgao"] = num_socios_mesmo_orgao
        elif not c["_is_medica"] and not c["_is_baixa"]:
            c["categoria"] = "SETOR_NAO_RELACIONADO"
            c["prioridade"] = 3
        elif c["_is_medica"]:
            c["categoria"] = "MEDICO_INSTITUTO"
            c["prioridade"] = 4
        else:
            c["categoria"] = "BAIXA_SUSPEICAO"
            c["prioridade"] = 5

    # Adiciona num_socios_orgao para todos
    for c in conflitos:
        eid, oid = c["_eid"], c["_oid"]
        c["num_socios_mesmo_orgao_na_empresa"] = len(empresa_socios_por_orgao[eid][oid])

    # Ordena: prioridade → valor desc
    conflitos.sort(key=lambda c: (c["prioridade"], -c["valor_total"]))

    # ── Salva ─────────────────────────────────────────────────────────────────
    COLUNAS = [
        "categoria", "prioridade",
        "funcionario", "orgao_folha", "orgao_contrato_original",
        "cargo", "lotacao", "vinculo",
        "periodo_inicio", "periodo_fim",
        "cnpj_empresa", "razao_social",
        "num_contratos", "num_contratos_durante", "num_contratos_apos_saida",
        "valor_total_fmt", "valor_durante_fmt", "valor_apos_saida_fmt",
        "num_socios_mesmo_orgao_na_empresa",
        "datas_durante", "datas_apos_saida", "descricoes",
    ]

    SAIDA.parent.mkdir(exist_ok=True)
    with open(SAIDA, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=COLUNAS, extrasaction="ignore")
        w.writeheader()
        w.writerows(conflitos)

    # ── Resumo ────────────────────────────────────────────────────────────────
    from collections import Counter
    cats = Counter(c["categoria"] for c in conflitos)

    print(f"\nArquivo gerado: {SAIDA}")
    print(f"Total de linhas: {len(conflitos):,}\n")
    print(f"{'Categoria':<30} {'Casos':>6}")
    print("─" * 38)
    for cat, n in sorted(cats.items(), key=lambda x: x[1], reverse=True):
        print(f"  {cat:<28} {n:>6,}")

    print(f"\n{'─'*60}")
    print("TOP 15 por valor — categorias prioritárias:")
    print(f"{'─'*60}")
    top = [c for c in conflitos if c["prioridade"] <= 3][:15]
    for c in top:
        print(f"\n  [{c['categoria']}]")
        print(f"  {c['funcionario']} ({c['orgao_folha']})")
        print(f"  {c['razao_social'][:60]}")
        print(f"  {c['num_contratos']} contratos | R$ {c['valor_total_fmt']}")
        if c["num_socios_mesmo_orgao_na_empresa"] > 1:
            print(f"  ⚠ {c['num_socios_mesmo_orgao_na_empresa']} servidores do mesmo órgão nessa empresa")


if __name__ == "__main__":
    main()
