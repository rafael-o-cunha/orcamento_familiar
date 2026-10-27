#!/usr/bin/env python3
"""Cria no GitHub as labels, os milestones e as issues descritos em docs/04-tarefas.md.

Pode ser executado quantas vezes quiser: o que já existe não é duplicado.
- Labels: criadas ou atualizadas a partir de .github/labels.json.
- Milestones: um por pacote ("P0 — Fundação", ...).
- Issues: uma por tarefa ("[P0] T0.1 ..."); a issue guarda o id da tarefa num
  comentário HTML invisível, usado para não criar a mesma tarefa duas vezes.
- Depois de criar, troca "T0.1" no campo "Depende de" pelo link da issue (#n).

Uso:
  GITHUB_TOKEN=... python3 .github/scripts/gerar_issues.py --repo dono/repositorio [--dry-run]
Sem dependências externas (só biblioteca padrão do Python 3).
"""
import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://api.github.com"
RAIZ = Path(__file__).resolve().parents[2]

RE_PACOTE = re.compile(r"^## Pacote (\d+) — (.+)$")
RE_TAREFA = re.compile(r"^### \[(P\d+)\] (T\d+\.\d+) (.+)$")
RE_LINHA = re.compile(r"^\|\s*(.+?)\s*\|\s*(.*?)\s*\|$")
RE_ID_TAREFA = re.compile(r"\bT\d+\.\d+\b")


# ----------------------------------------------------------------- leitura do .md
def ler_tarefas(caminho):
    pacotes, tarefas = {}, []
    pacote_atual = None
    tarefa = None
    for linha in Path(caminho).read_text(encoding="utf-8").splitlines():
        m = RE_PACOTE.match(linha)
        if m:
            pacote_atual = f"P{m.group(1)}"
            pacotes[pacote_atual] = {"titulo": f"{pacote_atual} — {m.group(2)}", "descricao": ""}
            tarefa = None
            continue
        if pacote_atual and linha.startswith("Entrega:") and not pacotes[pacote_atual]["descricao"]:
            pacotes[pacote_atual]["descricao"] = linha
            continue
        m = RE_TAREFA.match(linha)
        if m:
            tarefa = {"pacote": m.group(1), "id": m.group(2), "nome": m.group(3), "campos": {}}
            tarefas.append(tarefa)
            continue
        if linha.startswith("## "):
            tarefa = None
            continue
        m = RE_LINHA.match(linha)
        if tarefa and m and m.group(1) not in ("Campo", "---"):
            tarefa["campos"][m.group(1)] = m.group(2)
    return pacotes, tarefas


def labels_da_tarefa(tarefa):
    return re.findall(r"`([^`]+)`", tarefa["campos"].get("Labels", ""))


def titulo_issue(tarefa):
    return f"[{tarefa['pacote']}] {tarefa['id']} {tarefa['nome']}"


def corpo_issue(tarefa, pacotes, numeros=None):
    c = tarefa["campos"]
    depende = c.get("Depende de", "—")
    if numeros:
        depende = RE_ID_TAREFA.sub(lambda m: f"#{numeros[m.group(0)]} ({m.group(0)})" if m.group(0) in numeros else m.group(0), depende)
    itens_aceite = [i.strip() for i in c.get("Aceite", "").split(";") if i.strip()]
    aceite = "\n".join(f"- [ ] {i}" for i in itens_aceite) or "—"
    return (
        f"<!-- tarefa:{tarefa['id']} -->\n"
        f"**Pacote:** {pacotes[tarefa['pacote']]['titulo']}  \n"
        f"**APF:** {c.get('APF', '—')}\n\n"
        f"### Descrição\n{c.get('Descrição', '—')}\n\n"
        f"### Entregável\n{c.get('Entregável', '—')}\n\n"
        f"### Aceite\n{aceite}\n\n"
        f"### Depende de\n{depende}\n\n"
        f"---\n_Gerada a partir de `docs/04-tarefas.md`. Para mudar a tarefa, edite a issue; "
        f"o documento é a referência inicial._\n"
    )


# ----------------------------------------------------------------- API do GitHub
class GitHub:
    def __init__(self, repo, token, dry_run):
        self.repo, self.token, self.dry_run = repo, token, dry_run

    def chamar(self, metodo, caminho, dados=None):
        url = f"{API}/repos/{self.repo}{caminho}"
        corpo = json.dumps(dados).encode() if dados is not None else None
        req = urllib.request.Request(url, data=corpo, method=metodo)
        req.add_header("Accept", "application/vnd.github+json")
        req.add_header("X-GitHub-Api-Version", "2022-11-28")
        if self.token:
            req.add_header("Authorization", f"Bearer {self.token}")
        try:
            with urllib.request.urlopen(req) as resp:
                texto = resp.read().decode()
                return json.loads(texto) if texto else None
        except urllib.error.HTTPError as e:
            sys.exit(f"Erro {e.code} em {metodo} {caminho}: {e.read().decode()[:500]}")

    def listar(self, caminho):
        itens, pagina = [], 1
        while True:
            sep = "&" if "?" in caminho else "?"
            lote = self.chamar("GET", f"{caminho}{sep}per_page=100&page={pagina}")
            itens += lote
            if len(lote) < 100:
                return itens
            pagina += 1

    def escrever(self, metodo, caminho, dados, descricao):
        print(("[simulação] " if self.dry_run else "") + descricao)
        if self.dry_run:
            return None
        resposta = self.chamar(metodo, caminho, dados)
        time.sleep(0.8)  # evita o limite secundário de criação da API
        return resposta


# ----------------------------------------------------------------- etapas
def sincronizar_labels(gh, labels):
    existentes = {l["name"]: l for l in gh.listar("/labels")} if gh.token else {}
    for label in labels:
        atual = existentes.get(label["name"])
        if atual is None:
            gh.escrever("POST", "/labels", label, f"label criada: {label['name']}")
        elif atual["color"].lower() != label["color"].lower() or (atual.get("description") or "") != label["description"]:
            nome = urllib.parse.quote(label["name"])
            gh.escrever("PATCH", f"/labels/{nome}", {"color": label["color"], "description": label["description"]}, f"label atualizada: {label['name']}")


def sincronizar_milestones(gh, pacotes):
    existentes = {m["title"]: m["number"] for m in gh.listar("/milestones?state=all")} if gh.token else {}
    numeros = {}
    for chave, pacote in pacotes.items():
        if pacote["titulo"] in existentes:
            numeros[chave] = existentes[pacote["titulo"]]
            continue
        criado = gh.escrever("POST", "/milestones", {"title": pacote["titulo"], "description": pacote["descricao"]}, f"milestone criado: {pacote['titulo']}")
        numeros[chave] = criado["number"] if criado else None
    return numeros


def criar_issues(gh, pacotes, tarefas, milestones):
    existentes = {}
    if gh.token:
        for issue in gh.listar("/issues?state=all"):
            m = re.search(r"<!-- tarefa:(T\d+\.\d+) -->", issue.get("body") or "")
            if m and "pull_request" not in issue:
                existentes[m.group(1)] = issue["number"]
    numeros = dict(existentes)
    novas = []
    for tarefa in tarefas:
        if tarefa["id"] in existentes:
            print(f"já existe: {titulo_issue(tarefa)} (#{existentes[tarefa['id']]})")
            continue
        dados = {"title": titulo_issue(tarefa), "body": corpo_issue(tarefa, pacotes), "labels": labels_da_tarefa(tarefa)}
        if milestones.get(tarefa["pacote"]):
            dados["milestone"] = milestones[tarefa["pacote"]]
        criada = gh.escrever("POST", "/issues", dados, f"issue criada: {dados['title']}  labels={dados['labels']}")
        if criada:
            numeros[tarefa["id"]] = criada["number"]
            novas.append(tarefa)
    # Segunda passada: liga "Depende de" às issues reais.
    for tarefa in novas:
        if RE_ID_TAREFA.search(tarefa["campos"].get("Depende de", "")):
            gh.escrever("PATCH", f"/issues/{numeros[tarefa['id']]}", {"body": corpo_issue(tarefa, pacotes, numeros)}, f"dependências ligadas: {tarefa['id']}")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY"), help="dono/repositorio")
    p.add_argument("--arquivo", default=str(RAIZ / "docs" / "04-tarefas.md"))
    p.add_argument("--labels", default=str(RAIZ / ".github" / "labels.json"))
    p.add_argument("--dry-run", action="store_true", help="só mostra o que seria criado")
    p.add_argument("--somente-labels", action="store_true", help="sincroniza só as labels")
    args = p.parse_args()

    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if not args.dry_run and (not args.repo or not token):
        sys.exit("Informe --repo dono/repositorio e a variável GITHUB_TOKEN (ou rode com --dry-run).")

    gh = GitHub(args.repo, token if not args.dry_run else None, args.dry_run)
    labels = json.loads(Path(args.labels).read_text(encoding="utf-8"))
    sincronizar_labels(gh, labels)
    if args.somente_labels:
        return

    pacotes, tarefas = ler_tarefas(args.arquivo)
    desconhecidas = {l for t in tarefas for l in labels_da_tarefa(t)} - {l["name"] for l in labels}
    if desconhecidas:
        sys.exit(f"Labels usadas nas tarefas e ausentes em labels.json: {sorted(desconhecidas)}")
    print(f"{len(pacotes)} pacotes e {len(tarefas)} tarefas lidos de {args.arquivo}")
    milestones = sincronizar_milestones(gh, pacotes)
    criar_issues(gh, pacotes, tarefas, milestones)


if __name__ == "__main__":
    main()
