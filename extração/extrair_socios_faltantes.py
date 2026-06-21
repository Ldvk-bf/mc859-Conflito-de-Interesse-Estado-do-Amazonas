# """
# Extrai sócios dos CNPJs que estão faltando no dataset principal.
# Salva em data/dados_base/socios_faltantes.csv — NÃO altera o arquivo principal.
# """

# import csv
# import time
# from pathlib import Path

# import requests
# from tqdm import tqdm

# CNPJS = [
#     "34170671000112",
#     "20166637000160",
#     "19945996000136",
#     "63279692000179",
#     "04666972000135",
#     "07516151000146",
#     "00766728000129",
#     "23611514000189",
#     "13293239000149",
#     "63823673000161",
#     "63825568000161",
#     "13536655000201",
#     "08958628000297",
#     "04461236000144",
#     "09354828000112",
#     "60801182000121",
#     "06295901000122",
#     "10325075000010",
#     "14178339001907",
#     "02345517000104",
#     "10683199000145",
#     "04628208000167",
#     "46706474000154",
#     "33399731000100",
#     "07875818000105",
#     "19533891000170",
#     "63245045000146",
#     "57693774000162",
# ]

# SAIDA = Path("data/dados_base/socios_faltantes.csv")
# COLUNAS = ["cnpj_empresa", "razao_social", "nome_socio", "cpf_cnpj_socio", "qualificacao"]


# def buscar_cnpj(cnpj: str) -> list[dict]:
#     url = f"https://brasilapi.com.br/api/cnpj/v1/{cnpj}"
#     try:
#         r = requests.get(url, timeout=15)
#         if r.status_code == 200:
#             dados = r.json()
#             qsa = dados.get("qsa", [])
#             razao = dados.get("razao_social", "")
#             if not qsa:
#                 return [{"cnpj_empresa": cnpj, "razao_social": razao,
#                          "nome_socio": "NAO INFORMADO", "cpf_cnpj_socio": "", "qualificacao": ""}]
#             return [
#                 {"cnpj_empresa": cnpj, "razao_social": razao,
#                  "nome_socio": s.get("nome_socio", ""),
#                  "cpf_cnpj_socio": s.get("cnpj_cpf_do_socio", ""),
#                  "qualificacao": s.get("qualificacao_socio", "")}
#                 for s in qsa
#             ]
#         else:
#             print(f"  ✗ {cnpj} — HTTP {r.status_code}")
#             return []
#     except requests.exceptions.RequestException as e:
#         print(f"  ✗ {cnpj} — {e}")
#         return []


# def main():
#     # Carrega CNPJs já encontrados para não repetir
#     ja_encontrados = set()
#     if SAIDA.exists():
#         with open(SAIDA, encoding="utf-8") as f:
#             for r in csv.DictReader(f, delimiter=";"):
#                 ja_encontrados.add(r["cnpj_empresa"])

#     pendentes = [c for c in CNPJS if c not in ja_encontrados]
#     print(f"Já encontrados: {len(ja_encontrados)} | Pendentes: {len(pendentes)}\n")

#     resultados = []
#     for cnpj in tqdm(pendentes):
#         rows = buscar_cnpj(cnpj)
#         resultados.extend(rows)
#         time.sleep(2)  # pausa maior para evitar rate limit

#     SAIDA.parent.mkdir(parents=True, exist_ok=True)
#     # Append nos já existentes
#     modo = "a" if ja_encontrados else "w"
#     with open(SAIDA, modo, newline="", encoding="utf-8") as f:
#         w = csv.DictWriter(f, fieldnames=COLUNAS, delimiter=";")
#         if modo == "w":
#             w.writeheader()
#         w.writerows(resultados)

#     print(f"\n✓ {len(resultados)} registros salvos em {SAIDA}")
#     print("\nEmpresas encontradas:")
#     vistas = set()
#     for r in resultados:
#         if r["cnpj_empresa"] not in vistas:
#             vistas.add(r["cnpj_empresa"])
#             print(f"  {r['cnpj_empresa']} — {r['razao_social']}")


# if __name__ == "__main__":
#     main()
