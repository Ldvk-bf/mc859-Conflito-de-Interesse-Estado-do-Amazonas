import os

caminho_base = "data/folha_pagamento_am"

for pasta_raiz, subpastas, arquivos in os.walk(caminho_base):
    if not arquivos:
        os.rmdir(pasta_raiz)
    for arquivo in arquivos:
        if arquivo.endswith(".pdf"):
            caminho_completo = os.path.join(pasta_raiz, arquivo)
            os.remove(caminho_completo)
            print(f"Apagado: {caminho_completo}")

print("Concluído.")