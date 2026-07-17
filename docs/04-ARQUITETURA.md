# 04 · Arquitetura Técnica

> Como as camadas do app se encaixam. Depois de ler a ontologia (§01),
> os fluxos (§02) e os dados (§03), este documento explica **como o
> código faz tudo isso acontecer** — do launcher ao render final.

---

## 1. Stack

- **Frontend** — 1 arquivo HTML monolítico (`index.html`, 13.147 linhas,
  1.76 MB). CSS inline no `<head>`. JavaScript inline em vários blocos
  `<script>`. Sem framework, sem build step.
- **Runtime** — navegador desktop moderno (Chrome/Safari/Firefox recentes).
- **Banco** — SQLite via **sql.js 1.14.1** (WASM). `data/auton.db`
  (~127 MB) carregado em memória no boot.
- **Persistência do consultório** — `localStorage` do navegador.
- **Servidor** — Python `http.server` na porta 8787. Só serve estático.
- **Fontes** — Google Fonts (Inter + JetBrains Mono) via CDN.
- **Imagens de exercício** — GitHub raw CDN.

**O app funciona 100% offline após o boot** — só o load inicial de fonts
e imagens precisa de rede.

---

## 2. Launchers

### 2.1. `start.command` (macOS)

```bash
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR" || exit 1

PORT=8787
URL="http://localhost:$PORT/index.html"

# Abre browser após 1s
(sleep 1 && open "$URL") &

# Sobe servidor
if command -v python3 >/dev/null 2>&1; then
  exec python3 -m http.server "$PORT"
elif command -v python >/dev/null 2>&1; then
  exec python -m http.server "$PORT"
else
  echo "ERRO: python não encontrado"; read -r; exit 1
fi
```

Duplo-clique no Finder → sobe servidor + abre browser.

### 2.2. `start.bat` (Windows)

```bat
@echo off
cd /d "%~dp0"

set PORT=8787
set URL=http://localhost:%PORT%/index.html

start "" "%URL%"

where python >nul 2>&1 && (python -m http.server %PORT%) || (
  where py >nul 2>&1 && (py -3 -m http.server %PORT%) || (
    echo ERRO: Python 3 nao encontrado
    pause
  )
)
```

Duplo-clique → abre browser + sobe servidor.

**Não funciona em `file://`** porque o `fetch('data/auton.db')` seria
bloqueado por CORS. Servidor HTTP é obrigatório.

**Porta 8787** — escolhida deliberadamente para não colidir com outros
apps do repositório na 8788.

---

## 3. sql.js

- **Biblioteca:** `lib/sql-wasm.js` (46 KB) + `lib/sql-wasm.wasm` (658 KB).
- **Versão:** **1.14.1** — declarada em `<script src="lib/sql-wasm.js?v=1.14.1">`
  (index.html linha 1915) e no README.txt linha 29.
- **Carregamento:**
  ```js
  <script src="lib/sql-wasm.js?v=1.14.1"></script>
  ```
  Cria `window.initSqlJs`.
- **wasm path** (linha 1948-1950):
  ```js
  initSqlJs({ locateFile: (f) => 'lib/' + f })
  ```
  Resolve para `lib/sql-wasm.wasm` relativo ao index.
- **Boot do DB** (1951-1954):
  ```js
  const SQL = await initSqlJs({ locateFile });
  const resp = await fetch('data/auton.db');
  const buf = new Uint8Array(await resp.arrayBuffer());
  db = new SQL.Database(buf);
  ```
- **FTS5 ausente** — a build oficial não vem com FTS5 compilado. Ver
  `03-DADOS.md` §7.

---

## 4. `window.AutonDB` — Fachada de leitura

**Definição:** linhas 1942–2100 (IIFE atribuída a `window.AutonDB`).
**Boot:** linhas 2103–2131.

### 4.1. Estrutura interna (privada)

```
{
  db,                    // instância SQL.Database (após init)
  readyPromise,          // memoiza init()
  init(),                // carrega o .db e prepara
  rows(res),             // helper: colunar → array de objetos
  escapeFTS(q),          // definido mas NUNCA usado
}
```

### 4.2. API pública

| Método | Assinatura | Retorno | Notas |
|---|---|---|---|
| `ready()` | `() => Promise<Database>` | promessa | idempotente via `readyPromise` |
| `isReady()` | `() => boolean` | | guard antes de cada consulta |
| `stats()` | `() => {produtos, exames}` | contagens agregadas | |
| `buscarProdutos(q, {categoria=null, limit=50})` | multi-termo LIKE | `Row[]` | AND entre palavras; OR entre 3 colunas (nome/principio_ativo/fabricante); `ORDER BY LENGTH(nome), nome` |
| `buscarExames(q, {categoria=null, limit=50})` | LIKE em 5 colunas | `Row[]` | nome, sigla, nome_tecnico, codigo_loinc, codigo_tuss |
| `getProduto(id)` | `SELECT * FROM produtos WHERE id=?` | `Row \| null` | |
| `getExame(id)` | idem para exames | `Row \| null` | |
| `categoriasProduto()` | `GROUP BY categoria ORDER BY n DESC` | `[{categoria, n}]` | facet |
| `categoriasExame()` | idem | `[{categoria, n}]` | |
| `buscarAlimentos(q, {grupo=null, limit=500})` | LIKE em `nome` + `grupo` | `Row[]` | |
| `countAlimentos(grupo?)` | count opcional filtrado | `number` | |
| `gruposAlimentos()` | facet | `[{grupo, n}]` | |
| `getAlimento(id)` | por PK | `Row \| null` | |

### 4.3. Hook de boot

Ao resolver a promise (linhas 2103–2131):
1. Atualiza contadores em `[data-autondb-count]`.
2. Dispara `CustomEvent('autondb:ready', {detail: stats})`.
3. Re-renderiza `RENDERERS.cadastros()` até 10× com backoff de 300 ms
   se ainda não existia.
4. Em erro dispara `CustomEvent('autondb:error', {detail: err.message})`.

### 4.4. Camada de cache

Definida em 6400–6499. Não vive dentro do AutonDB — é wrapper em cima.

- `allAlimentos()`, `allProdutos()`, `allExames()` — cache com TTL **5000 ms**,
  hard-limit **500** linhas (`__HARD_LIMIT_LISTA = 500`, linha 6431).
- `countProdutosCategoria(cat)`, `countExamesCategoria(cat)` — cache de
  contagens por categoria (`window.__countCacheP`, `__countCacheE`).
- Fallback: quando `AutonDB` não está pronto, retorna o seed em
  `state.cadastros.<tipo>`.
- Evento `autondb:ready` invalida caches e re-renderiza `RENDERERS.cadastros`
  se estiver na tela.

**Motivo do hard-limit 500:** renderizar 53k rows travaria o DOM.
Cadastros mostram no máximo 500 por render — filtros e busca cobrem o resto.

---

## 5. `window.RENDERERS` — Dispatcher de views

**Definição:** linha 4267 — `const RENDERERS = {};`

Cada view registra-se com:
```js
RENDERERS.<stepId> = function() {
  document.getElementById('screen-<stepId>').innerHTML = '...';
};
```

Não é classe, não é reativo. Cada renderer **regrava o `innerHTML` do
próprio `<section id="screen-...">`**. Simples e direto.

### 5.1. Inventário

55 renderers no total. Ver `02-TELAS.md` para o inventário completo.
Resumido:

- **Plano Alimentar (wizard):** 14 renderers (9 ativos + 5 legados).
- **Programa de Treino (wizard):** 13 renderers (7 visíveis + 6 ocultos).
- **Prescrição (wizard):** 6 renderers.
- **Solicitação de Exames (wizard):** 6 renderers.
- **Paciente:** 2 renderers (`pacientes`, `paciente_detalhe`) + 5 sub-renderers de aba.
- **Cadastros:** 1 renderer chassi + 11 sub-renderers (12 - o de painéis não existe).

### 5.2. Padrão de acionamento

`goTo(stepId)` (6749) → resolve migração → mostra tela certa → chama
`RENDERERS[stepId]()`.

**Exceções especiais:**
- Se `stepId ∈ PLANO_SUBSTEPS` (6729) ou `TREINO_SUBSTEPS` (6733), o
  contêiner único (`screen-plano_completo` / `screen-treino_completo`)
  é ativado, **todos** os sub-renderers rodam de uma vez, e faz
  scroll-suave até a âncora. O usuário navega pelo scroll ou pelos
  botões da sidebar horizontal.
- `_reRenderAllSubsteps()` (4708) — re-renderiza toda a stack quando um
  template é aplicado (mudou várias etapas de uma vez).

### 5.3. Pseudo-componentes reutilizáveis

Não são componentes React — são funções que emitem HTML:

| Função | Linha | Uso |
|---|---|---|
| `openModal(title, body, footer)` | 8708 | Inserção em `#modalRoot` |
| `closeModal()` | 8712 | Limpa e some |
| `toast(msg, ms=2500)` | 7125 | Notificação temporária no `#toast` |
| `navFooter({next, canNext, onNext, ...})` | 7156 | Rodapé "Continuar →" dos wizards |
| `renderPainelCatalogoOficial(tipo)` | 2138 | Busca ANVISA/LOINC no SQLite |
| `renderPhaseStepper()` | 6991 | Barra de fases no topo do wizard |
| `updateHeaderBar()` | 7100 | Título + rota ativa na sidebar |
| `renderPlanoSidebar()` | 6865 | Sidebar horizontal do plano |
| `renderTreinoSidebar()` | 6901 | Sidebar horizontal do treino |
| `_renderContextoBanner()` | 9694 | Banner de contexto de paciente no wizard |
| `categoriaTag`, `catExameTag`, `grupoTag` | — | Chips coloridos |
| `chipInputHTML`, `alergiaInputHTML` | 7397, 7421 | Widgets de chips |
| `secao(titulo)` | 11593 | Wrapper de seção em editores densos |

---

## 6. Roteamento

### 6.1. Atributo `data-route`

Só existe nos 2 botões da sidebar (linhas 1897–1899). Handler é `onclick`
direto para `goTo('pacientes' | 'cadastros')`.

`updateHeaderBar()` (7100) percorre `.nav-item[data-route]` para
alternar a classe `.active` conforme `state.currentStep`.

### 6.2. Função central `goTo(stepId)` (6749–6839)

Fluxo:
1. Aplica `_STEP_MIGRATION` (6737) — mapeia stepIds já removidos para o
   mais próximo válido.
2. Se `stepId ∈ PLANO_SUBSTEPS`:
   - Adiciona classe `in-plano-completo` no body.
   - Ativa `#screen-plano_completo`.
   - Renderiza todos os 9 sub-renderers.
   - Monta a sidebar do plano.
   - `scrollIntoView({behavior:'smooth'})` no `#screen-<stepId>`.
3. Se `stepId ∈ TREINO_SUBSTEPS`: idem para `in-treino-completo`.
4. Caso contrário (path legado):
   - Remove ambas as classes.
   - Esconde todos os `.screen`.
   - Ativa `#screen-<stepId>`.
   - Chama o renderer.
5. Todos os caminhos chamam `renderPhaseStepper()`, `updateHeaderBar()`,
   `scheduleSave()`.

### 6.3. Navegação sequencial

`nextStep()` / `prevStep()` (7143–7154) usam `FLUXOS.find(f =>
f.steps.some(s => s.id === state.currentStep))` para pular ao vizinho na
lista definida em `STEPS`, `STEPS_TREINO`, `STEPS_RX`, `STEPS_EX`
(2261–2334).

### 6.4. Deep-linking — parcial

- `.plano-anchor` e `.pac-det-tab` usam `href="#screen-<id>"` mas o
  handler `onclick="event.preventDefault(); goTo(...)"` cancela o browser.
- O app **não lê `location.hash` no boot** — não há `hashchange` listener.
- Sem `history.pushState`.
- **URL não muda ao navegar.** Compartilhar URL é inútil — sempre abre
  na tela persistida em `state.currentStep`.

### 6.5. Boot final

Linhas 13135–13143:
```js
const validSteps = new Set([
  ...STEPS.map(s=>s.id), ...STEPS_TREINO.map(s=>s.id),
  ...STEPS_RX.map(s=>s.id), ...STEPS_EX.map(s=>s.id),
  ...CADASTRO_ROUTES,
  ...['pacientes', 'paciente_detalhe', 'cadastros']
]);
if (!validSteps.has(state.currentStep)) state.currentStep = 'pacientes';
goTo(state.currentStep);
```

Fallback é sempre a lista de pacientes.

### 6.6. Sistema de "contexto"

`state.contextoInstrumento` + `_WIZARD_HERDADOS` (linhas 8987–8992).

Quando um wizard é iniciado a partir de um paciente:
1. `criarInstrumento(tipo)` (9063) seta
   `state.contextoInstrumento = { pacienteId, pacienteNome, tipo,
     stepInicial, iniciadoEm }`.
2. `_WIZARD_START_EM_CONTEXTO[tipo]` (8984) dita o step inicial:
   - `plano_alimentar → 'objetivos'`
   - `programa_treino → 't_objetivos'`
   - `prescricao → 'rx_itens'`
   - `solicitacao_exames → 'ex_selecao'`
3. `_WIZARD_HERDADOS[tipo]` (8991) lista os steps ocultados no stepper
   (herdados da Ficha).
4. Renderer da sidebar filtra por essa lista para não mostrar etapas
   puladas.
5. Ao salvar (`salvarInstrumentoNoPaciente`), o contexto é limpo.

---

## 7. Estado global (`autonState_v1`)

### 7.1. Persistência

- **Chave:** `autonState_v1` — `localStorage` (6520, 6525, 6530).
- **Versão de seed:** `SEED_VERSION = 'auton-v2-unified'` (6248). Se
  `state.__seed !== SEED_VERSION`, ignora o storage e recarrega de
  `DEFAULT_STATE`.
- **Auto-save:** `scheduleSave()` (6536–6540) — debounce de 500 ms;
  dispara `save()` (6519) que faz `JSON.stringify(state)` (silencioso em
  erro).
- **UI de status:** `#autosave` mostra "Salvando…" (`markSaving`, 6541)
  → "Auto-salvo" (`markSaved`, 6546).

### 7.2. Reset

`reset()` (6529–6533):
```js
function reset() {
  localStorage.removeItem('autonState_v1');
  state = structuredClone(DEFAULT_STATE);
  goTo('inicio');
}
```

Chamada apenas dos CTAs "Novo atendimento" nas telas de sucesso.
**Não é acessível pela sidebar** — apesar do README mencionar botão
"Sair", o HTML atual não o tem.

### 7.3. Chave de tema (separada)

- `localStorage['auton-theme']` — `'light' | 'dark'`.
- Aplicada em `<html data-theme="...">`.
- **Não é resetada pelo `reset()`**.

### 7.4. Estrutura completa

Ver `03-DADOS.md` §6 para o mapa completo de chaves e sub-schemas.

---

## 8. Motor de cálculo

Módulo puramente funcional em 6552–6721. Sem estado interno — funções
recebem dados e retornam números.

### 8.1. Antropometria

- `calcIMC(peso, altura)` (6555) — `peso / (altura/100)²`.
- `classifyIMC(imc)` (6560) — categoria WHO (baixo peso, eutrófico,
  sobrepeso, obesidade grau I/II/III).

### 8.2. TMB (6 fórmulas)

- **Mifflin-St Jeor** (6576) — atual gold standard.
  - Homem: `10P + 6.25A − 5I + 5`
  - Mulher: `10P + 6.25A − 5I − 161`
- **Harris-Benedict revisada** (6581).
  - Homem: `88.362 + 13.397P + 4.799A − 5.677I`
  - Mulher: `447.593 + 9.247P + 3.098A − 4.330I`
- **Cunningham** (6586) — para atletas: `500 + 22 × massaMagra`.
- **FAO/OMS** (6589) — tabela por sexo × faixa etária.
- **Schofield** (6601) — idem.
- **Manual** (6612) — valor livre.

### 8.3. Energia

- `calcGET(tmb, fator)` (6619) — `tmb × fator`.
- `FATORES_ATIVIDADE` (linha 2350):
  - sedentário: 1.20
  - leve: 1.375
  - moderado: 1.55
  - ativo: 1.725
  - extremo: 1.90
- `calcVET(get, ajusteKcal)` (6623) — `get + ajusteKcal`.

### 8.4. Macros

- `calcMacrosGramas(vet, pctP, pctC, pctG)` (6627):
  - P = `(vet × pctP/100) / 4`
  - C = `(vet × pctC/100) / 4`
  - G = `(vet × pctG/100) / 9`
- `nutriPorGramas(alimento, gramas)` (6635) — proporção linear.
- `nutriRefeicao(refId)` (6644), `nutriPlano()` (6655), `metaRefeicao(refId)` (6663).

### 8.5. Sugestões por objetivo

- `suggestAjustePorObjetivo(objKey)` (6703):
  - emagrec: −400 kcal
  - ganho_massa: +350
  - performance: +200
  - gestação: +300
  - lactação: +500
  - default: neutro
- `suggestMacrosPorObjetivo(objKey)` (6713):
  - emagrec: 30/45/25
  - ganho_massa: 30/50/20
  - controle_glicemico: 25/40/35
  - cardio: 20/50/30
  - performance: 25/55/20
  - default: 20/55/25
- `suggestFormula(dados)` (6696) — prioriza Cunningham > Mifflin > FAO/OMS > manual.
- `formulaAvailability(dados)` (6685), `formulaData(key, dados)` (6675).

### 8.6. Treino

- `calc1RM(carga, reps)` (4521) — **Epley:** `carga × (1 + reps/30)`.
  Definida mas **não invocada em lugar nenhum**.
- `calcPercGorduraPollock(dobras, sexoM, idade)` (4506) — densidade por
  sexo (Pollock 7 dobras) + `% = 495/D − 450`.
- `calcVolumeTreino(treinoId)` (4526) — `Σ (series × parseFirstNumber(reps) × carga)`.
- `calcVolumePorGrupo()` (4539) — distribui volume pelos `primario` do exercício.
- `contagemExerciciosPorGrupo()` (4552), `totalItensNoPrograma()` (4564).
- `parseFirstNumber(s)` (4533) — extrai primeiro número de "8-12".

---

## 9. "IA" — o que é e o que não é

**Nenhum LLM externo é chamado.** Todas as funções `ia*` são heurísticas
locais.

| Função | Linha | O que faz |
|---|---|---|
| `iaSugerirExerciciosParaTreino(id)` | 5251 | Wrapper — seta activeTab e delega |
| `iaSugerirExercicios()` | 5451 | Filtra `allExercicios()` por `primario.includes(grupo)`, pega 1 composto + 1 isolado por grupo, define `series/reps/carga/descanso` por `fase` e `nivel` |
| `iaSugerirRefeicaoPara(refId)` | 7882 | Wrapper por refeição |
| `iaSugerirRefeicao()` | 7963 | Regex no nome ("café", "almoço", "jantar", "lanche") + distribui kcal por porção |
| `iaSugerirSubs(refId, alimentoId)` | 8045 | Filtra mesmo `grupo`, calcula gramas por isocaloria |
| `processarRevisaoTreino()` | 5608 | **Mock**. `setTimeout(800ms)` + chama `_gerarAvaliacaoIATreino` |
| `_gerarAvaliacaoIATreino()` | 5635 | Gera texto estruturado a partir do state (ANÁLISE, BALANCEAMENTO, ADEQUAÇÃO, RECOMENDAÇÕES, PRÓXIMOS PASSOS) usando `FAIXAS[objKey]` |
| `aiSuggestionObjetivo()` | 7503 | Sugere descrição de objetivo (heurística local) |
| `gerarJustificativaIA()` | 7676 | Gera texto de justificativa do VET (heurística local) |

**Nenhuma API_KEY, endpoint OpenAI/Anthropic/Gemini ou token no código.**

Rótulos como "Auton-Coach" nos toasts são branding, não integração.

---

## 10. URLs externas

Todas as `fetch()`:

| URL | Propósito | Onde |
|---|---|---|
| `data/auton.db` | SQLite embarcado | linha 1951 |
| `/data/exercicios_freedb.json?v=<ts>` | Base free-exercise-db | 4396 |
| `/data/seeds/treinos_modelo.json` | Seed treinos | 4464 |
| `/data/seeds/templates_programa.json` | Seed templates programa | 4465 |
| `./data/produtos.csv` (e 5 outros) | Overlays opcionais | 12686–12693 |
| `https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/` | **Único CDN externo em runtime** — imagens de exercício | `FREEDB_IMG_CDN` linha 4350 |
| `https://fonts.googleapis.com/...Inter...` | Google Fonts | linha 1 (link) |

---

## 11. Design System — tokens `--h2-*`

Tokens em `:root` (linhas 6–112) e dark override em
`html[data-theme="dark"]` (115–130).

### 11.1. Cores principais

**Marca / ação / accent:**
- `--h2-primary: #1e3a5f` (Auton navy).
- `--h2-primary-hover: #2d4a6f`.
- `--h2-action: #4765eb` (CTA azul).
- `--h2-action-hover: #8d9eeb`.
- `--h2-accent: #ff6418` (Bonescreen orange — crítico).
- `--h2-accent-hover: #d45314`.

**Semânticas:**
- `--h2-success: #10b981`, `--h2-warning: #f59e0b`,
  `--h2-danger: #ef4444`, `--h2-info: #4765eb`.
- Cada uma tem versão `-bg` com alpha 10%.

**Superfícies (light):**
- `--h2-bg: #fafafa`, `--h2-bg-tinted: #EBF3F6`, `--h2-surface: #ffffff`,
  `--h2-surface-raised: #ffffff`.

**Superfícies (dark):**
- `--h2-bg: #0e1724`, `--h2-bg-tinted: #0f1620`, `--h2-surface: #14202c`,
  `--h2-surface-raised: #182838`.

**Texto (light):** `#1f1d2a`, `#5b5875`, `#7a788f`.
**Texto (dark):** `#f0eff4`, `#cbd3e1`, `#8898ab`.

### 11.2. Geometria

- **Radius:** sm .5rem, base 1rem, lg 1.25rem, pill 999px.
- **Espaço:** escala 1..12 (0.25rem × N).
- **Shadow:** sm/md/lg/xl + action (com tint).

### 11.3. Tipografia

- **Font:** Inter (Google Fonts).
- **Forçada:** `html, body, * { font-family: 'Inter' !important }`
  (linha 145).
- **Mono:** JetBrains Mono (só para códigos).

### 11.4. Motion

- `--h2-ease: cubic-bezier(0.4, 0, 0.2, 1)`.
- `--h2-transition-fast: 0.18s var(--h2-ease)`.
- `--h2-transition: 0.35s var(--h2-ease)`.
- `--h2-transition-slow: 0.6s var(--h2-ease)`.
- **Transição global:** `* { transition: background-color .2s, color .2s,
  border-color .2s }` (linha 164) — anima o toggle dark/light.

### 11.5. Aliases de retrocompat

Linhas 80–111 — expõe `--color-bg`, `--color-surface`, `--color-text`,
etc. apontando para os `--h2-*`. Todo CSS legado continua funcionando.

### 11.6. Componentes CSS reutilizáveis

Ver `AUTON-DESIGN-SYSTEM.md` (raiz do projeto) para catálogo completo.
Principais nomes que aparecem no HTML:

| Componente | Classe base | Local (aprox.) |
|---|---|---|
| Sidebar 240px | `.sidebar` + `.nav-item` | 225–274 |
| Topbar 56px | `.topbar` + `.search-wrap` + `.kbd` + `.topbar-actions` | 392+ |
| Card | `.card` (alias `.h2-card`) + `.h2-card__title` + `.h2-icon-chip--{blue,orange,violet,mint,slate,navy}` | 664–697 |
| Hero KPI | `.h2-hero` + `.h2-hero__number` + `.h2-hero__label` | 700–716 |
| Botão | `.btn` + variantes `.btn-{primary,action,destructive,secondary,ghost,link,danger}` + tamanhos `.btn-{sm,lg,icon}` | 767–851 |
| Badge | `.badge` + `.badge-{success,warning,error,danger,info,ai,navy}` + `.badge-dot` | 862–876 |
| Status badge | `.status-badge` + `.status-{confirmed,pending,cancelled,in-progress,waiting,recording,processing}` | 879–893 |
| Alert | `.alert` + `.alert-{default,success,warning,destructive}` | 898–911 |
| Choice card | `.choice` + `.choice-{icon,title,desc}` + `.choice.selected` | 913–929 |
| Radio list | `.radio-list` + `.radio-row` + `.radio-mark` + `.radio-body` | 932–955 |
| AI panel | `.ai-panel` + `.ai-icon` + `.ai-title` + `.btn-ai` + `.btn-ai-ghost` + `.ai-spark` | 958–989 |
| Chip / input | `.chip-input` + `.chip` + `.chip.critical` + `.chip.warning` | 992–1011 |
| Tabs | `.tabs` + `.tab` + `.tab.active` + `.tab-panel` | 1013–1029 |
| Slider | `.slider` + `.slider-row` + `.slider-thumb` | 1031–1050 |
| Autocomplete | `.ac-list` + `.ac-item` + `.ac-item.blocked` | 1100–1119 |
| Meal item | `.meal-item` + `.meta-bar` + `.meal-tabs` + `.meal-tab.filled/active` | 1121–1156 |
| Val cards | `.val-card.{ok,warn,err}` | 1159–1173 |
| Modal | `.modal-backdrop` (blur 6px) + `.modal` + `.modal-{header,body,footer,title,close}` | 1233–1272 |
| Theme toggle | `.theme-toggle` + `.icon-sun` + `.icon-moon` | 1277–1292 |
| Plano-sidebar | `.plano-sidebar` + `.plano-anchor{-num, .active, .done}` | 550–587 |
| Info tip | `.info-tip` | 607–618 |

**Não há:** drawer, sidebar colapsável (rail é fixo em 240 px), select
customizado (usa `<select>` nativo).

### 11.7. Toggle de tema

**Boot** (linhas 1919–1924):
```js
(() => {
  const stored = localStorage.getItem('auton-theme');
  const preferred = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  const theme = stored || preferred;
  document.documentElement.setAttribute('data-theme', theme);
})();
```

**Toggle** (1926–1931):
```js
window.toggleTheme = function () {
  const cur = document.documentElement.getAttribute('data-theme') || 'light';
  const next = cur === 'dark' ? 'light' : 'dark';
  document.documentElement.setAttribute('data-theme', next);
  localStorage.setItem('auton-theme', next);
};
```

**UI:** botão `.theme-toggle` na topbar (linha 1910). CSS troca
`display` dos SVGs conforme `html[data-theme="dark"]`.

**Persistência:** `localStorage['auton-theme']` (não é o `autonState_v1`).

---

## 12. Fluxo end-to-end (walkthrough do boot)

1. **Usuário duplo-clica `start.command`** → sobe Python http.server 8787.
2. **Browser abre `http://localhost:8787/index.html`** → baixa HTML +
   fonts.
3. **HTML executa CSS (`<head>`)** → aplica design tokens.
4. **Script síncrono no head — tema** (1919) → aplica `data-theme` no
   `<html>` **antes** de qualquer render (evita flash).
5. **Body renderiza** — sidebar + topbar + `#main` vazio + `#modalRoot` +
   `#toast` + 40+ `<section class="screen" id="screen-*">` (todos
   `.hidden`).
6. **`<script src="lib/sql-wasm.js">` carrega** → cria `window.initSqlJs`.
7. **Bloco principal JS executa:**
   - Declara todas as constantes (STEPS, FLUXOS, CATEGORIAS_*, SCHEMAS_*,
     PRODUTOS_SEED, EXAMES_SEED, MODELOS_EXAMES_SEED, etc.).
   - Declara `AutonDB` (IIFE) — não faz init ainda.
   - Declara `RENDERERS = {}`.
   - Declara todas as funções (renderers, motor de cálculo, CRUD, etc.).
   - Chama `AutonDB.ready()` (assíncrono).
   - Chama `load()` — lê `localStorage['autonState_v1']`, valida
     `__seed`, rehidrata `state`, roda migrações inline.
   - Chama `window.__carregarExerciciosFreeDB()` (assíncrono) →
     mescla exercicios em `state.cadastros.exercicios`.
   - Chama `window.__carregarSeedsTreino()` (assíncrono) → mescla
     seeds JSON.
   - Chama `loadCadastrosFromCSV()` (assíncrono) → overlay opcional.
   - Chama `goTo(state.currentStep)` → renderiza tela persistida (default:
     `pacientes`).
8. **AutonDB resolve `ready()`** → dispara `autondb:ready` → invalida
   caches → re-renderiza tela atual.

Depois: cada interação do usuário é síncrona (não há requests). Só
imagens de exercícios continuam sendo carregadas do CDN GitHub.

---

## 13. Dívidas técnicas identificadas

Consolidação dos alertas dos capítulos anteriores:

### 13.1. UI incompleta
- Botão **"Sair"** na sidebar mencionado no README não existe no HTML.
- Botão **"Novo paciente"** é stub (`toast('em breve')`).
- Aba **"Evolução Fotográfica"** é placeholder.
- Botões **Imprimir / Enviar por email** em rx_sucesso, ex_sucesso e
  sucesso do plano são stubs.
- **Search bar da topbar** (`⌘K`) é decorativa.
- **Botões Academy/Ajuda** são stubs.

### 13.2. Modelo de dados
- `state.paciente/anamnese/avaliacao/...` (raiz — legado single-paciente)
  coexiste com `state.pacientes[]` (modelo ontológico novo).
- **Instrumento não guarda conteúdo** — só metadado (`resumo`). Reabrir
  para editar não é possível.
- `paciente.ficha.antropometria` é série temporal, mas **não há UI de
  gráfico**.

### 13.3. Arquitetura
- **Deep-link URL não funciona** — `location.hash` não é lido.
- **Renderers duplicados** — `cadastroExercicios`, `cadastroTreinos`,
  `cadastroTemplatesPrograma` definidos duas vezes (a segunda sobrescreve).
- **Constantes duplicadas** — `GRUPOS_MUSCULARES` × `GRUPOS_MUSC`,
  `SPLITS_LABELS` × `SPLITS`, `OBJETIVOS_LABELS_PT` × `OBJETIVOS_TREINO`.
- **FTS5 tabelas populadas mas não usadas** — busca usa LIKE puro.
- **`escapeFTS()` definida e nunca chamada.**
- **6 steps de treino ocultos** (`display: none`) por refactor.
- **8 renderers legados do plano alimentar** ficam mortos no bundle.
- **`1RM Epley` definido e não invocado.**

### 13.4. Seeds vazios
- `FORMULAS_SEED = []`
- `TEMPLATES_PRESCRICAO_SEED = []`
- `GRUPOS_CLINICOS_TP = []`
- `EXERCICIOS_SEED = []` (freedb via JSON)

### 13.5. Enriquecimento
- `produtos_precos` (CMED) — 0 rows.
- `produtos_sinonimos` — 0 rows.
- `crosswalk_medicamentos` — 0 rows.
- Pipeline ETL descrito no brief não rodou completamente.

### 13.6. Manutenção
- **7 backups `.bak_*`** manuais na pasta (44models, alimentos121,
  jejum, medidas, pool_planos, pre_emojis, pre_labels) — indicam
  iteração intensa sem VCS ativo. **Repositório não é git**.

---

## 14. Restrições e limites conhecidos

- **Concorrência:** o app é single-user. Não há trava de concorrência —
  se o profissional abrir duas abas do navegador, ambas escrevem no
  mesmo `localStorage` e a última fechada vence.
- **Storage:** `localStorage` tem limite ~5-10 MB por origem. Com 100
  pacientes × 10 atendimentos × 3 instrumentos ≈ 30k objetos —
  provavelmente cabe, mas pode encostar no teto se os `resumo[]`
  crescerem muito.
- **Sync:** não há backup automático. Se o usuário limpar o
  `localStorage` do navegador, perde tudo.
- **Multi-device:** não há sync entre computadores. Cada instalação é
  isolada.
- **Imagens de exercício:** hot-linked do GitHub — se `raw.githubusercontent.com`
  cair ou o repositório freedb for removido, as imagens somem (mas os
  exercícios continuam disponíveis).
- **CORS:** o app precisa rodar num servidor HTTP (a Python `http.server`
  é suficiente). `file://` não funciona.
