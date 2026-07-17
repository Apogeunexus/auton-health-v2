# Auton Health v2

App clínico local para profissionais de saúde brasileiros (médico, nutricionista, personal trainer). Roda em um único `index.html` sobre SQLite (via sql.js).

**Escopo dos 4 fluxos clínicos:**

- Plano Alimentar
- Programa de Treino
- Prescrição
- Solicitação de Exames

Um único paciente é a âncora — ele acumula uma Ficha Clínica, Atendimentos e Instrumentos emitidos.

---

## Como rodar localmente

Pré-requisito: **Python 3** e **Git LFS** (para o `auton.db` de 121 MB).

```bash
# Clonar (com LFS)
git lfs install
git clone https://github.com/Apogeunexus/auton-health-v2.git
cd auton-health-v2

# macOS
./start.command

# Windows
start.bat
```

O launcher sobe `python -m http.server 8787` e abre o navegador em `http://localhost:8787/index.html`.

Se o `auton.db` clonou como pointer LFS (arquivo ~130 bytes em vez de ~121 MB), rode:

```bash
git lfs pull
```

---

## Estrutura

```
auton-health-v2/
├── index.html              ← O app inteiro (13k linhas, ~1.8 MB)
├── data/
│   ├── auton.db            ← Catálogo oficial (121 MB · LFS)
│   ├── exercicios_freedb.json   ← 873 exercícios (Unlicense)
│   └── seeds/
│       ├── treinos_modelo.json      ← 20 treinos curados
│       ├── templates_programa.json  ← 16 templates curados
│       └── importar.md              ← Instruções pro usuário
├── lib/
│   ├── sql-wasm.js         ← sql.js 1.14.1
│   └── sql-wasm.wasm       ← 658 KB
├── docs/                   ← Documentação completa
│   ├── 00-README.md
│   ├── 01-ONTOLOGIA.md
│   ├── 02-TELAS.md
│   ├── 03-DADOS.md
│   └── 04-ARQUITETURA.md
├── start.command           ← macOS launcher
├── start.bat               ← Windows launcher
└── vercel.json             ← Config Vercel (deploy estático)
```

---

## Números do app

- **`index.html`:** 13.147 linhas · 1.76 MB · SPA monolítico.
- **`data/auton.db`:** 121 MB, SQLite via sql.js WASM.
- **Registros no catálogo oficial:**
  - Produtos (ANVISA): 53.717
  - Exames (LOINC/TUSS/CBHPM): 98.554
  - Alimentos (TACO): 597
- **Exercícios (freedb):** 873 via JSON externo.

---

## Documentação

Toda a doc está em [`docs/`](./docs/):

- [**00 · README**](./docs/00-README.md) — índice geral, glossário, convenções.
- [**01 · Ontologia**](./docs/01-ONTOLOGIA.md) — domínio, entidades, relações, estados, eventos, regras invioláveis.
- [**02 · Telas**](./docs/02-TELAS.md) — tela por tela, funcionalidade por funcionalidade.
- [**03 · Dados**](./docs/03-DADOS.md) — schema completo do SQLite, seeds, fontes, `localStorage`.
- [**04 · Arquitetura**](./docs/04-ARQUITETURA.md) — camadas técnicas, roteamento, motor de cálculo, design system.

---

## Fontes de dados (todas oficiais / abertas)

- **ANVISA Dados Abertos** — medicamentos, alimentos (suplementos), cannabis.
- **CMED** — composição e tarja.
- **TACO** (Unicamp, 4ª ed.) — composição de alimentos brasileiros.
- **LOINC** — códigos universais de exames.
- **TUSS (ANS)** — procedimentos de saúde suplementar.
- **CBHPM (AMB)** — classificação hierarquizada de procedimentos.
- **SIGTAP (DATASUS)** — procedimentos SUS.
- **free-exercise-db** — 873 exercícios (Unlicense).

Detalhes em [`docs/03-DADOS.md`](./docs/03-DADOS.md).

---

## Stack

- HTML + CSS + JS puros (sem framework, sem build step).
- SQLite via **sql.js 1.14.1** (WASM).
- Servidor local: Python `http.server` na porta 8787.
- Persistência do consultório: `localStorage` do navegador.

---

## Estado atual

Este é o **snapshot da versão local** (`v2`), pronto para a equipe de dev portar para a versão web. Alguns componentes já estão implementados e outros estão marcados como stub — o inventário completo de dívida técnica está em [`docs/04-ARQUITETURA.md#13-dívidas-técnicas-identificadas`](./docs/04-ARQUITETURA.md#13-dívidas-técnicas-identificadas).
