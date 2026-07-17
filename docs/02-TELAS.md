# 02 · Telas e Funcionalidades

> Percurso completo pelo `index.html`. Cada tela documenta: propósito, o
> que aparece na UI, campos coletados, ações disponíveis, transições,
> regras específicas. Números de linha referem ao `index.html` em
> `2026-07-16`.
>
> Assuma este mapa como o "manual do produto". Se uma funcionalidade
> aparece no código mas não neste doc, é lacuna a corrigir.

---

## Sumário

- [Chassi: sidebar, topbar, header dinâmico](#0-chassi-sidebar-topbar-header-dinâmico)
- [PACIENTES (landing)](#1-pacientes-landing)
- [PACIENTE — Detalhe (5 abas)](#2-paciente--detalhe-5-abas)
  - [Visão Geral](#21-aba-visão-geral)
  - [Ficha Clínica](#22-aba-ficha-clínica-4-sub-abas)
  - [Atendimentos](#23-aba-atendimentos)
  - [Instrumentos](#24-aba-instrumentos)
  - [Evolução Fotográfica](#25-aba-evolução-fotográfica)
- [MODAL Ficha Técnica (usado nos wizards)](#3-modal-ficha-técnica)
- [WIZARD Plano Alimentar (9 substeps + legados)](#4-wizard-plano-alimentar)
- [WIZARD Programa de Treino (7 visíveis + 6 ocultos)](#5-wizard-programa-de-treino)
- [WIZARD Prescrição (6 telas)](#6-wizard-prescrição)
- [WIZARD Solicitação de Exames (6 telas)](#7-wizard-solicitação-de-exames)
- [CADASTROS — 4 domínios × 3 níveis](#8-cadastros)
- [Painel Catálogo Oficial (busca ANVISA/LOINC via SQLite)](#9-painel-catálogo-oficial)
- [Modais globais](#10-modais-globais)

---

## 0. Chassi: sidebar, topbar, header dinâmico

Todo o app compartilha um único chassi (linhas 1897–1911).

### 0.1. Sidebar (`.sidebar` — `aside`)
Fixa 240 px, à esquerda. **Duas** entradas de rota:

| Item | Rota | Ícone | Comportamento |
|---|---|---|---|
| Pacientes | `data-route="pacientes"` | 👥 | `goTo('pacientes')` |
| Cadastros | `data-route="cadastros"` | 📚 | `goTo('cadastros')` |

Estilos: `.nav-item.active` marcado pelo `updateHeaderBar()` (linha 7100)
quando o `state.currentStep` bate com a rota.

**Não existem** rotas Home, Agenda, Consultas, Academy, Configurações,
Sair. Ícones e labels dessas ideias podem aparecer em telas de sucesso,
mas nunca como itens de navegação.

**Não existe botão "Sair"** no rodapé da sidebar, apesar de o `README.txt`
mencionar. A função `reset()` (linha 6529) existe mas é acionada apenas
pelos CTAs "Novo atendimento" nas telas de sucesso.

### 0.2. Topbar (`.topbar`)
Fixa 56 px, no topo.

- **Search bar** (`.search-wrap`) — placeholder `"Buscar pacientes,
  consultas, ações..."` + shortcut `⌘K`. Sem lógica de busca — é
  decorativa.
- **Botão "Academy"** — `toast('em breve')`.
- **Botão "Ajuda"** — `toast('em breve')`.
- **Toggle de tema** (`.theme-toggle`) — dois SVGs (sol/lua); alterna
  `html[data-theme]` e persiste em `localStorage['auton-theme']`.

### 0.3. Header dinâmico (dentro de cada `.screen`)
Mostra o rótulo da fase atual e uma barra de progresso quando o wizard
tem múltiplos steps. Rendering em `updateHeaderBar()` e
`renderPhaseStepper()` (linhas 6991–7106).

O rótulo é derivado de `FLUXOS` (linha 2337): mapeia o step atual para
um `title` (`"Novo Plano Alimentar"`, `"Novo Programa de Treino"`,
`"Nova Prescrição"`, `"Nova Solicitação de Exames"`).

### 0.4. Sidebar horizontal dos wizards (`.plano-sidebar`)
Só aparece durante wizards de Plano Alimentar (`renderPlanoSidebar`,
linha 6865) e Programa de Treino (`renderTreinoSidebar`, linha 6901).
Lista os substeps do wizard como âncoras clicáveis, marca a etapa
ativa e as completadas (via `stepCompleted()`/`tStepCompleted()`).

---

## 1. PACIENTES (landing)

**Rota:** `pacientes` · **Renderer:** `RENDERERS.pacientes` (linha 8821).

Tela inicial do app. Substitui um dashboard tradicional — a lista de
pacientes **É** o dashboard.

### 1.1. Header de estatísticas
Três cards KPI (linhas 8880–8908):

| Card | Métrica | Fonte |
|---|---|---|
| **Ativos** | `state.pacientes.filter(p => p.status === 'ativo').length` | `state.pacientes` |
| **Novos este mês** | pacientes com `criadoEm` no mês/ano atual | idem |
| **Arquivados** | `p.status === 'arquivado'` | idem |

### 1.2. Barra de filtros
- **Busca por texto**: `filtrarPacientes(q)` (linha 8932) — grava em
  `state.pacientesFiltro.q`, filtra por `nome`, `cpf`, `email`.
- **Chips de status**: Todos / Ativo / Inativo / Arquivado —
  `filtroStatusPacientes(s)` (linha 8937).

### 1.3. Botão "Novo paciente"
**Não implementado.** Chama `toast('Cadastro de paciente — em breve.')`
(linha 8874). Não há função `novoPaciente`, `salvarPaciente` nem form.
Pacientes vêm exclusivamente do `DEFAULT_STATE.pacientes[]` (seed) e do
que o profissional editar via modal Ficha (§3) — sem ponto de entrada
para criar do zero pela UI.

### 1.4. Tabela de pacientes
Colunas: **Avatar (iniciais)** · **Nome** (+idade + sexo derivados) ·
**Cidade/UF** · **Último atendimento** (derivado) · **Status** (chip
colorido) · **Ação** (botão "Abrir").

Clique em qualquer linha → `abrirPaciente(id)` (linha 8942):
```
state.pacienteAtivoId = id;
state.pacienteDetalheTab = 'visao-geral';
state.pacienteDetalheSubTab = null;
goTo('paciente_detalhe');
```

---

## 2. PACIENTE — Detalhe (5 abas)

**Rota:** `paciente_detalhe` · **Renderer:** `RENDERERS.paciente_detalhe` (linha 9745).

Header do paciente: avatar, nome, meta-info (idade, sexo, cidade,
telefone), botão **"+ Novo instrumento"** (dropdown), botão de voltar.

O botão "+ Novo instrumento" (`togglePacActionsMenu`, linha 8954) abre
menu com 4 opções — cada uma chama `criarInstrumento(tipo)`:
1. **Plano Alimentar** — "14 etapas — anamnese, cálculo, refeições"
2. **Programa de Treino** — "13 etapas — periodização, split, exercícios"
3. **Prescrição** — "Itens + posologia + emissão"
4. **Solicitação de Exames** — "Seleção de exames + emissão"

### 2.0. Tabs de topo (`_PAC_TABS`, linha 9737)

Navegação por `mudarPacTab(id)` (linha 9828):

| Aba | id | Renderer |
|---|---|---|
| Visão Geral | `visao-geral` | `_renderPacVisaoGeral` (9862) |
| Ficha Clínica | `ficha` | `_renderPacFicha` (9917) |
| Atendimentos | `atendimentos` | `_renderPacAtendimentos` (10027) |
| Instrumentos | `instrumentos` | `_renderPacInstrumentos` (10064) |
| Evolução Fotográfica | `evolucao` | `_renderPacEvolucao` (10115) |

### 2.1. Aba "Visão Geral"

Renderer: `_renderPacVisaoGeral` (linha 9862).

**Layout:** grid 3×2 de KPI cards + 2 cards largos.

**KPI cards:**
- **Peso** (última medição de `ficha.antropometria`) — via `_pacUltimoPeso(p)` (8793).
- **IMC** — derivado (`_pacIMC(p)`, 8797).
- **Objetivo** — `ficha.objetivo.tipo` traduzido.
- **Instrumentos vigentes** — `_pacInstrumentosVigentes(p).length` (8802).

**Cards largos:**
- **Último atendimento** — data, tipo, status. Botão "Ver detalhes".
- **Evolução** — placeholder textual ("gráfico em breve").

### 2.2. Aba "Ficha Clínica" (4 sub-abas)

Renderer: `_renderPacFicha` (linha 9917) — **modo leitura**.

Sub-abas via `mudarPacSubTab(sid)` (linha 9839):

#### 2.2.1. Anamnese
Blocos empilhados (todos apenas leitura):
- **Queixa principal** — texto.
- **Histórico clínico** (HDA + HPP misturados).
- **Antecedentes familiares**.
- **Medicamentos em uso** (`ficha.anamnese.medicamentosEmUso[]`) — chips.
- **Suplementos** (`suplementos[]`) — chips.
- **Alergias** (`alergias[{agente, gravidade}]`) — chips críticas.
- **Intolerâncias** — chips.
- **Cirurgias** — lista.
- **Hábitos** — sono (horas), água (ml), álcool, tabaco, intestino.
- **Data da última atualização** — `atualizadaEm`.

Para editar: botão "Editar Ficha" (topo direito) → abre modal (§3).

#### 2.2.2. Antropometria
Tabela invertida em ordem cronológica (mais recente primeiro):
Data · Peso · Altura · IMC (derivado) · % Gordura · Massa Magra ·
Cintura · Quadril · Relação C/Q (derivado).

Botão "+ Nova medição" → abre modal Ficha em modo edit, sub-aba
`antropometria`.

#### 2.2.3. Objetivo
Card único mostrando `tipo`, `descricao`, `metaPeso`, `prazoMeses`,
`definidoEm`, `status`.

#### 2.2.4. Estilo de vida
`fatorAtividade`, `disponibilidadeTreinoSemanal`, chips de
`preferencias[]`, `aversoes[]`, `restricoesReligiosas[]`.

### 2.3. Aba "Atendimentos"

Renderer: `_renderPacAtendimentos` (linha 10027).

Timeline vertical de todos os `p.atendimentos[]`, mais recente primeiro.

**Card de cada atendimento:**
- Data, tipo (badge), status (badge), profissional.
- Motivo.
- Lista de Instrumentos emitidos (link para aba Instrumentos).
- Botão **"Concluir"** se `status === 'em_andamento'` →
  `concluirAtendimento(atdId)` (linha 10052).

Não há "criar atendimento" — atendimento nasce da emissão de instrumento
(§5.1 da ontologia).

### 2.4. Aba "Instrumentos"

Renderer: `_renderPacInstrumentos` (linha 10064).

**Sub-tabs por tipo:** Todos · Alimentar · Treino · Prescrição ·
Exames.

**Sub-tab "Todos"** — mostra 4 CTAs: "+ Novo Plano Alimentar", "+ Novo
Programa de Treino", "+ Nova Prescrição", "+ Nova Solicitação de Exames".

**Sub-tab de tipo específico** — mostra CTA "+ Novo <tipo>" único no
topo, seguido da lista de instrumentos desse tipo (`vigente` no topo,
depois `substituido` desbotados).

**Card de instrumento:**
- Ícone do tipo, resumo (`resumo`), data de emissão (`emitidoEm`),
  atendimento vinculado.
- Badge `vigente` (verde) ou `substituido` (cinza).
- Menu de ações (⋯) — hoje só "Ver detalhes" (placeholder).

**Limitação:** clicar em ver instrumento **não abre o conteúdo original**
(§2.7 da ontologia — instrumento só guarda metadado).

### 2.5. Aba "Evolução Fotográfica"

Renderer: `_renderPacEvolucao` (linha 10115).

**Placeholder.** Texto: "em breve — galeria com fotos frente/lado/costas
por data".

---

## 3. MODAL Ficha Técnica

**Aberto por:** `abrirFichaModal('view' | 'edit')` (linha 9197).
**Renderer:** `_renderFichaModal` (9209).

Usado tanto na aba Ficha do paciente_detalhe quanto **sobre** wizards
(pelo banner de contexto — permite consultar/editar a Ficha sem sair do
wizard em andamento).

### 3.1. Estrutura
- Toggle "Visualizar / Editar" (`mudarModoFicha`, linha 9306).
- Sub-tabs (viram âncoras — `scrollFichaTo(id)`, linha 9296): Anamnese,
  Antropometria, Objetivo, Estilo de vida.
- Conteúdo é um documento longo com as 4 seções empilhadas
  (`#ficha-sec-<tab>` para cada).
- **Scroll-spy** atualiza qual pill fica ativa conforme o usuário rola.

### 3.2. Modo View
Cards read-only estilo consulta (mesmos dados de `_renderPacFicha`).

### 3.3. Modo Edit
Cada seção vira um formulário.

**Anamnese** (`_renderFichaModalEdit`, sub-tab `anamnese`):
- Textareas: queixa, histórico clínico, antecedentes familiares.
- Chip-inputs: medicamentos, suplementos, alergias (com prompt de
  gravidade), intolerâncias, cirurgias.
- Radios: álcool, tabaco, intestino.
- Numerics: sono (h), água (ml).

**Antropometria** (sub-tab `antropometria`):
- Form de nova medição: Data, Peso (kg)*, Altura (cm)*, Cintura,
  Quadril, % Gordura, Massa magra. Peso+Altura obrigatórios.
- Ao salvar → push em `ficha.antropometria`. Nunca sobrescreve
  (série temporal).

**Objetivo** (sub-tab `objetivo`):
- Select `tipo`, textarea `descricao`, number `metaPeso`, number
  `prazoMeses`, radio `status`.

**Estilo de vida** (sub-tab `estilo`):
- Select `fatorAtividade`, number `disponibilidadeTreinoSemanal`,
  chip-inputs `preferencias`, `aversoes`, `restricoesReligiosas`.

### 3.4. Ações
- **Salvar** — `salvarFicha()` (linha 9599) → `_coletarTodasSecoesDoForm()`
  (9523) percorre `[data-ff]` de cada `#ficha-sec-*` e grava em
  `paciente.ficha.*`. Re-renderiza banner de contexto + wizard atual.
- **Cancelar** — descarta mudanças, fecha modal.

---

## 4. WIZARD Plano Alimentar

**Rota-âncora:** `screen-plano_completo` (contêiner único).
**Sub-steps ativos** (`PLANO_SUBSTEPS`, linha 6729):
`inicio → anamnese → avaliacao → objetivos → estrategia_calorica → estrutura → montagem → substituicoes → distribuicao_macros`.

Além dos 9 ativos, **8 renderers legados** ficam disponíveis por
compatibilidade (`formula`, `get`, `estrategia`, `macros`, `revisao`,
`validacao`, `publicacao`, `sucesso`, `revisar_publicar`) — não fazem
parte do fluxo padrão, redirecionados por `_STEP_MIGRATION` (linha 6744).

**Fases** (`PHASES`, linha 2273): Contexto (etapas 1) · Avaliação (2–3)
· Estratégia (4–5) · Plano (6–9).

**Entry points:**
- Standalone: `goTo('inicio')` (a partir do menu — mas o menu não tem
  esse acesso; o entry padrão é via paciente).
- De paciente: `criarInstrumento('plano_alimentar')` → pula
  `inicio + anamnese + avaliacao` (herdados da Ficha), começa em
  `objetivos`.

**Sidebar horizontal** com 9 âncoras clicáveis (renderPlanoSidebar,
linha 6865).

### Etapa 1 · Início do Atendimento
**Renderer:** `RENDERERS.inicio` (7168–7180).

- **Select** `tipo` de atendimento: `inicial | retorno | urgencia`.
- **Banner** se template aplicado (`state.origem_template_id`).
- **Ações:** `setTipo`, `descartarTemplate`.
- **Nav footer:** "Iniciar Anamnese →".

### Etapa 2 · Anamnese
**Renderer:** `RENDERERS.anamnese` (7322–7386) + `renderAnamneseTab` (7337).

Quatro blocos empilhados:

**Clínica:**
- Textarea `queixa`*, textarea `historicoClinico`.
- Chip-inputs `medicamentos[]`, `suplementos[]` (`a_addChip`, `a_removeChip`).

**Alimentar:**
- Chip-inputs `preferencias[]`, `aversoes[]`.
- Textarea `registro24h` (recordatório 24h).

**Hábitos:**
- Radios `nivelAtividade` (5 opções de `FATORES_ATIVIDADE`).
- Range 1-10: `qualidadeSono`, `nivelEstresse`.
- Radios `habitoIntestinal`.
- Number `hidratacao_ml`.

**Restrições:**
- Chip-input `alergias[{agente, gravidade}]` (`a_addAlergia` usa `prompt()`
  para gravidade).
- Chip-input `intolerancias[]`.
- Text-input `restricoesReligiosas`.

**Setters:** `a_set(k,v)` (7388).

### Etapa 3 · Avaliação Nutricional
**Renderer:** `RENDERERS.avaliacao` (7449–7478).

- **Obrigatórios:** `peso`*, `altura`*, `dataMedicao`.
- **Composição corporal:** radios `metodoComposicao` (bioimpedancia /
  dobras / dexa / estimativa) → mostra numerics `massaMagra`, `massaGorda`,
  `percGordura`.
- **Derivado ao vivo:** IMC + classificação WHO + barra visual.

**Setter:** `av_set(k,v)`.

### Etapa 4 · Objetivos Clínicos
**Renderer:** `RENDERERS.objetivos` (7480–7501).

- Select `objetivo.key` (10 opções de `OBJETIVOS`).
- Textarea `descricao` — obrigatória se `key === 'outro'`.
- Botão IA (✨) sugestão de descrição (`aiSuggestionObjetivo`).

Ao mudar objetivo, o app já pré-computa um ajuste calórico sugerido
(`_AJUSTE_POR_OBJETIVO`, 7206).

### Etapa 5 · Estratégia Calórica (consolidada)
**Renderer:** `RENDERERS.estrategia_calorica` (8258–8435).

Tela mais densa do fluxo. Quatro blocos:

**Bloco 1 · TMB:**
- Select `formulaKey` (6 fórmulas: Mifflin-St Jeor, Harris-Benedict,
  Cunningham, FAO/OMS, Schofield, Manual).
- Input opcional `tmbManual` se `formulaKey === 'manual'`.
- Mostra TMB calculado.

**Bloco 2 · GET:**
- Select `fatorAtividade` (`FATORES_ATIVIDADE`: 1.20, 1.375, 1.55, 1.725,
  1.90).
- Mostra GET = TMB × fator.

**Bloco 3 · Template:**
- Botão **"Escolher template"** (`abrirTemplateModal`) — abre modal
  com cards de templates filtrados por objetivo. Aplicar chama
  `aplicarTemplate(id)` (7224).

**Bloco 4 · VET final:**
- Select `ajusteTipo` (deficit / neutro / superavit).
- Slider `ajusteKcal` (−1000 a +1000).
- Textarea `justificativa`* + botão IA para gerar (✨ `gerarJustificativaIA`).
- Mostra VET = GET + ajusteKcal.

**Ações:** `setFormula`, `setTmbManual`, `setFator`, `setAjusteTipo`,
`setAjuste`, `setJustificativa`, `aplicarSugestaoAjuste`, `abrirTemplateModal`,
`aplicarTemplate`, `descartarTemplate`, `confirmEstrategiaCalorica`.

### Etapa 6 · Método + Estrutura das Refeições
**Renderer:** `RENDERERS.estrutura` (7753–7793).

Tabela de refeições. Cada linha: nome, `horario` (time), `pctVet` (%
do VET). Soma de `pctVet` deve = **100%** (validação inline).

**Método:** fixado em `gramaturas` (única opção ativa; `equivalencias`
existia como opção legada).

**Ações:** `addRefeicao`, `removeRefeicao`, `setRefeicaoField`,
`setMetodo` (no-op).

### Etapa 7 · Montagem de Refeições
**Renderer:** `RENDERERS.montagem` (7795–7849).

Para cada refeição:
- **Autocomplete inline** `foodSearch-{refId}` — busca em `AutonDB.buscarAlimentos()`.
- **Lista de itens** (`renderMealItem`): alimento, gramas, obs.
- **Barra de progresso** por refeição (kcal, P, C, G vs meta).
- **Progresso global** no rodapé (kcal, P, C, G totais vs VET).
- **Alergeno-blocking** (`isAlergenoBlocked`) — impede adicionar alimento
  com alergeno declarado na anamnese.
- **Flag de intolerância** (`isIntoleranciaFlag`) — avisa mas não bloqueia.
- **Botão IA** por refeição — `iaSugerirRefeicaoPara(refId)` — heurística
  local (regex no nome da refeição).

**Ações:** `searchFoodInline`, `addFoodTo`, `editItem` (via `prompt()`
edita gramas), `removeItem`.

### Etapa 8 · Substituições
**Renderer:** `RENDERERS.substituicoes` (8007–8067) + `renderSubstituicaoRefeicao` (8019).

Para cada item de cada refeição, permite adicionar até 3 substitutos
isocalóricos.

- **IA sugere:** `iaSugerirSubs(refId, alimentoId)` — filtra alimentos do
  mesmo `grupo`, calcula gramas por isocaloria.
- **State:** `state.plano.substituicoes[refId:alimId] = [{alimentoId, gramas}]`.
- Obrigatório apenas se método for `equivalencias` (legado).

### Etapa 9 · Distribuição de Macros
**Renderer:** `RENDERERS.distribuicao_macros` (8437–8566).

Tela final. **Não coleta nada** — apenas mostra:
- Tabela comparativa **alvo × real** para P/C/G/VET (real via TACO).
- Stacked bars alvo e real lado a lado.
- Deltas com badges verde/amarelo/vermelho (<5g / <15g / ≥15g).
- Botão final **"Publicar plano →"** → `publicarPlanoAlimentar()` (8569).

### Publicação
`publicarPlanoAlimentar()` (linha 8569):
- Marca `state.plano.publicado = true`.
- Registra `publicadoEm`.
- Se `state.contextoInstrumento`: chama `salvarInstrumentoNoPaciente()`
  → instrumento com `resumo: "{VET} kcal · {N} refeições · {ajusteTipo} {kcal}"`.

Nas telas legadas: `RENDERERS.sucesso` (8253) mostra ✓ e CTA "Novo plano"
(chama `reset()`) ou "Salvar em {paciente}".

---

## 5. WIZARD Programa de Treino

**Rota-âncora:** `screen-treino_completo`.
**Sub-steps visíveis** (`TREINO_SUBSTEPS`, linha 6733):
`t_inicio → t_anamnese → t_avaliacao → t_objetivos → t_programa → t_semana → t_split`.

Além dos 7 visíveis, **6 steps ocultos** (`display: none !important`):
`t_periodizacao` (auto-derivado do objetivo), `t_montagem` (mesclado com
t_split), `t_revisao`, `t_validacao`, `t_atribuicao`, `t_sucesso`. Alguns
são chamados via IA ou deep-link.

**Sidebar horizontal:** `renderTreinoSidebar` (6901). Em contexto de
paciente, filtra por `_WIZARD_HERDADOS.programa_treino` (esconde
`t_inicio, t_anamnese, t_avaliacao`).

### Etapa 1 · Início Atendimento
**Renderer:** `RENDERERS.t_inicio` (4611).

- Select `atendimento.tipo`: `inicial | retorno | ajuste`.
- Card read-only do aluno (nome, idade, sexo, data — vem do paciente ativo
  ou é editável se standalone).
- **Nav footer:** "Iniciar Anamnese →".

**Ação:** `tSetTipo(t)` (4861).

### Etapa 2 · Anamnese
**Renderer:** `RENDERERS.t_anamnese` (4864).

- Textareas: `queixa`, `historicoClinico`.
- Chip-inputs: `medicamentos[]` (`anamneseAddChip`/`Remove`, linhas 4590/4599).
- Numerics/ranges: `qualidadeSono`, `nivelEstresse`.
- Selects: `experienciaPrevia` (NIVEIS_TREINO), `localTreino` (academia /
  casa / ar_livre / estudio).
- Numerics: `disponibilidadeSemanal`, `tempoDisponivelMin`.
- Chip-inputs: `preferencias`, `aversoes`.
- Textarea: `objetivoDetalhado`.
- **Lesões** (`lesoes[]`): botão "+ Adicionar lesão" chama
  `addLesaoPrompt()` — 4 `window.prompt()` sequenciais (região, quando,
  status, observação).
- Chip-input: `restricoesMovimento[]`.

**Setters:** `t_a_set(k,v)` (4925), `removeLesao(i)` (4937).

### Etapa 3 · Avaliação Física
**Renderer:** `RENDERERS.t_avaliacao` (4940).

- Numerics: `peso`, `altura`, `fc_repouso`.
- Derivado: **IMC + classificação WHO** (barra visual).
- Radio: `metodoComposicao` (bioimpedancia / dobras / dexa / estimativa).
- Se dobras → 7 numerics **Pollock**: tricipital, subescapular,
  suprailiaca, abdominal, peitoral, axilarMedia, crural. Calcula
  **% gordura via `calcPercGorduraPollock`** (4506).
- Numerics: `cintura`, `quadril` → relação C/Q derivada.
- Numerics: `massaMagra`, `percGordura` (se não usar dobras).

**Setters:** `t_av_set(k,v)` (4964), `setDobra(d,v)` (4965).

### Etapa 4 · Objetivo
**Renderer:** `RENDERERS.t_objetivos` (4968).

Radio grid: hipertrofia, emagrecimento, condicionamento, forca,
performance, saude, reabilitacao, outro.

Ao selecionar → auto-deriva `periodizacao.fase` via
`_FASE_POR_OBJETIVO_TREINO` (4984). Ex: `hipertrofia → 'hipertrofia'`,
`emagrecimento → 'definicao'`, `forca → 'forca'`.

**Setter:** `setObj(k)` (4994).

### Etapa 5 (oculta) · Periodização
**Renderer:** `RENDERERS.t_periodizacao` (5018).

Não visível na sidebar. Apenas expõe `periodizacao.fase` (adaptacao /
hipertrofia / forca / potencia / manutencao / definicao) para deep-link
manual. Comentário na linha 2299: "Periodização é derivada
automaticamente do objetivo — não é step visível".

**Setter:** `setFase(k)` (5034).

### Etapa 6 · Programa
**Renderer:** `RENDERERS.t_programa` (5037).

- **Bloco template compacto:** botão "Aplicar template" (abre modal),
  "Trocar", "Descartar" (`abrirTemplateTreinoModal` 4800,
  `tDescartarTemplate` 4792).
- Text `programa.nome`.
- Numeric `duracao_semanas`.
- Radio `programa.nivel`.
- Card **"Fim previsto"** — data atual + `duracao_semanas × 7 dias`.

**Setter:** `pg_set(k,v)` (5102).

### Etapa 7 · Semana
**Renderer:** `RENDERERS.t_semana` (5105).

- Numeric `semana.dias_treino`.
- Numeric `semana.tempo_treino_min`.
- Chip toggles `dias_semana[]` — segunda a domingo.

**Setters:** `sem_set(k,v)` (5128), `toggleDia(d)` (5129).

### Etapa 8 · Split + Montagem (consolidado)
**Renderer:** `RENDERERS.t_split` (5140).

Coração do fluxo. Coleta todo o programa.

- Select `split.tipo` (`SPLITS`: full_body, upper_lower, ABC, ABCD, PPL, ABCDE).
  Ao mudar oferece confirmação de reset da estrutura (`setSplit`, 5255).
- Lista de treinos em **accordion** (`_renderTreinoAccordion`, 5199).
  Cada card mostra nome, grupos, dia, volume/exercícios/séries.

**Ações no card do treino:**
- Editar nome → inline.
- Editar dia → inline.
- Editar grupos → `editGruposTreino(id)` (5317) via `prompt()`.
- Remover treino → `removeTreino(id)`.
- Adicionar exercício → autocomplete inline
  (`searchExercicioParaTreino`, 5245) → clicar num resultado chama
  `addExercicio(id)` (5440) que anexa item com defaults
  `{series:3, reps:'10-12', carga:20, descanso:60, tecnica:'normal'}`.
- Botão **IA** — `iaSugerirExerciciosParaTreino(treinoId)` (5251) →
  heurística: 1 composto + 1 isolado por grupo muscular do treino,
  parâmetros por fase e nível.

**Itens de exercício** (`renderExItem`, 5392):
- Nome do exercício + tag do grupo primário.
- Inputs inline: séries, reps (texto: "8-12"), carga (kg), descanso (s),
  técnica (select).
- **Alerta de lesão** (`alertaLesao`, 5406) — cross-check com lesões
  cadastradas (ombro, joelho, lombar).
- Remover → `removeExItem(tId, i)` (5425).

**Rodapé do treino:** volume total (`calcVolumeTreino`, 4526), n
exercícios, n séries.

**Rodapé geral do split:** botão gigante **"Publicar programa →"** →
`publicarProgramaTreino()` (5594).

Nota (linha 5189): "Revisão foi removida — profissional já conferiu tudo".
Publica direto do t_split, pulando t_revisao/t_validacao/t_atribuicao.

### Etapas ocultas 9-12
Existem apenas para compatibilidade e deep-link:

- **t_montagem** (`RENDERERS.t_montagem`, 5329) — versão anterior do split
  com tabs + autocomplete global (não accordion). Substituída pelo t_split
  atual.
- **t_revisao** (`RENDERERS.t_revisao`, 5480) — botão "Processar revisão
  agora" chama `processarRevisaoTreino()` (5608) → **mock de IA local**
  (setTimeout 800ms + `_gerarAvaliacaoIATreino()`, 5635). Gera texto
  estruturado (ANÁLISE, BALANCEAMENTO, ADEQUAÇÃO AO OBJETIVO,
  RECOMENDAÇÕES, PRÓXIMOS PASSOS). Cross-check com `FAIXAS` por objetivo
  (10-20 séries/grupo/semana para hipertrofia, etc.).
- **t_validacao** (`RENDERERS.t_validacao`, 5813) — roda `tRunValidations`
  (5743). Cartões OK/warn/err por categoria (Completude, Lesões,
  Distribuição, Composição, Volume). Warnings críticos exigem
  justificativa (`tSetJustify`, 5829).
- **t_atribuicao** (`RENDERERS.t_atribuicao`, 5841) — preview mobile do
  aluno com 2 primeiros treinos, toggles WhatsApp/Email/Notificação,
  `dataInicio`, botão publicar.

### Etapa 13 (oculta) · Sucesso
**Renderer:** `RENDERERS.t_sucesso` (5866).

- Ícone ✓ + mensagem.
- CTA "Salvar em {paciente}" (se contexto) → `salvarInstrumentoNoPaciente`.
- CTA "Novo programa" → `reset()`.

---

## 6. WIZARD Prescrição

**Registro:** `FLUXOS[2]` (linha 2340). **Steps:** `STEPS_RX` (2306-2319):
`rx_inicio → rx_paciente → rx_itens → rx_revisao → rx_emissao → rx_sucesso`.

Todas as telas em `#screen-rx_*`.

**Entry:**
- Standalone: `rx_inicio`.
- Contexto de paciente: `rx_itens` (`_WIZARD_START_EM_CONTEXTO.prescricao = 'rx_itens'`, linha 8984).

### Etapa 1 · Início
**Renderer:** `RENDERERS.rx_inicio` (12790–12806).

- Título: "Novo Atendimento — Prescrição · Etapa 1 de 6".
- 3 tipos (buttons/cards): `inicial | renovacao | ajuste`.
- Date `data`.
- Nav: "Continuar →" habilita quando tipo escolhido.

### Etapa 2 · Dados do Paciente
**Renderer:** `RENDERERS.rx_paciente` (12808–12814).

Grid 2×2:
- `nome`* (text)
- `cpf` (text)
- `idade` (number)
- `sexo` (radio F/M)
- `peso` (kg)
- `altura` (cm)
- `alergias` (CSV textarea → array)

Nav habilita se `nome` preenchido.

### Etapa 3 · Itens da Prescrição
**Renderer:** `RENDERERS.rx_itens` (12832–12848).

Grid de **10 botões de tipo de produto** (`RX_TIPOS_PRODUTO`, 12818):
Medicamento, Suplemento, Fitoterápico, Nutraceutico, Probiótico,
Hormônio, Peptídeo, Cannabis, Homeopatia, Injetável.

+ **Botão "Fórmula manipulada"** — abre busca em `state.cadastros.formulas`.

Cada botão chama `rxAddItem(tipo, categoria)` (12862):
1. Cria item stub `{tipo, categoria, ref_id:null, ref_nome:'', dose,
   frequencia, horario, duracao, obs}`.
2. Chama `rxAbrirBuscaItem(idx)` (12875) → abre modal "Buscar
   <categoria> (ANVISA)" com input + `#rxSearchResults`.

**Modal de busca:**
- Input dispara `rxSearchExec(i, q)` (12890) → `AutonDB.buscarProdutos(q,
  {limit:30, categoria})` (LIKE no SQLite).
- Fórmulas: filtra `state.cadastros.formulas` in-memory.
- Clique no resultado → `rxSelecionarRef(i, id, nome)` (12917) → grava
  `ref_id` + `ref_nome`, fecha modal.

**Lista de itens adicionados** (`rxItemHtml`, 12850):
- Ordem, nome do produto/fórmula.
- 4 inputs inline: **Dose**, **Frequência**, **Horário**, **Duração**
  (texto livre).
- Input `Observações`.
- Botão × remover.

**Textarea `observacoes`** geral no rodapé.

Nav habilita quando `itens.length > 0`.

### Etapa 4 · Revisão Clínica
**Renderer:** `RENDERERS.rx_revisao` (12926–12939).

Snapshot readonly:
- Dados do paciente.
- **Tag warning** se `alergias` populadas.
- Tabela `#/Item/Dose/Frequência/Duração`.
- Observações gerais.

### Etapa 5 · Emissão
**Renderer:** `RENDERERS.rx_emissao` (12941–12946).

Card único. Botão gigante **"Emitir Prescrição →"** → `rxEmitir()`
(12947):
- Gera `state.rx.numero = 'RX-' + Date.now()`.
- `state.rx.dataEmissao = ISO`.
- Navega para `rx_sucesso`.

**Não gera PDF nem imprime.**

### Etapa 6 · Sucesso
**Renderer:** `RENDERERS.rx_sucesso` (12954–12963).

- Mostra número + data.
- Actions: **Imprimir** (`toast('em breve')`), **Enviar email** (`toast`),
  **Nova prescrição** (`rxNova()` → reset + volta ao rx_inicio), **Salvar
  em {paciente}** (se contexto).

---

## 7. WIZARD Solicitação de Exames

**Steps:** `STEPS_EX` (2322-2334):
`ex_inicio → ex_paciente → ex_selecao → ex_revisao → ex_solicitacao → ex_sucesso`.

**Entry:**
- Standalone: `ex_inicio`.
- Contexto: `ex_selecao`.

### Etapa 1 · Contexto
**Renderer:** `RENDERERS.ex_inicio` (12977–12994).

- Título: "Novo Atendimento — Exames · Etapa 1 de 6".
- 3 choices: `inicial` (Check-up), `seguimento`, `urgencia`.
- Ação: `exSetTipo(t)`.

### Etapa 2 · Dados do Paciente
**Renderer:** `RENDERERS.ex_paciente` (12996–13002).

- Grid 2×2: nome*, cpf, idade, sexo.
- Checkbox **"Paciente pode fazer jejum de 8h"** → `state.ex.paciente.jejum`.

### Etapa 3 · Seleção de Exames
**Renderer:** `RENDERERS.ex_selecao` (13004–13068).

Duas formas de adicionar:
- **Botão "+ Adicionar exame"** → `exAbrirBusca()` → modal "Buscar Exame
  (LOINC + SIGTAP)" (13022) com input `exSearchInputRx`.
  - `exSearchExec(q)` → `AutonDB.buscarExames(q, {limit:40})` (fallback: filtro local).
  - Clique → `exSelecionarExame(id, nome)` (13047) → push em
    `state.ex.exames`, dedup por `exameId`.
- **Select "Aplicar modelo…"** → `exAplicarModelo(id)` (13056) → achata
  `m.grupos[].exames[]`, merge dedup.

**Lista de itens** (`.ex-item`):
- Ordem, nome, badge `obrigatório | opcional`.
- Botão toggle obrigatório (`exToggleObrig`, 13054).
- Botão × (`exRemoveExame`, 13055).
- Input `Observação` por exame.

**Textarea `observacoes`** geral.

### Etapa 4 · Revisão
**Renderer:** `RENDERERS.ex_revisao` (13070–13081).

- Card paciente (nome, idade, sexo, jejum sim/não).
- Card "Exames solicitados (N)" — tabela.
- Card "Observações gerais" (se preenchida).

### Etapa 5 · Emissão
**Renderer:** `RENDERERS.ex_solicitacao` (13083–13094).

Botão gigante **"Emitir Solicitação →"** → `exSolicitar()` (13089):
- `state.ex.numero = 'EX-' + Date.now().slice(-8)`.
- `state.ex.dataEmissao = ISO`.
- Navega para `ex_sucesso`.

### Etapa 6 · Sucesso
**Renderer:** `RENDERERS.ex_sucesso` (13096–13115).

Mesmos padrões do rx_sucesso: número, data, botões (Salvar/Imprimir/Enviar/Nova).

---

## 8. CADASTROS

**Rota:** `cadastros` · **Renderer:** `RENDERERS.cadastros` (10124–10156).

Layout: barra de top-tabs (4 domínios), painel de sub-tabs (3 níveis
cada), área de conteúdo `#cadastroSubContent`.

**Registro:** `CADASTRO_TABS` (linhas 8736–8772):

```js
CADASTRO_TABS = {
  alimentacao: { top: 'Alimentação', subs: [
    { key:'alimentos',           renderer:'cadastroAlimentos',           nivel:'Nível 1 · Atoms' },
    { key:'refeicoes',           renderer:'cadastroRefeicoes',           nivel:'Nível 2 · Compostos' },
    { key:'templates_plano',     renderer:'cadastroTemplatesPlano',      nivel:'Nível 3 · Templates' },
  ]},
  treino: { top: 'Treino', subs: [
    { key:'exercicios',          renderer:'cadastroExercicios',          nivel:'Nível 1 · Atoms' },
    { key:'treinos',             renderer:'cadastroTreinos',             nivel:'Nível 2 · Compostos' },
    { key:'templates_programa',  renderer:'cadastroTemplatesPrograma',   nivel:'Nível 3 · Templates' },
  ]},
  prescricao: { top: 'Prescrição', subs: [
    { key:'produtos',            renderer:'cadastroProdutos',            nivel:'Nível 1 · Atoms' },
    { key:'formulas',            renderer:'cadastroFormulas',            nivel:'Nível 2 · Compostos' },
    { key:'templates_prescricao',renderer:'cadastroTemplatesPrescricao', nivel:'Nível 3 · Templates' },
  ]},
  exames: { top: 'Exames', subs: [
    { key:'exames_lista',        renderer:'cadastroExames',              nivel:'Nível 1 · Atoms' },
    { key:'modelos_exames',      renderer:'cadastroModelosExames',       nivel:'Nível 3 · Templates' },
  ]},  // ← só 2 sub-tabs (não há Nível 2 Painel)
}
```

**Framework de cadastro:** `setCadastroTop(k)` (10157),
`setCadastroSub(k)` (10163), `filterCadastro(q)` (8724),
`crudHeader(...)` (8714).

**Ver / Editar / Duplicar / Excluir** são padrão em todas as tabelas via
o helper `crudHeader`. Fonte dupla (SQLite + localStorage) via
`all<Tipo>()` (linhas 6417–6486).

---

### 8.1. Alimentação → Alimentos

**Renderer:** `RENDERERS.cadastroAlimentos` (10171–10207).

**Fonte:** dupla — `AutonDB.buscarAlimentos()` (SQLite, prioritária) ou
`state.cadastros.alimentos` (fallback). Cache 5s, hard-limit 500 linhas.

**Colunas:** Nome · Grupo · Medida caseira · kcal/100g · P · C · G ·
Fibra · Na · Ações.

**Filtro por grupo:** dropdown `alimGrupoSel` (`setGrupoAlimentoFiltro`,
10208) — usa `AutonDB.gruposAlimentos()`.

**CRUD:**
- `novoAlimento()` (10224) — abre modal com `alimentoEditorHtml` (10214).
- `editAlimento(id)` (10229).
- `salvarAlimento(id)` (10235).
- `duplicarAlimento(id)` (10260) — clona para cadastro pessoal.
- `excluirAlimento(id)` (10271) — só se for pessoal.

**Editor:** campos: nome, grupo, kcal, P/C/G/100g, porção padrão + medida
caseira, checkboxes de alergenos (glúten, leite, ovos, peixe, amendoim,
castanhas, soja).

**Mapa MEDIDAS_CASEIRAS** (linha 10425+) — dicionário `taco_N → {q, u, g}`
para conversão porção↔gramas.

---

### 8.2. Alimentação → Refeições-modelo

**Renderer:** `RENDERERS.cadastroRefeicoes` (10280–10297).

**Fonte:** `state.cadastros.refeicoes_modelo` (seed `REFEICOES_MODELO_SEED`).

**Colunas:** Nome · Categoria · nº alimentos · kcal · P · C · G · Ações.

**Categorias:** `cafe | lanche | almoco | jantar | ceia | pre_treino | pos_treino`.

**Cálculos:** `calcularRefeicao()` deriva perfil nutricional.

**CRUD:**
- `verRefeicaoModelo(id)` (10298) — modal com header + tabela detalhada por
  item + badges de perfil.
- `novoRefeicaoModelo()` (10331).
- `editRefeicaoModelo(id)` (10336) — editor só de cabeçalho (nome +
  categoria). Itens são editados quando a refeição é usada num plano.
- `salvarRefeicaoModelo(id)` (10342).
- `duplicarRefeicaoModelo(id)` (10362).
- `excluirRefeicaoModelo(id)` (10373).

---

### 8.3. Alimentação → Templates de Plano

**Renderer:** `RENDERERS.cadastroTemplatesPlano` (10382–10396).

**Fonte:** `state.cadastros.templates_plano` (seed `TEMPLATES_PLANO_SEED`).

**Colunas:** Nome · Objetivo · VET · Macros · nº refeições · Ações.

**CRUD:**
- `verTemplatePlano(id)` (11068) — modal grande com header (VET, macros,
  objetivo), `<details>` expansíveis por refeição, `observacao` renderizada
  como markdown clínico (`renderMarkdownClinico`, 10399).
- `novoTemplatePlano()` (11148).
- `editTemplatePlano(id)` (11153).
- `salvarTemplatePlano(id)` (11159).
- `duplicarTemplatePlano(id)` (11186).
- `excluirTemplatePlano(id)` (11197).

**Editor** (`templatePlanoEditorHtml`, 11143):
- Text `nome`, select `objetivo`, number `VET`.
- Numerics `macros.p`, `macros.c`, `macros.g`.
- **Multi-select** `refeicoesModeloIds` (checkboxes das refeições cadastradas).
- Textarea `observacao` (markdown).

---

### 8.4. Treino → Exercícios

**Renderer:** `RENDERERS.cadastroExercicios` (11206–11219).

**Fonte:** `state.cadastros.exercicios` (873 items via `__carregarExerciciosFreeDB`).

**Colunas:** Thumb (imagem CDN) · Nome · Grupos · Padrão · Equipamento ·
Nível · Tipo · Ações.

**Editor** (`exercicioEditorHtml`, 11220):
- Nome, grupo primário (select GRUPOS_MUSCULARES — 10 opções).
- Padrão (8 opções: empurrar/puxar horizontal/vertical, agachar, dobrar,
  rotacionar, estabilizar).
- Equipamento (12 opções).
- Nível, tipo.
- **Galeria de imagens + instruções** (read-only, vêm do freedb).

**Limitação do editor atual:** só permite 1 grupo primário e 1 equipamento
mesmo que o modelo suporte arrays.

**CRUD:**
- `novoExercicio` (11238) · `editExercicio(id)` (11242) · `salvarExercicio(id)`
  (11247) · `duplicarExercicio(id)` (11261) · `excluirExercicio(id)` (11266).

---

### 8.5. Treino → Treinos-modelo

**Renderer:** `RENDERERS.cadastroTreinos` (11273–11284).

**Fonte:** `state.cadastros.treinos_modelo` (seed
`data/seeds/treinos_modelo.json`, 20 treinos curados).

**Colunas:** Nome · Grupos · Nível · Nº Exercícios · Ações.

**CRUD:**
- `verTreinoModelo(id)` (11285) — modal com tabela `#/Exercício/Séries/Reps/Carga/Descanso`.
- `novoTreinoModelo` (11299) · `editTreinoModelo(id)` (11303) · `salvarTreinoModelo(id)`
  (11308) · `duplicarTreinoModelo` (11319) · `excluirTreinoModelo` (11324).

**Editor** (`treinoModeloEditorHtml`, 11292):
- Nome, nivel.
- Checkboxes de grupos musculares.
- Comentário no editor: "Após salvar, adicione exercícios editando
  individualmente ou usando este treino-modelo dentro de um programa".

**Modelo do item:** `{ id:'tm_xxx', nome, nivel, grupos:[], itens:[{exercicioId, series, reps, carga, descanso}] }`.

---

### 8.6. Treino → Templates de Programa

**Renderer:** `RENDERERS.cadastroTemplatesPrograma` (11334–11345).

**Fonte:** `state.cadastros.templates_programa` (seed
`data/seeds/templates_programa.json`, 16 templates).

**Colunas:** Nome · Objetivo · Fase · Duração · Nível · Split · Nº Treinos.

**CRUD:**
- `verTemplatePrograma(id)` (11404) — modal com meta + tabela expansível
  em dois níveis:
  - Accordion `toggleTreinoInline` (11388) — abre o treino-modelo.
  - Accordion `toggleExercicioInline` (11369) — abre o detalhe do
    exercício (imagens + instruções freedb via `_exercicioDetalheHtml`,
    11346).
  - Alerta se `treinosModeloIds` aponta para IDs inexistentes.
- `novoTemplatePrograma` (11419) · `editTemplatePrograma(id)` (11423) ·
  `salvarTemplatePrograma(id)` (11428).

**Editor** (`templatePrgEditorHtml`, 11414):
- Nome, objetivo (OBJETIVOS_LABELS_PT).
- Fase (FASES_LABELS), duracao_semanas, nivel.
- Split (SPLITS_LABELS).
- **Multi-select** `treinosModeloIds`.
- Textarea `observacao` (markdown).

---

### 8.7. Prescrição → Produtos

**Renderer:** `RENDERERS.cadastroProdutos` (11460–11498).

**Fonte:** dupla — `AutonDB` (prioritária, 53k produtos) ou
`PRODUTOS_SEED` (~137 curados). Cache 5s, hard-limit 500.

**Colunas:** Nome · Categoria (tag colorida via `categoriaTag`) ·
Fabricante · Detalhe (`detalheProdutoResumido`, 11509) · Ações.

**Filtro:** dropdown `prodCatSel` (`setCategoriaFiltro`, 11508). Total
por categoria via `countProdutosCategoria`.

**Painel de provenance:** `renderProvenancePanel` (11499) — mostra fonte
e cross-walk IDs de cada produto.

**Editor de Produto** (`produtoEditorHtml`, 11591):

Estrutura de **4 blocos empilhados** (não são abas):

- **Bloco 1 · IDENTIDADE** (11603):
  - `pd_categoria` — select (`disabled` quando não é novo).
  - `pd_nome`* — text.
  - Campos dinâmicos por categoria (`SCHEMAS_PRESCRICAO[categoria]`).

- **Bloco 2 · CLÍNICA** (11611):
  - `classe_terapeutica`, `registro_anvisa`, `tarja`, `fonte`.

- **Bloco 3 · SEGURANÇA E ADMINISTRAÇÃO** (11616):
  - Checkboxes: `jejum`, `apos_refeicao`, `antes_refeicao`, `evitar_alcool`.
  - Textarea `obs_livre`.

- **Bloco 4 · CÓDIGOS AVANÇADOS** — `<details>` accordion (11622):
  - `codigo_atc`, `codigo_dcb`, `codigo_unii`, `codigo_rxcui`,
    `codigo_ean13`, `codigo_chebi`, `pubchem_cid`, `codigo_loinc`.

- **Painel MARCAS COMERCIAIS** — só se `marcas_count && marcas`. Card
  com contagem + preview das 8 primeiras marcas. Não editável.

**Visualizador** (`verProduto`, 11543) usa helper `val(v)` (11548) para
**esconder campos vazios** e nunca mostrar "—". Organiza em 3 seções via
`secao()`. `interopRows = CAMPOS_INTEROP.filter(f => val(p[f.key]))` —
só mostra códigos preenchidos.

**CRUD:**
- `novoProduto()` (11631), `editProduto(id)` (11635), `salvarProduto(id)`
  (11642) — usa `setIfValue` para não poluir com strings vazias.
- `duplicarProduto(id)` (11669) — sempre para cadastro pessoal.
- `excluirProduto(id)` (11679) — só pessoal.

---

### 8.8. Prescrição → Fórmulas Manipuladas

**Renderer:** `RENDERERS.cadastroFormulas` (11689–11700).

**Fonte:** `state.cadastros.formulas` — **seed vazio** (`FORMULAS_SEED = []`,
linha 3034). Comentário: "zerado. Vamos recomeçar com nova estratégia".

**Colunas:** Nome · Forma (badge) · Nº Componentes · Posologia · Ações.

**CRUD:**
- `verFormula(id)` (11701) · `novoFormula()` (11779) · `editFormula(id)`
  (11783) · `salvarFormula(id)` (11788) · `duplicarFormula(id)` (11814) ·
  `excluirFormula(id)` (11819).

**Editor** (`formulaEditorHtml`, 11715):

- **Cabeçalho:** `fm_nome`*, `fm_tipo` (select: cápsula/sachê/solução/
  pomada/creme/xarope/gel), `fm_duracao`, `fm_posologia`, `fm_obs`.

- **Lista de componentes** (`#fm_componentes` + botão "+ Adicionar
  componente"):

  Cada linha (`componenteRowHtml`, 11725):
  - **Produto/Ativo** — input `.fm_cmp_nome` + hidden `.fm_cmp_pid`.
    - `oninput`/`onfocus` → `buscarProdutoParaComponente(inputEl, idx)`
      (11743): autocomplete via `AutonDB.buscarProdutos(q, {limit:8})`.
    - Clique num resultado → `selecionarProdutoComponente(prod, idx)`
      (11757): preenche `pid`, `nome`, **auto-fill de dose com
      `prod.concentracao`** se dose vazia, atualiza badge "vinculado ao
      catálogo".
  - **Dose** — input placeholder "ex: 400 mg".
  - **Observação** — input.
  - Botão × remove o card.
  - Badge de vínculo: verde ("vinculado ao produto do catálogo") ou
    cinza ("ativo em texto livre").

- **Regra de desvincular ao editar** (11768): listener global — se
  usuário mudar `.fm_cmp_nome` após vincular, zera `pid` e badge volta
  para "ativo em texto livre".

- **`salvarFormula`** (11788): exige `nome` + ≥1 componente. Cada
  componente é serializado como
  `{produto_id, produto_nome, nome, dose, obs}`.

**Não há cálculo automático de quantidades totais.**

---

### 8.9. Prescrição → Templates de Prescrição

**Renderer:** `RENDERERS.cadastroTemplatesPrescricao` (11835–11864).

**Fonte:** `state.cadastros.templates_prescricao` — **seed vazio**
(linha 3037). Filtros por `GRUPOS_CLINICOS_TP` (também vazio, linha 3038).

**Colunas:** Nome · Grupo clínico · Condição-alvo · Nº Ativos · Nº Fases ·
Nº Exames de acompanhamento · Ações.

**Editor** (`templatePrescricaoEditorHtml`, 12076) — 6 seções:

1. **Identificação** — nome, grupo_clinico, condicao_alvo.
2. **Prescrição base** — ativos_sugeridos (CSV/quebras de linha),
   posologia base.
3. **Campos específicos** — grid dinâmico via `[data-esp]` — sugerido
   pelo `_renderCampoEspecifico` (11965) por regex do key.
4. **Segurança** — contraindicações, interações, monitoramento.
5. **Acompanhamento** — exames_acompanhamento[], protocolo_fases[].
6. **Observações** — textarea markdown.

**Constantes de opções:** `OPCOES_FORMA_FARMACEUTICA`, `OPCOES_UNIDADE`,
`OPCOES_FREQUENCIA`, `OPCOES_VIA`, `OPCOES_ASSOCIACAO_REFEICOES`,
`OPCOES_NIVEL_EVIDENCIA` (11951–11961).

**CRUD:**
- `verTemplatePrescricao(id)` (11865) — suporta 2 formatos: legado
  (`t.itens[]` com posologia) e novo (`ativos_sugeridos[]` +
  `protocolo_fases[]` + `exames_acompanhamento[]`).
- `novoTemplatePrescricao()` (12113) · `editTemplatePrescricao(id)`
  (12117) · `salvarTemplatePrescricao(id)` (12122) — coleta 23+ campos.
- `duplicarTemplatePrescricao(id)` (12196) · `excluirTemplatePrescricao(id)` (12201).

---

### 8.10. Exames → Exames

**Renderer:** `RENDERERS.cadastroExames` (12215–12249).

**Fonte:** dupla — `AutonDB.buscarExames()` (98k) ou fallback local
(seed `EXAMES_SEED`, 186 exames curados).

**Filtros:** categoria (24 opções em `CATEGORIAS_EXAME`, 3043), tipo
(`individual | painel | composto`), status.

**Colunas:** Nome (+sinônimos) · Sigla · Categoria (tag colorida) ·
Material · Tipo · Resultado · Status · Ações.

**Total:** via `countExamesCategoria(cat)` (6471) cacheado.

**Editor** (`exameEditorHtml`, 12280) — 5 blocos:

1. **Informações principais** — nome*, sigla, sinônimos (CSV),
   categoria*, subcategoria (depende), tipo_exame*, status, descrição.

2. **Coleta e preparo** (details) — material (select 21 opções),
   horário preferencial, jejum (checkbox + horas), restrições,
   orientação ao paciente, observação profissional.

3. **Resultado** — tipo_resultado* (select `TIPOS_RESULTADO`, 11 opções,
   trigger re-render). Condicionais:
   - Se numérico: unidade + casas decimais.
   - Se `lista_opcoes`: opções (CSV).

4. **Componentes** (só se `tipo_resultado === 'composto'`) —
   `renderComponentesBlock` (12310): lista dinâmica de linhas com ordem,
   nome, sigla, tipo_resultado, unidade, min, max.

5. **Valores de referência** (opcional, details) — lista dinâmica com
   faixa, sexo (`ambos | M | F`), idade min/max, min, max, unidade, obs.

**LOINC/TUSS/CBHPM:** **não expostos no editor manual** — apenas
preenchidos via `importarDoCatalogoOficial` (2238–2240).

**CRUD:**
- `verExame(id)` (12251), `novoExame()` (12377), `editExame(id)` (12381),
  `salvarExame(id)` (12388), `duplicarExame(id)` (12401),
  `arquivarExame(id)` (12410) — arquiva se em uso por modelo, remove
  senão.

---

### 8.11. Exames → Modelos de Solicitação

**Renderer:** `RENDERERS.cadastroModelosExames` (12427–12441).

**Fonte:** `state.cadastros.modelos_exames` (seed 44 modelos).

**Colunas:** Nome · Categoria · Especialidade · Nº Grupos · Nº Exames ·
Visibilidade · Ações.

**Editor** (`modeloExamesEditorHtml`, 12515) — meta + grupos:

**Meta:**
- Nome*, categoria (texto livre), especialidade, objetivo (textarea),
  descrição (textarea), tags (CSV).
- Select visibilidade: `privado | compartilhado com a equipe | padrão do
  sistema`.

**Grupos** (`#me_grupos` + botão "+ Adicionar grupo"):

Cada grupo (`grupoModeloHtml`, 12524):
- Header: rótulo "Grupo N" + input nome + botão remover.
- Container `.me_exames_container` com linhas de exame.
- Row de adição: `<select class="me_add_exame_select">` populado com
  **`allExames().filter(e => e.status === 'ativo')`** (12528) — select
  HTML nativo sem autocomplete real. Formato:
  `{nome} ({sigla}) · {categoria label}`.
- Botão "Adicionar" → `addExameAoGrupo(btn)` (12542).

Cada linha de exame no grupo (`exameModeloRowHtml`, 12531):
- Checkbox "obrigatório" (default true).
- Nome + sigla + tag de categoria.
- Input `Observação clínica`.
- Botão ×.

**Ordenação implícita pelo DOM.** Sem drag-and-drop.

**`salvarModeloExames(id)`** (12562): extrai `grupos[].exames[]` do DOM,
valida (nome + ≥1 grupo), salva.

**Visualização** `verModeloExames(id)` (12443–12513) — CSS embutido,
`.mv-grid { columns: 3 }`, cada grupo lista exames obrigatórios (○) e
opcionais (badge "opc"), obs em itálico.

**Ver / Novo / Editar / Duplicar / Excluir** presentes.

---

## 9. Painel Catálogo Oficial

**Renderer:** `renderPainelCatalogoOficial(tipo)` (linhas 2138–2172).

Painel de busca full-text no SQLite embutido em várias telas de cadastro
(Produtos e Exames). Componentes:
- Input `#catOficialSearch_<tipo>` — digitação dispara
  `buscarNoCatalogoOficial(tipo, q)` (2176).
- Área `#catOficialResults_<tipo>` — tabela de até 50 resultados.
- Cada linha: nome + botão **"⇩ Importar"** →
  `importarDoCatalogoOficial(tipo, id)` (2195): copia registro do SQLite
  para `state.cadastros.<tipo>`, marca `_importado_do_catalogo_em`,
  evita duplicatas.

Renderer suporta 2 tipos: `produtos` e `exames`. Chamado
`renderResultadosCatalogoOficial(tipo)` (2157) para redraw.

---

## 10. Modais globais

### 10.1. `openModal(title, body, footer)` (8708)
Utility genérico. Insere em `#modalRoot`. Backdrop `.modal-backdrop` com
`backdrop-filter: blur(6px)`. `closeModal()` (8712).

### 10.2. Modais específicos do domínio

**Alimentação:**
- **Escolher template · Plano Alimentar** — `abrirTemplateModal` (7264).
  Filtra por objetivo, cards clicáveis com macros/ajuste/nº refeições.
- **Detalhe Refeição-modelo** — `verRefeicaoModelo` (10298).
- **Editor Alimento** — `novoAlimento` / `editAlimento`.
- **Editor Refeição-modelo** — `novoRefeicaoModelo` / `editRefeicaoModelo`.
- **Detalhe Template de Plano** — `verTemplatePlano` (11068).
- **Editor Template de Plano** — via `templatePlanoEditorHtml`.

**Treino:**
- **Escolher template · Programa** — `abrirTemplateTreinoModal` (4800).
  Cards com badges (objetivo/split/nível/semanas/#treinos), ranqueados
  por `_scoreTemplateParaAluno` (4619), badge "Recomendado" para score ≥ 30.
- **Editor Exercício** — `novoExercicio` / `editExercicio`.
- **Ver Treino-modelo** — `verTreinoModelo`.
- **Editor Treino-modelo** — `novoTreinoModelo` / `editTreinoModelo`.
- **Ver Template de Programa** — `verTemplatePrograma`.
- **Editor Template de Programa** — via `templatePrgEditorHtml`.

**Prescrição:**
- **Buscar produto/fórmula** — dentro do wizard rx_itens, aberto por
  `rxAbrirBuscaItem`.
- **Editor Produto** (4 blocos + accordion).
- **Editor Fórmula** (componentes com autocomplete).
- **Editor Template de Prescrição** (6 seções).

**Exames:**
- **Buscar exame** — dentro do wizard ex_selecao, aberto por `exAbrirBusca`.
- **Editor Exame** (5 blocos).
- **Ver Modelo de Solicitação** (grid 3 colunas).
- **Editor Modelo** (meta + grupos).

**Paciente/Ficha:**
- **Ficha Técnica** — `abrirFichaModal('view' | 'edit')` (9197). Único
  modal que abre sobre um wizard em andamento.

### 10.3. Prompts nativos usados
Alguns fluxos usam `window.prompt()` em vez de modais:
- `addLesaoPrompt()` — 4 prompts sequenciais (região, quando, status,
  observação).
- `editGruposTreino(id)` — 1 prompt com lista.
- `a_addAlergia()` — prompt para gravidade.
- `editItem()` (montagem de refeição) — prompt para gramas.

### 10.4. Toast
`toast(msg, ms = 2500)` (7125) — set `#toast.textContent` + classe
`.show` por N ms.

---

## Notas de dívida técnica identificadas

- **Sidebar sem "Sair"** — README menciona, HTML não tem. `reset()` só é
  chamado nas telas de sucesso.
- **"Novo paciente" é stub** — sem UI de cadastro.
- **Impressão / PDF / Email** — todos os botões em rx_sucesso, ex_sucesso
  e a tela de sucesso do plano são `toast('em breve')`.
- **Aba "Evolução Fotográfica"** — placeholder.
- **Search bar da topbar** — placeholder, sem lógica.
- **Instrumento não guarda conteúdo** — ver `resumo`. Reabrir para editar
  não é possível.
- **Deep-link URL não funciona** — apesar de `href="#..."`, o handler
  `event.preventDefault()` cancela. `location.hash` não é lido.
- **Renderers duplicados** — `cadastroExercicios`, `cadastroTreinos`,
  `cadastroTemplatesPrograma` definidos duas vezes (a segunda sobrescreve).
- **FTS5 tabelas populadas mas não usadas** — busca usa LIKE puro.
- **`escapeFTS()` definida e nunca chamada** — intenção futura morta.
- **1RM Epley definido mas não invocado** — apenas menções educativas em
  texto.
- **Fórmulas e Templates de Prescrição seed vazio** — "recomeçando".
- **`GRUPOS_CLINICOS_TP` vazio** — filtro de templates de prescrição não
  aparece.
- **Steps de treino ocultos** — 6 de 13 estão com `display: none`.
- **State legado coexiste** — `state.paciente/anamnese/avaliacao/...`
  (raiz) coexiste com `state.pacientes[]` (modelo ontológico novo).
