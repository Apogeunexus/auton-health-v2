# Documentação · Auton Health v2

> Documentação viva do app clínico local em `auton-v2/`. Construída via
> auditoria ontológica em `2026-07-16`, contra `index.html` (13.147 linhas)
> e `data/auton.db` (~127 MB).

---

## Como ler

A doc segue o método ontológico: **entender antes de descrever**. Comece
sempre pela ontologia; ela dá o vocabulário estável para tudo o mais.

Ordem recomendada:

1. **[01 · Ontologia](01-ONTOLOGIA.md)** — o que existe no Auton Health,
   quais entidades, como se relacionam, quais estados, quais eventos,
   quais regras invioláveis.

2. **[02 · Telas](02-TELAS.md)** — percurso pelo app: cada tela, cada
   funcionalidade, cada campo, cada botão, cada transição.

3. **[03 · Dados](03-DADOS.md)** — o `auton.db` (schema completo,
   contagens, views, índices), os seeds inline no HTML, os JSONs
   externos, os CSVs opcionais, o `localStorage`.

4. **[04 · Arquitetura](04-ARQUITETURA.md)** — como o código faz tudo
   isso acontecer: launcher, sql.js, AutonDB, RENDERERS, roteamento,
   estado, motor de cálculo, "IA", design system, walkthrough do boot,
   dívidas técnicas.

5. **[05 · Correções](05-CORRECOES.md)** — plano de correção dos
   editores de Cadastros (Níveis 2 e 3) para respeitar a ontologia
   composicional. Nenhum código pronto — instruções para o dev
   implementar. Ver antes de mexer em Refeição-modelo, Treino-modelo,
   Template de Plano ou Template de Programa.

Também na raiz do projeto (não neste diretório):

- **[AUTON-DESIGN-SYSTEM.md](../../AUTON-DESIGN-SYSTEM.md)** — catálogo
  visual completo (tokens, componentes, animações, breakpoints, dark
  mode) — 1470 linhas.
- **[catalogo-clinico-repositorios.md](../../catalogo-clinico-repositorios.md)**
  — inventário de todas as bases de dados clínicas do mercado (BR
  regulatório, BR comercial, internacional, suplementos, fitoterápicos,
  homeopatia, interações, evidência).

---

## O que é o Auton Health

**Um SaaS clínico brasileiro** que roda **localmente** no computador do
profissional (médico, nutricionista, personal trainer).

Um único `index.html`. Um único `auton.db`. Zero login. Zero cloud. Zero
build step. Bastam Python + browser.

**Estrutura:**

```
auton-v2/
├── index.html              ← O app inteiro (13k linhas, 1.8 MB)
├── data/
│   ├── auton.db            ← Catálogo oficial (127 MB)
│   ├── exercicios_freedb.json   ← 873 exercícios (Unlicense)
│   └── seeds/
│       ├── treinos_modelo.json      ← 20 treinos curados
│       ├── templates_programa.json  ← 16 templates curados
│       └── importar.md              ← Instruções pro usuário
├── lib/
│   ├── sql-wasm.js         ← sql.js 1.14.1
│   └── sql-wasm.wasm       ← 658 KB
├── docs/                   ← Você está aqui
├── start.command           ← macOS launcher
├── start.bat               ← Windows launcher
└── README.txt              ← Instruções para o usuário final
```

---

## Métricas do app (2026-07-16)

- **`index.html`:** 13.147 linhas · 1.76 MB · 1 SPA monolítico.
- **`data/auton.db`:** ~127 MB, SQLite via sql.js WASM.
- **Renderers registrados:** 55.
- **Rotas de topo:** 2 (`pacientes`, `cadastros`).
- **Wizards:** 4 (Plano Alimentar, Programa de Treino, Prescrição,
  Solicitação de Exames).
- **Steps totais nos 4 wizards:** ~44 (17 no Plano, 13 no Treino, 6 na
  Prescrição, 6 nos Exames — alguns ocultos ou legados).
- **Cadastros:** 12 sub-telas em 4 top-tabs × 3 níveis (menos 1 — não há
  cadastro de Painéis de Exames como entidade separada).
- **Registros no catálogo oficial:**
  - Produtos (ANVISA): **53.717**
  - Exames (LOINC/TUSS/CBHPM): **98.554**
  - Alimentos (TACO): **597**
- **Exercícios (freedb):** **873** (via JSON externo).
- **Modelos de solicitação (seed):** **44**.
- **Templates de treino (seed):** **16**.
- **Templates de plano (seed):** **~5**.
- **Fórmulas manipuladas (seed):** **0** (zerado, "recomeçando").
- **Templates de prescrição (seed):** **0** (idem).

---

## Modelo ontológico em 30 segundos

O Auton Health se organiza em torno do **Paciente**. Cada paciente tem:
- uma **Ficha Clínica** (anamnese + antropometria + objetivo + estilo de vida),
- uma série de **Atendimentos** (eventos datados),
- uma série de **Instrumentos** (Planos, Programas, Prescrições,
  Solicitações emitidos).

Para produzir cada tipo de Instrumento, o profissional usa uma
biblioteca de conhecimento reutilizável organizada em **3 níveis** por
domínio clínico:

| Domínio      | Nível 1 · Átomo          | Nível 2 · Composto       | Nível 3 · Modelo/Template   |
|--------------|--------------------------|--------------------------|-----------------------------|
| Alimentação  | Alimento (TACO)          | Refeição-modelo          | Template de Plano Alimentar |
| Treino       | Exercício (freedb)       | Treino-modelo            | Template de Programa        |
| Prescrição   | Produto (ANVISA)         | Fórmula manipulada       | Template de Prescrição      |
| Exames       | Exame (LOINC/TUSS/CBHPM) | *(não modelado)*         | Modelo de Solicitação       |

**Regra-mãe do sistema:** cada nível carrega **só o que é dele**. Produto
tem identidade química, não posologia. Refeição-modelo tem composição,
não meta calórica. Instrumento tem resumo, não conteúdo integral.

Detalhes: [01-ONTOLOGIA.md](01-ONTOLOGIA.md).

---

## Glossário rápido

| Termo | Significado |
|---|---|
| **Instrumento** | O artefato clínico emitido (Plano, Programa, Prescrição, Solicitação). |
| **Wizard** | Sequência de telas que coleta dados até publicar um Instrumento. |
| **Substep** | Cada tela dentro de um wizard. |
| **Sub-state** | Sub-árvore de `state` dedicada a um wizard (`state.plano`, `state.treino`, `state.rx`, `state.ex`). |
| **Contexto** | `state.contextoInstrumento` — presente quando o wizard nasce de um Paciente. |
| **Catálogo Oficial** | Dados imutáveis pelo user, vindos do SQLite. |
| **Biblioteca Pessoal** | Dados que o profissional cria, persistidos em `localStorage`. |
| **Freedb** | Base pública free-exercise-db (Unlicense, 873 exercícios). |
| **TACO** | Tabela Brasileira de Composição de Alimentos, Unicamp 4ª ed. |
| **ANVISA** | Agência Nacional de Vigilância Sanitária. |
| **CMED** | Câmara de Regulação do Mercado de Medicamentos. |
| **LOINC** | Logical Observation Identifiers Names and Codes — padrão mundial de exames. |
| **TUSS** | Terminologia Unificada da Saúde Suplementar (ANS). |
| **CBHPM** | Classificação Brasileira Hierarquizada de Procedimentos Médicos (AMB). |
| **SIGTAP** | Sistema de Gerenciamento da Tabela de Procedimentos do SUS. |

Glossário completo em [01-ONTOLOGIA.md §8](01-ONTOLOGIA.md#8-glossário).

---

## Convenções desta doc

- **Números de linha** referenciam o `index.html` da versão auditada em
  `2026-07-16`. Podem defasar após edições — sempre confira antes de
  citar em código novo.
- **Rastreabilidade:** cada afirmação sobre comportamento é rastreável a
  uma função ou linha do código; nada foi inferido "por design pretendido".
- **Regras invioláveis** aparecem marcadas como tal — cuidado ao mexer.
- **Stubs conhecidos** estão listados em §13 de cada doc — evite depender
  deles em novos fluxos.
- **Backups `.bak_*`** na pasta `auton-v2/` são snapshots manuais.
  Não são versionamento — o repositório não é um git.

---

## Convenções do código

**Nomenclatura de funções por domínio:**
- `t_*` / `RENDERERS.t_*` → Treino
- `rx_*` / `RENDERERS.rx_*` → Prescrição
- `ex_*` / `RENDERERS.ex_*` → Exames
- Sem prefixo dedicado / `RENDERERS.<step>` → Plano Alimentar
- `_pac*` / `RENDERERS.paciente_*` → Paciente
- `RENDERERS.cadastro*` → Cadastros

**Ids de entidades:**
- Alimentos: `taco_<n>` (do TACO) ou `a_<n>` (custom).
- Exercícios: `freedb_<n>` (do freedb) ou `ex_<hash>` (custom).
- Exames: `ex<n>` (seed curado), `loinc_<code>`, `tuss_<code>` (importado).
- Produtos: `m<n>` (medicamento), `s<n>` (suplemento), `p_<hash>` (custom).
- Fórmulas: (a definir — seed está vazio).
- Refeições-modelo: `rm<n>` ou `rmn<n>`.
- Templates: `tpn<n>` (plano nutricional), `tm<n>` (treino), `me<n>` (modelo exames).
- Atendimentos: `atd_<timestamp>`.
- Instrumentos: `ins_<timestamp>`.
- Pacientes: `p<n>` (seed) ou `p_<timestamp>`.

**Sub-states:**
- `state.plano` — plano alimentar em edição.
- `state.treino` — programa de treino em edição.
- `state.rx` — prescrição em edição.
- `state.ex` — solicitação de exames em edição.

Cada wizard usa o seu próprio sub-state e é reinicializado por
`_resetWizardState(tipo)` (linha 9010) antes de começar.

---

## Contato / evolução

Esta é a primeira versão consolidada. Correções, adições e discussões
sobre o modelo pertencem ao próximo iteração da doc — o app está em
evolução ativa (7 backups `.bak_*` só em julho de 2026).

Para propor alteração, edite os `.md` correspondentes; a doc é a
verdade e o `index.html` deve segui-la (quando não segue, é dívida
técnica — está listada em §13 de cada doc).
