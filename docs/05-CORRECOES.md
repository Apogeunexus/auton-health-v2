# 05 · Correções — Composição Ontológica dos Cadastros

> **Problema-raiz:** os editores dos Níveis 2 e 3 dos 4 domínios não
> respeitam a ontologia. Regra que precisa valer em todos:
>
> **Cada Nível N precisa ter UI para selecionar itens do Nível N−1 —
> e preservar 100% dos metadados que o schema já suporta.**
>
> Hoje isso só acontece corretamente em **Prescrição → Fórmula**. Os
> outros editores ou coletam só o cabeçalho, ou usam `<select multiple>`
> HTML nativo, ou **destroem metadados clínicos ricos** ao editar
> templates populados por seeds.
>
> Este documento é o **plano de correção**. Nada é código pronto — são
> instruções para o dev implementar. A maior parte das mudanças é
> UI-only; algumas exigem evolução do schema com migration (agenda
> semanal/diária, ver §5).

---

## Sumário

- [1. Diagnóstico — matriz atual](#1-diagnóstico--matriz-atual-4-domínios--3-níveis)
- [2. Bloqueadores prévios (fazer PRIMEIRO)](#2-bloqueadores-prévios-fazer-primeiro)
- [3. Padrão de referência — Fórmula](#3-padrão-de-referência--editor-de-fórmula-manipulada)
- [4. Instruções por editor — Níveis 2](#4-instruções-por-editor--níveis-2-composição-de-itens)
- [5. Instruções por editor — Níveis 3](#5-instruções-por-editor--níveis-3-templates-com-agenda-e-metadados)
- [6. Integridade referencial](#6-integridade-referencial-cross-cadastro)
- [7. Padronização visual](#7-padronização-visual)
- [8. Discussão ontológica pendente](#8-discussão-ontológica-pendente)
- [9. Ordem final de implementação](#9-ordem-final-de-implementação)
- [10. Checklist de aceitação](#10-checklist-de-aceitação-por-editor)

---

## 1. Diagnóstico — matriz atual (4 domínios × 3 níveis)

| Domínio | Nível 1 · Átomo | Nível 2 · Composto | Nível 3 · Template |
|---|---|---|---|
| **Alimentação** | Alimento — CRUD ✅ | Refeição-modelo — ❌ **só cabeçalho** | Template de Plano — 🔴 **múltiplos problemas** (ver §5.1) |
| **Treino** | Exercício — CRUD ✅ | Treino-modelo — ❌ **só cabeçalho** | Template de Programa — 🔴 **lista solta em vez de agenda semanal** |
| **Prescrição** | Produto — CRUD ✅ | Fórmula — ✅ **CORRETO** (padrão de referência) | Template de Prescrição — N/A (é template textual, não composição — ver §8.2) |
| **Exames** | Exame — CRUD ✅ | (Painel não existe — ver §8.1) | Modelo de Solicitação — ⚠️ tem grupos, mas `<select>` HTML com 500+ opções |

**Legenda:** ✅ ok · ⚠️ funciona mas UI ruim · 🔴 bug ou perda de dados · ❌ falta composição inteira

**Impacto para o usuário:**
- **Impossível** criar Refeição-modelo ou Treino-modelo funcional pela UI. Só os que vieram no seed têm itens.
- **Editar** um Template de Plano pela UI **destrói metadados clínicos ricos** (categoria, especialidade, tags, markdown estruturado com 12 seções clínicas populado por workflow).
- **Bug do 33+33+33=99** em `aplicarTemplate` (linha 7247) trava validação da Etapa 6 (Estrutura) do wizard de plano — ver §2.2.
- **Renderers duplicados** significam que editar um deles pode não ter efeito (a segunda definição sobrescreve a primeira) — ver §2.1.

---

## 2. Bloqueadores prévios (fazer PRIMEIRO)

Antes de tocar em qualquer editor, resolver esses dois itens — senão
correções serão invisíveis ou introduzirão novos bugs.

### 2.1. Deduplicar renderers

**3 pares confirmados** por grep. Como o JS avalia em ordem, a segunda
sobrescreve a primeira — editar a versão que aparece antes no arquivo
**não tem efeito nenhum**.

| Renderer | Definição 1 (obsoleta, remover) | Definição 2 (canônica, manter) |
|---|---|---|
| `RENDERERS.cadastroExercicios` | [index.html:5906](../index.html#L5906) | [index.html:11211](../index.html#L11211) |
| `RENDERERS.cadastroTreinos` | [index.html:5924](../index.html#L5924) | [index.html:11278](../index.html#L11278) |
| `RENDERERS.cadastroTemplatesPrograma` | [index.html:5941](../index.html#L5941) | [index.html:11339](../index.html#L11339) |

**Ação:** deletar as versões 5906/5924/5941. Verificar (grep) se há
outras funções relacionadas duplicadas (`verTemplatePrograma`,
`treinoModeloEditorHtml`, `templatePrgEditorHtml`, editores de exercício
etc.) — se sim, aplicar o mesmo tratamento.

**Custo:** ~30 min. Ganho: elimina fonte silenciosa de bugs futuros.

### 2.2. Bug crítico em `aplicarTemplate` — distribuição de `pctVet`

**Local:** [index.html:7247](../index.html#L7247).

```js
const pctPorRefeicao = Math.round(100 / refs.length);
```

Distribui uniformemente com arredondamento simples. Resultado:

| N refeições | `Math.round(100/N)` | Total | Problema |
|:-:|:-:|:-:|---|
| 3 | 33 | **99** | Trava `canNext` na Etapa 6 (validação exige 100%) |
| 4 | 25 | 100 | OK |
| 5 | 20 | 100 | OK |
| 6 | 17 | **102** | Estoura |
| 7 | 14 | **98** | Trava |

**Correção:** distribuir com resto para fechar 100 exatamente:

```js
const base = Math.floor(100 / refs.length);
const resto = 100 - (base * refs.length);
// primeiras `resto` refeições ganham +1
refs.forEach((r, i) => r.pctVet = base + (i < resto ? 1 : 0));
```

**Melhor ainda:** template salvar `pctVet` explícito por refeição (§5.1)
para respeitar rateio clínico (ex: café 25% / almoço 40% / jantar 30% /
ceia 5%). Aí não precisa distribuir na aplicação.

**Custo:** 15 min. Ganho: destrava o wizard para templates de 3 ou
6-7 refeições.

---

## 3. Padrão de referência — Editor de Fórmula Manipulada

Este editor **já implementa o padrão ontológico correto** e serve de
referência para todos os outros editores de Nível 2.

**Local:** `index.html` linhas 11715–11794 (função `formulaEditorHtml`).

### 3.1. Estrutura

```
Cabeçalho (nome, tipo farmacêutico, duração, posologia geral, observação)
└── Lista de Componentes (Nível 1 = Produto)
    ├── Linha 1: [autocomplete Produto] [dose] [obs] [×]
    │             └── vinculação com produto_id (hidden)
    │             └── indicador de vínculo (vinculado ao catálogo | texto livre)
    ├── Linha 2: ...
    └── [+ Adicionar componente]
```

### 3.2. Peças-chave a reutilizar

| Função | Linha | O que faz |
|---|---|---|
| `componenteRowHtml(c, i)` | 11725 | Renderiza cada linha de componente com input+dose+obs+botão remover |
| `buscarProdutoParaComponente(inputEl, idx)` | 11743 | Autocomplete via `AutonDB.buscarProdutos(q, {limit:8})` — dropdown flutuante |
| `selecionarProdutoComponente(prod, idx)` | 11757 | Preenche `pid` hidden, nome, auto-fill de dose com `prod.concentracao` |
| Listener de desvincular | 11768 | Se usuário edita o nome depois de vincular → remove o vínculo |
| `addComponente()` | 11737 | Adiciona nova linha vazia |

### 3.3. Regras invioláveis do padrão

1. **Autocomplete sempre que o Nível N−1 for grande** (>50 itens) — nunca `<select>` HTML nativo.
2. **Vinculação por id** — cada linha carrega hidden com `<nivel1>_id`. Preserva referência ao catálogo oficial mesmo quando o nome é editado.
3. **Fallback texto livre** — se o profissional edita o nome depois de vincular, o vínculo cai e vira "item em texto livre". Nunca perde o que foi digitado.
4. **Auto-fill inteligente** — quando vincula, preenche defaults derivados do item (dose = `concentracao`, gramas = medida caseira padrão, séries/reps = últimos usados).
5. **Indicador visual do vínculo** — badge verde ("vinculado ao catálogo") ou cinza ("texto livre").
6. **Contexto isolado** — editor de cadastro NUNCA toca em `state.plano`/`state.treino`/etc. Usa `tm.itens`/`rm.itens` locais.

---

## 4. Instruções por editor — Níveis 2 (composição de itens)

### 4.1. 🍽️ Alimentação → Refeição-modelo

**Editor atual** ([linhas 10331–10346](../index.html#L10331), função `refeicaoModeloEditorHtml`):

```html
<input id="rm_nome">              [OK]
<select id="rm_cat">              [OK]
<div>Após salvar, os itens de alimento serão editáveis
     (feature em desenvolvimento — hoje edita apenas cabeçalho).</div>
```

**Precisa virar:**

```
Cabeçalho: nome, categoria [MANTÉM]
Perfil clínico: chip-input [low-carb, cetogênica, sop, jejum, ...]
                (vocabulário controlado — mesma lista dos templates de plano)

── Alimentos da refeição ──
[+ Adicionar alimento]
Linha por item:
  [autocomplete Alimento] [gramas: 100] [medida caseira: 1 xíc ▾] [obs] [×]
  └── indicadores: vínculo TACO | badge alergeno (se contexto paciente) | kcal calculado

Rodapé (calculado ao vivo):
  Total: N alimentos · X kcal · Pg · Cg · Gg · Fibra g · Sódio mg
```

**Peças a reutilizar:**

- `searchFoodInline(refId, q)` ([7852](../index.html#L7852)) — autocomplete de alimento já usado na Etapa 7 do wizard. **Extrair como componente reutilizável** `_editorAlimentoAutocomplete(contexto, onSelect)` que serve tanto no wizard quanto no cadastro.
- `MEDIDAS_CASEIRAS` ([10425+](../index.html#L10425)) — mapa `taco_N → {q, u, g}` para dropdown de medida caseira.
- `calcularRefeicao(r)` ([11054](../index.html#L11054)) — cálculo agregado.
- `isAlergenoBlocked(alimentoId)` ([7902](../index.html#L7902)) — só ativa no contexto paciente (`state.contextoInstrumento`).

**Regra de contexto:** o cadastro NÃO tem paciente ativo → alergeno-block
não se aplica. Apenas mostra composição bruta do alimento.

**Salvar:**

```js
function salvarRefeicaoModelo(id) {
  const data = {
    nome: v('rm_nome'),
    categoria: v('rm_cat'),
    perfil: [...document.querySelectorAll('.rm_perfil_chip')].map(c => c.dataset.tag),
    itens: [...document.querySelectorAll('.rm_item_row')].map(row => ({
      alimentoId: row.dataset.alimentoId || null,
      alimento_nome: row.querySelector('.rm_item_nome').value,  // snapshot
      gramas: +row.querySelector('.rm_item_gramas').value || 0,
      medidaCaseira: row.querySelector('.rm_item_medida')?.value || null,
      obs: row.querySelector('.rm_item_obs').value,
    })).filter(it => it.alimentoId || it.alimento_nome),
  };
  // ... resto igual
}
```

**Ganho no viewer** `verRefeicaoModelo` ([10298](../index.html#L10298)): já
suporta `t.itens` com cálculo — só passa a ter dados reais.

**Remover:** o `<div class="field-hint">` apologético e o `<div class="ai-panel">` "Este é o cadastro base".

---

### 4.2. 💪 Treino → Treino-modelo

**Editor atual** ([linhas 11297–11322](../index.html#L11297), função `treinoModeloEditorHtml`):

```html
<input id="tm_nome">              [OK]
<select id="tm_nivel">            [OK]
<checkboxes grupos musculares>    [DERIVAR — permitir override]
<div>Após salvar, adicione exercícios editando individualmente...</div>
```

**Precisa virar:**

```
Cabeçalho: nome, nível [MANTÉM]

── Exercícios do treino ──
[+ Adicionar exercício]  [🤖 Sugerir com IA]

Linha por item:
  [autocomplete Exercício]
  [séries: 3] [reps: 8-12] [carga: 20 kg] [descanso: 60s] [técnica ▾] [obs] [×]
  └── indicadores: grupo primário (chip colorido) | thumb da imagem
      | ⚠ lesão (só em contexto paciente)

Rodapé:
  Total: N exercícios · S séries · V kg volume estimado
  Grupos musculares (derivados): [chips]  [override manual ▾]
```

**Peças a reutilizar:**

- `searchExercicioParaTreino(treinoId, value)` ([5245](../index.html#L5245)) — autocomplete da Etapa 8. **Extrair como componente** `_editorExercicioAutocomplete(contexto)`.
- `iaSugerirExerciciosParaTreino(treinoId)` ([5251](../index.html#L5251)) — heurística de composto+isolado por grupo.
- `renderExItem(treinoId, item, idx)` ([5392](../index.html#L5392)) — inputs inline já prontos. **Precisa aceitar `contexto='cadastro'` para não mexer em `state.treino.montagem`**.
- `alertaLesao(ex)` ([5406](../index.html#L5406)) — só ativa em contexto paciente.
- `_deriveGrupos(tm)` ([4730](../index.html#L4730)) — deriva grupos automaticamente dos `primario` dos exercícios.
- `calcVolumeTreino(treinoId)` ([4526](../index.html#L4526)) — volume total.

**Refatoração necessária** (contexto):

Hoje `renderExItem`, `searchExercicioParaTreino`, etc. leem/escrevem direto em `state.treino.montagem.itens[treinoId]`. Precisa parametrizar:

```js
// Antes:
function renderExItem(treinoId, item, idx) { /* usa state.treino.montagem */ }

// Depois:
function renderExItem(contexto, item, idx) {
  // contexto = { source, containerId, onChange }
  // source = state.treino.montagem.itens[treinoId] OU tm.itens
}
```

**Salvar:**

```js
function salvarTreinoModelo(id) {
  const data = {
    nome: v('tm_nome'),
    nivel: v('tm_nivel'),
    itens: [...document.querySelectorAll('.tm_ex_row')].map(row => ({
      exercicioId: row.dataset.exercicioId,
      series: +row.querySelector('.tm_ex_series').value,
      reps: row.querySelector('.tm_ex_reps').value,
      carga: +row.querySelector('.tm_ex_carga').value,
      descanso: +row.querySelector('.tm_ex_descanso').value,
      tecnica: row.querySelector('.tm_ex_tecnica').value,
      obs: row.querySelector('.tm_ex_obs').value,
    })).filter(it => it.exercicioId),
  };
  // grupos derivados dos exercícios (+ override manual)
  data.grupos = _deriveGrupos(data)
    .concat([...document.querySelectorAll('.tm_grupo_cb_override:checked')].map(cb => cb.dataset.grupo));
  data.grupos = [...new Set(data.grupos)];
  // ...
}
```

**Ganho no viewer** `verTreinoModelo` ([11285](../index.html#L11285)): já mostra
`#/Exercício/Séries/Reps/Carga/Descanso` — só passa a ter dados reais.

**Remover:** o `<div class="field-hint">` apologético.

---

## 5. Instruções por editor — Níveis 3 (templates com agenda e metadados)

### 5.1. 🍽️ Alimentação → Template de Plano

**Editor atual** ([linhas 11148–11151](../index.html#L11148), função `templatePlanoEditorHtml`):

6 campos secos: nome, objetivo, VET, macros P/C/G%, `<select multiple>` de refeições, textarea de observação.

**Problemas encontrados:**

#### 5.1.a — Perda de metadados clínicos ricos

Os 89 templates atuais têm no schema (populados via workflow):

- `categoria` — Check-ups / Emagrecimento / Metabolismo / Saúde intestinal / etc.
- `especialidade` — clínica geral, endocrinologia, nutrição funcional, etc.
- `descricao` — racional curto
- `tags` — array de palavras-chave
- `visibilidade` — padrão / privado / equipe
- `observacao` — **markdown estruturado com 12 seções clínicas**: nome, objetivo, estratégia, distribuição, opções, recomendados, proibidos, opcionais, substituições, orientações, observações, fundamentação

**O editor ignora todos esses campos.** Editar um template pela UI destrói metadados ricos.

**Correção:** expor todos os campos. Manter mesma nomenclatura do schema.

#### 5.1.b — Multi-select de refeições é UX pobre

Hoje `<select multiple size=6>`:
- Não mostra kcal/macros de cada refeição.
- Não permite reordenar.
- Não permite repetir refeição (ex: mesmo lanche 2× no dia).
- Não mostra soma total × VET alvo.

**Correção:** virar **agenda diária** (§5.1.c) — resolve todos esses pontos.

#### 5.1.c — Falta `pctVet` por refeição (agenda diária)

O schema atual armazena `refeicoesModeloIds: [rmn1, rmn5, rmn12]` — lista solta, sem horário nem % calórico. Ao aplicar, `aplicarTemplate` distribui com `Math.round(100/N)` (bug §2.2).

**Evolução ontológica:** substituir por **agenda diária**:

```js
// Schema antigo (deprecar mas manter suporte durante migração):
refeicoesModeloIds: ['rmn1', 'rmn5', 'rmn12']

// Schema novo:
agenda_diaria: [
  { ordem: 1, horario: '07:00', refeicaoModeloId: 'rmn1',  pctVet: 25 },
  { ordem: 2, horario: '10:00', refeicaoModeloId: 'rmn5',  pctVet: 10 },
  { ordem: 3, horario: '13:00', refeicaoModeloId: 'rmn12', pctVet: 40 },
  { ordem: 4, horario: '16:00', refeicaoModeloId: 'rmn5',  pctVet: 10 },  // repetido OK
  { ordem: 5, horario: '20:00', refeicaoModeloId: 'rmn8',  pctVet: 15 },
]
```

**Regras:**
- `Σ pctVet === 100`, com validação visual no editor.
- Repetição permitida (mesmo `refeicaoModeloId` em ordens diferentes).
- `horario` opcional; se presente ordena por ele automaticamente.
- Migration: converter `refeicoesModeloIds[]` existente em `agenda_diaria[]` com `pctVet` distribuído via §2.2 (versão corrigida).

**UI proposta:** tabela editável com drag-to-reorder e picker de refeição por linha:

```
── Agenda diária ──
┌────┬────────┬─────────────────────┬────────┬────────┬─────┐
│ ↕  │ 07:00  │ Café mediterrâneo ▾ │  25 %  │ 450 kcal│ ×  │
│ ↕  │ 10:00  │ Lanche pré-treino ▾ │  10 %  │ 180 kcal│ ×  │
│ ↕  │ 13:00  │ Almoço tradicional▾ │  40 %  │ 720 kcal│ ×  │
│ ↕  │ 16:00  │ Lanche pré-treino ▾ │  10 %  │ 180 kcal│ ×  │
│ ↕  │ 20:00  │ Jantar leve       ▾ │  15 %  │ 270 kcal│ ×  │
└────┴────────┴─────────────────────┴────────┴────────┴─────┘
                              Total: 100% · 1800 kcal ✓
[+ Adicionar refeição]
```

O picker `▾` é um autocomplete de refeições-modelo com preview (categoria, kcal, macros) — não `<select>`.

#### 5.1.d — Editor de markdown para `observacao`

Viewer (`verTemplatePlano`) já renderiza via `renderMarkdownClinico` ([10399](../index.html#L10399)) as 12 seções clínicas. Editor volta a `<textarea>` cru — profissional edita, salva, e perde formatação estruturada.

**Correção mínima:** manter `<textarea>`, mas oferecer **template pré-preenchido** com as 12 seções vazias ao criar template novo, e **preview lateral** renderizado ao vivo enquanto edita.

**Correção maior:** editor rich-text simples (h2, listas, negrito). Não precisa de dependência externa — o parser markdown atual (`renderMarkdownClinico`) já cobre.

#### 5.1.e — Estrutura de jejum

Os 21 templates de jejum têm `n_refeicoes_alvo` (1/2/3/4/6/7) intrínseco ao protocolo. Hoje isso vive só na `observacao` textual, não como campo. Formulário precisa expor `n_refeicoes_alvo` quando `categoria === 'jejum'` (ou tag `jejum` presente).

#### 5.1.f — Preview clínico ao editar

Painel lateral direito, sempre visível durante edição:

- Soma de kcal das refeições selecionadas × VET alvo (badge verde/vermelho).
- Distribuição real de macros × macros alvo (barras comparativas).
- Alergênicos presentes (chips).
- Nº de opções por categoria (café / almoço / jantar / etc.).

Reutilizar componentes do modal `verTemplatePlano` ([11068](../index.html#L11068)) — já tem tudo isso implementado; só faltar exibir em modo edit.

#### 5.1.g — Padrão modal ≠ padrão single-page do fluxo

O fluxo do plano é single-page-scroll (sidebar + seções empilhadas). O
editor de template é modal com formulário compacto — inconsistência de
linguagem visual.

**Direção sugerida:** reaproveitar a mesma tela do plano com uma flag
`templateMode: true` que:
- Não exige paciente ativo.
- Substitui "Publicar plano" por "Salvar template".
- Omite anamnese/avaliação/objetivo/estratégia (não fazem sentido em template).
- Renderiza apenas: nome + metadados + Estrutura (agenda diária) + Montagem (refeições populadas) + Observação markdown.

**Custo:** alto (refactor grande). **Decisão para depois** dos passos críticos.

---

### 5.2. 💪 Treino → Template de Programa

**Editor atual** ([linhas 11419–11423](../index.html#L11419)):

Nome, objetivo, fase, duração, nível, split, `<select multiple>` de treinos-modelo, observação.

**Mesmos problemas do §5.1**, adaptados:

#### 5.2.a — Agenda semanal em vez de lista solta

**Evolução ontológica:** substituir `treinosModeloIds: []` por:

```js
agenda_semanal: {
  seg: { tipo: 'treino', treinoModeloId: 'tm3', nome_display: 'A · Peito+Tríceps' },
  ter: { tipo: 'treino', treinoModeloId: 'tm7', nome_display: 'B · Costas+Bíceps' },
  qua: { tipo: 'descanso' },
  qui: { tipo: 'treino', treinoModeloId: 'tm5', nome_display: 'C · Pernas' },
  sex: { tipo: 'treino', treinoModeloId: 'tm3', nome_display: 'A · Peito+Tríceps' },  // repetido
  sab: { tipo: 'cardio', notas: '30 min esteira' },
  dom: { tipo: 'descanso' },
}
```

**UI proposta:** grid 7×1 (segunda a domingo), cada célula com dropdown:
`[Descanso ▾]` · `[Treino A/B/C ▾]` · `[Cardio ▾]`.

Migration: converter `treinosModeloIds[]` existente distribuindo pelos
dias na ordem (Descanso nos dias sobrando).

#### 5.2.b — Preservar metadados

Mesmo tratamento do §5.1.a — expor `categoria`, `descricao`, `tags`,
`visibilidade`, `observacao` como markdown.

#### 5.2.c — Preview + progressão

Painel lateral: volume estimado por semana, distribuição por grupo,
progressão sugerida (se houver `progressao_semanas[]`).

---

### 5.3. 🩺 Exames → Modelo de Solicitação (só melhorar)

**Editor atual** ([linhas 12520–12557](../index.html#L12520)):

Este é o **único do Nível 3 que já tem estrutura correta** (grupos +
itens). **Problema único**: `<select>` HTML nativo com 500+ opções trava
o browser.

**Correção:** trocar o `<select>` de "Adicionar exame ao grupo" por
autocomplete similar ao `exSearchExec(q)` do wizard `ex_selecao`
([13005](../index.html#L13005)):

```
── Grupo 1: Metabolismo glicêmico ──
[✓ obrig] Glicemia de jejum         (soro) [obs...] [×]
[✓ obrig] Insulina                  (soro) [obs...] [×]
[  opc ] HbA1c                      (sangue total) [obs...] [×]

+ Adicionar exame ao grupo:
[autocomplete via AutonDB.buscarExames(q, {limit:20})]  [+ Adicionar]
```

**Peças a reutilizar:**
- `AutonDB.buscarExames(q, {limit: 20})` ([2013](../index.html#L2013))
- Padrão do modal `ex_selecao` ([13022](../index.html#L13022))

Adicional (opcional): botão "Importar exames de outro modelo" para
compor entre modelos.

---

## 6. Integridade referencial (cross-cadastro)

Hoje o app não protege as referências entre cadastros:

- **Excluir uma Refeição-modelo** em uso por N Templates de Plano →
  templates ficam com `refeicoesModeloIds` órfãos silenciosamente.
- **Excluir um Treino-modelo** em uso por N Templates de Programa → idem.
- **Excluir um Exercício** em uso por N Treinos-modelo → idem.
- **Excluir um Alimento** em uso por N Refeições-modelo → idem.
- **Excluir um Produto** em uso por N Fórmulas → idem.

**Padrão que já existe:** limpeza de "templates zumbi" no
`__carregarSeedsTreino` ([4461+](../index.html#L4461)) — remove templates
cujos `treinosModeloIds` não existem mais. Replicar para todos os
cadastros.

**Ações necessárias:**

1. **Aviso ao excluir** — antes de confirmar, mostrar quantos consumidores
   existem:
   ```
   Excluir "Café mediterrâneo"?
   ⚠ Esta refeição é usada por 3 Templates de Plano:
     - Emagrecimento 1800 kcal
     - SOP protocolo A
     - Jejum 16:8 padrão
   ```
2. **3 opções:** [Cancelar] · [Excluir e limpar refs órfãs] · [Excluir mantendo refs órfãs (marcar como "removido")]
3. **Job de limpeza** no boot, opcional: percorrer cadastros e reportar
   refs órfãs para o profissional decidir.
4. **Aliases de nome preservados**: quando um item é removido mas ainda
   referenciado, mostrar `nome_snapshot` no lugar de "REMOVIDO".

---

## 7. Padronização visual

Regras que valem para todos os editores corrigidos:

1. **Sem emojis** — os `ai-panel` dos cadastros ainda têm emojis
   herdados; remover para consistência com o resto do app.
2. **Sem modal aninhado** — se uma escolha secundária aparece dentro
   de um modal (ex: buscar alimento dentro do modal de refeição), fazer
   **inline com dropdown flutuante**, não abrir segunda camada modal.
3. **`<select multiple>` proibido** — sempre autocomplete ou grid de
   cards clicáveis.
4. **Reordenar via drag** (nice-to-have) ou setas ↑↓ (obrigatório) em
   qualquer lista ordenada.
5. **Preview lateral quando útil** — kcal/volume/macros ao vivo no
   canto direito enquanto edita.
6. **Remover mensagens apologéticas** — `field-hint`s com "feature em
   desenvolvimento" ou "por enquanto edita só cabeçalho" saem quando o
   editor for completo.

---

## 8. Discussão ontológica pendente

Enquanto o dev trabalha nos editores, valem três discussões estratégicas.

### 8.1. "Painel de Exames" deve existir como Nível 2 formal?

Hoje o cadastro de Exames tem só 2 níveis (Exame + Modelo de Solicitação).
O que o brief original chamava de "Painel" hoje aparece como:

- Exame com `tipo_exame='composto'` (ex: Hemograma agrupando HB, HT, leucócitos como `componentes[]`) — LOINC oficial.
- Grupo dentro de um Modelo de Solicitação (ex: "Metabolismo glicêmico" agrupando 4 exames).

**Pergunta:** ganharíamos algo criando um cadastro separado "Painel"
como Nível 2? Prós: reutilização entre modelos ("Perfil lipídico" pode
aparecer em vários modelos). Contras: mais uma entidade pra manter e
duplicação parcial com "composto" LOINC.

**Sugestão:** manter 2 níveis por enquanto. Se aparecer necessidade
real (mesmo painel em N modelos), promove.

### 8.2. Template de Prescrição vs Fórmula — quando usar cada um?

A Fórmula (Nível 2) já compõe Produtos. O Template de Prescrição
(Nível 3) **não compõe Fórmulas nem Produtos** hoje — ele é um
"protocolo de prescrição" texto com metadados clínicos.

**Isso é intencional?** Ou o Template de Prescrição deveria também
poder referenciar Produtos/Fórmulas como itens (do jeito que o wizard
`rx_itens` faz)?

**Cenário ideal:**

```
Template "Tratamento SIBO — 4 semanas"
├── Item 1: Fórmula "Berberina + Alicina 500 mg" · 1 cáp 2×dia · 30d
├── Item 2: Produto "Rifaximina 550mg" · 1 comp 3×dia · 14d
├── Item 3: Fórmula "Enzimas digestivas plus" · 1 cáp antes das refeições · 30d
└── Instruções ao paciente: [texto]
```

Se o time endossar, o Template de Prescrição vira o **Nível 3
composicional** do domínio Prescrição, coerente com os outros 3
domínios. Pergunta clínica/de produto.

### 8.3. "Aluno" ainda vai virar entidade separada?

Documentado em `01-ONTOLOGIA.md` §2.1 — hoje "Aluno" é só label para
Paciente no contexto de Treino. Se o produto expandir para
academias/estúdios (onde aluno ≠ paciente), precisa evoluir o modelo
ontológico. Pergunta para o time de produto.

---

## 9. Ordem final de implementação

Prioridade recalibrada considerando bloqueadores, bugs críticos e
esforço:

| # | Item | Impacto | Esforço | Tipo |
|:-:|---|:-:|:-:|---|
| **0a** | Deduplicar 3 renderers (§2.1) | 🟡 Prevenção | 🟢 30 min | Dívida técnica |
| **0b** | Corrigir bug 33+33+33 em `aplicarTemplate` (§2.2) | 🔥 Alto | 🟢 15 min | Bug crítico |
| **1** | Refeição-modelo — editor de itens (§4.1) | 🔥 Alto | 🟡 2h | Feature quebrada |
| **2** | Treino-modelo — editor de itens (§4.2) | 🔥 Alto | 🟡 2h + refactor `renderExItem` p/ contexto | Feature quebrada |
| **3** | Template de Plano — metadados + agenda diária + migration (§5.1a-c-f) | 🔥 Alto | 🔴 3-4h | Perda de dados |
| **4** | Template de Programa — agenda semanal + migration (§5.2) | 🔥 Alto | 🟡 2h | Feature |
| **5** | Editor markdown + estrutura de jejum (§5.1d,e) | 🟡 Médio | 🟡 2h | Preservação clínica |
| **6** | Modelo de Solicitação — trocar `<select>` (§5.3) | 🟡 Médio | 🟢 1h | UX |
| **7** | Integridade referencial (§6) | 🟡 Médio | 🟡 2-3h | Confiabilidade |
| **8** | Padronização visual (§7) | 🟢 Baixo | 🟢 1h | Consistência |
| **9** | (opcional) `templateMode` single-page (§5.1g) | 🟢 Baixo | 🔴 6-8h | Refactor arquitetural |

**Estimativa realista para 0–8:** ~2.5 a 3 dias de dev experiente.
Item 9 (opcional) fica para depois.

**Ordem sugerida:** exatamente na ordem da tabela. Passos 0a e 0b são
obrigatórios antes de qualquer outro (0a evita bugs invisíveis; 0b
destrava wizard).

---

## 10. Checklist de aceitação por editor

Todo editor corrigido precisa passar por:

- [ ] Editor coleta itens do Nível N−1 (não só cabeçalho)
- [ ] Autocomplete usa a base oficial correspondente (TACO / freedb / ANVISA / LOINC)
- [ ] Cada item é vinculado por `id` (não só nome), com fallback texto livre
- [ ] Cada item guarda os campos do relacionamento (gramas / séries+reps+carga+técnica / dose)
- [ ] Cálculo agregado ao vivo (kcal total / volume total / % VET / etc.)
- [ ] Preview visual do que já foi adicionado (não lista texto)
- [ ] Botão remover por item e reordenar (setas ↑↓ no mínimo)
- [ ] Ao salvar, escreve em `itens[]` / `agenda_*[]` no schema (já existe ou migration §5)
- [ ] Viewer (`verX`) mostra o conteúdo real (já preparado — só precisa dados)
- [ ] Nenhum uso de `<select multiple>` HTML nativo — sempre autocomplete ou grid de cards
- [ ] Metadados clínicos do seed preservados (categoria, especialidade, tags, visibilidade, markdown estruturado)
- [ ] Aviso ao excluir item em uso por N consumidores (§6)
- [ ] Nenhuma mensagem apologética "feature em desenvolvimento" restante
- [ ] Sem emojis nos ai-panels
- [ ] Sem modal aninhado (subordinação inline)

---

## Anexo A · Comandos úteis para o dev

Grep de duplicações (para o passo 0a e para achar mais dívidas):

```sh
grep -n 'RENDERERS\.\w\+ = function' auton-v2/index.html \
  | awk -F: '{print $NF}' | awk '{print $1}' | sort | uniq -d
```

Rodar após deduplicar para confirmar zero:

```sh
grep -c 'RENDERERS\.cadastroTreinos = function' auton-v2/index.html      # esperado: 1
grep -c 'RENDERERS\.cadastroExercicios = function' auton-v2/index.html   # esperado: 1
grep -c 'RENDERERS\.cadastroTemplatesPrograma = function' auton-v2/index.html # esperado: 1
```

Verificar migrations (após implementar §5.1 e §5.2):

```sh
sqlite3 data/auton.db ".dump" | grep -E 'agenda_diaria|agenda_semanal' | head
# (essas colunas moram no localStorage do state, não no SQLite —
#  mas se algum dia migrar cadastros para o SQLite, aqui é o hook)
```
