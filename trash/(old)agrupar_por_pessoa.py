"""
Agrupa matches_com_contratos.csv por pessoa (nome_normalizado).

Gera dois arquivos:
  data/resumo_por_pessoa_todos.csv   — todos os matches (exatos + fuzzy)
  data/resumo_por_pessoa_exatos.csv  — somente matches onde metodo == "exato"
                                       (nome idêntico após normalização)

Campos multi-valor usam " | " como separador.
"""

import csv
import re
import unicodedata
from collections import defaultdict
from pathlib import Path

ENTRADA       = Path("data/dados_derivados/matches_com_contratos.csv")
SAIDA_TODOS   = Path("data/nome_pessoa_score-empresa(s)-orgao.csv")
SAIDA_EXATOS  = Path("data/nome_pessoa_exato-empresa(s)-orgao.csv")

COLUNAS_SAIDA = [
    "nome_funcionario",
    "nome_socio",
    "orgao",
    "lotacao_funcionario",
    "cargo",
    "vinculo",
    "periodo_inicio",
    "periodo_fim",
    "cnpj_empresa",
    "razao_social",
    "qualificacao",
    "scores",
    "orgaos_contrato",
    "num_contratos_comprometidos",
    "num_contratos_comprometidos_orgao_em_que_trabalha",
    "datas_contrato",
    "data_valores_contratos",
    "valor_final_comprometido",
]

SEP = " | "


def normalizar(s: str) -> str:
    s = s.strip().upper()
    s = unicodedata.normalize("NFD", s)
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    return re.sub(r"\s+", " ", re.sub(r"[^A-Z\s]", "", s)).strip()


def parsear_valor_br(v: str) -> float:
    if not v or not v.strip():
        return 0.0
    try:
        return float(v.strip().replace(".", "").replace(",", "."))
    except ValueError:
        return 0.0


def formatar_valor_br(v: float) -> str:
    return f"{v:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


def lista_unica(valores: list[str]) -> str:
    vistos, resultado = set(), []
    for v in valores:
        v = v.strip()
        if v and v not in vistos:
            vistos.add(v)
            resultado.append(v)
    return SEP.join(resultado)


def agregar(grupos: dict[str, list[dict]]) -> list[dict]:
    resultados = []

    for _nome_norm, linhas in grupos.items():
        ref = linhas[0]

        conflitos = [r for r in linhas if r.get("conflito_direto") == "SIM"]
        todos     = linhas

        resultados.append({
            "nome_funcionario":    ref.get("nome_funcionario", "").strip(),
            "nome_socio":          lista_unica([r.get("nome_socio", "") for r in linhas]),
            "orgao":               ref.get("orgao", "").strip(),
            "lotacao_funcionario": ref.get("lotacao_funcionario", "").strip(),
            "cargo":               ref.get("cargo", "").strip(),
            "vinculo":             ref.get("vinculo", "").strip(),
            "periodo_inicio":      ref.get("periodo_inicio", "").strip(),
            "periodo_fim":         ref.get("periodo_fim", "").strip(),
            "cnpj_empresa":        lista_unica([r.get("cnpj_empresa", "")  for r in linhas]),
            "razao_social":        lista_unica([r.get("razao_social", "")  for r in linhas]),
            "qualificacao":        lista_unica([r.get("qualificacao", "")  for r in linhas]),
            "scores":              lista_unica([r.get("score", "")         for r in linhas]),
            "orgaos_contrato":     lista_unica(
                [r.get("orgao_contrato", "") for r in todos if r.get("orgao_contrato")]
            ),
            "num_contratos_comprometidos": len(
                [r for r in todos if r.get("orgao_contrato")]
            ),
            "num_contratos_comprometidos_orgao_em_que_trabalha": len(conflitos),
            "datas_contrato": lista_unica(
                [r.get("data_contrato", "") for r in conflitos]
            ),
            "data_valores_contratos": lista_unica([
                f"{r.get('data_contrato', '')}|R${r.get('valor_final', '0,00')}"
                for r in conflitos
            ]),
            "valor_final_comprometido": formatar_valor_br(
                sum(parsear_valor_br(r.get("valor_final", "")) for r in conflitos)
            ),
        })

    resultados.sort(key=lambda r: (
        -r["num_contratos_comprometidos_orgao_em_que_trabalha"],
        -parsear_valor_br(r["valor_final_comprometido"]),
    ))

    return resultados


def salvar(resultados: list[dict], caminho: Path) -> None:
    caminho.parent.mkdir(exist_ok=True)
    with open(caminho, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=COLUNAS_SAIDA)
        writer.writeheader()
        writer.writerows(resultados)


def imprimir_resumo(label: str, resultados: list[dict]) -> None:
    com_conflito = [
        r for r in resultados
        if r["num_contratos_comprometidos_orgao_em_que_trabalha"] > 0
    ]
    total_valor = sum(
        parsear_valor_br(r["valor_final_comprometido"]) for r in com_conflito
    )
    print(f"\n  [{label}]")
    print(f"    Pessoas únicas:                {len(resultados):,}")
    print(f"    Com conflito direto:           {len(com_conflito):,}")
    print(f"    Valor total comprometido:      R$ {formatar_valor_br(total_valor)}")

    print(f"\n  {'─'*85}")
    print(f"  PREVIEW — top 8 por nº de contratos em conflito")
    print(f"  {'─'*85}")
    for r in resultados[:8]:
        print(
            f"\n    {r['nome_funcionario']}\n"
            f"    Órgão    : {r['orgao']} | {r['lotacao_funcionario']} | {r['cargo']}\n"
            f"    Período  : {r['periodo_inicio']} → {r['periodo_fim']}\n"
            f"    Empresas : {r['razao_social'][:75]}\n"
            f"    Conflitos: {r['num_contratos_comprometidos_orgao_em_que_trabalha']} "
            f"contratos | R$ {r['valor_final_comprometido']}\n"
            f"    Detalhe  : {r['data_valores_contratos'][:90]}"
        )


def main():
    print(f"Carregando {ENTRADA}...")
    with open(ENTRADA, encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))
    print(f"  {len(rows):,} linhas")

    # ── Versão TODOS ──────────────────────────────────────────────────────────
    grupos_todos: dict[str, list[dict]] = defaultdict(list)
    for r in rows:
        chave = normalizar(r.get("nome_funcionario", ""))
        if chave:
            grupos_todos[chave].append(r)

    # ── Versão EXATOS — filtra apenas linhas onde metodo == "exato" ───────────
    # Mantém somente pessoas cujo match de nome foi exato.
    # As linhas de contrato (orgao_contrato, valor, etc.) vêm só dessas pessoas.
    # "exato"      = nome idêntico após normalização         → máxima confiança
    # "token_igual" = mesmos tokens, ordem diferente (score 95) → alta confiança
    grupos_exatos: dict[str, list[dict]] = defaultdict(list)
    for r in rows:
        if r.get("metodo", "").strip() in ("exato", "token_igual"):
            chave = normalizar(r.get("nome_funcionario", ""))
            if chave:
                grupos_exatos[chave].append(r)

    print(f"\n  Grupos (todos):   {len(grupos_todos):,} pessoas")
    print(f"  Grupos (exatos):  {len(grupos_exatos):,} pessoas")

    print("\nAgregando...")
    todos_agg  = agregar(grupos_todos)
    exatos_agg = agregar(grupos_exatos)

    salvar(todos_agg,  SAIDA_TODOS)
    salvar(exatos_agg, SAIDA_EXATOS)

    print(f"\nArquivos gerados:")
    print(f"  {SAIDA_TODOS}")
    print(f"  {SAIDA_EXATOS}")

    print(f"\n{'='*90}")
    imprimir_resumo("TODOS  — exatos + fuzzy", todos_agg)
    print(f"\n{'='*90}")
    imprimir_resumo("EXATOS — apenas nome idêntico", exatos_agg)
if __name__ == "__main__":
    main()
