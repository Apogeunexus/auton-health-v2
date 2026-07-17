# 05 · Correções — Tela **Cadastros**

> **Escopo estrito:** correções nos **11 sub-cadastros** da rota
> `data-route="cadastros"`. Nada de wizard, nada de fluxo clínico, nada
> de tela de paciente. Só a **biblioteca de conhecimento reutilizável**
> do profissional.
>
> **Fora de escopo:** correções em `aplicarTemplate`, `salvarInstrumentoNoPaciente`,
> renderers do wizard (`RENDERERS.inicio/anamnese/t_split/rx_itens/ex_selecao`).
> Bugs desses arquivos citados aqui são **notas correlatas**, não itens
> deste plano. Eles vão para `06-CORRECOES-FLUXO.md` (a criar).

---

## Sumário

- [1. Escopo — os 11 sub-cadastros](#1-escopo--os-11-sub-cadastros)
- [2. Diagnóstico](#2-diagnóstico-11-sub-cadastros--6-critérios)
- [3. Bloqueadores prévios](#3-bloqueadores-prévios-fazer-primeiro)
- [4. Padrão de referência](#4-padrão-de-referência--editor-de-fórmula)
- [5. Arquitetura de componentes reutilizáveis](#5-arquitetura-de-componentes-reutilizáveis)
- [6. Correções por sub-cadastro](#6-correções-por-sub-cadastro)
- [7. Integridade referencial](#7-integridade-referencial-entre-cadastros)
- [8. Padronização visual](#8-padronização-visual)
- [9. Migrações de schema](#9-migrações-de-schema)
- [10. Ordem de implementação e Definition of Done](#10-ordem-de-implementação-e-definition-of-done)
- [Anexos](#anexo-a--comandos-úteis-para-o-dev)

---

## 1. Escopo — os 11 sub-cadastros

Registrados em `CADASTRO_TABS` ([index.html:8736–8772](../index.html#L8736)).
Rota entra por `goTo('cadastros')` → `RENDERERS.cadastros`
([10124](../index.html#L10124)) → delega para o sub-renderer da sub-tab
ativa em `#cadastroSubContent`.

| # | Top-tab | Sub-tab (`key`) | Nível | Renderer | Editor `*EditorHtml` |
|:-:|---|---|:-:|---|---|
| 1 | Alimentação | `alimentos` | 1 | `cadastroAlimentos` @10171 | `alimentoEditorHtml` @10214 |
| 2 | Alimentação | `refeicoes` | 2 | `cadastroRefeicoes` @10280 | `refeicaoModeloEditorHtml` @10331 |
| 3 | Alimentação | `templates_plano` | 3 | `cadastroTemplatesPlano` @10382 | `templatePlanoEditorHtml` @11148 |
| 4 | Treino | `exercicios` | 1 | `cadastroExercicios` @11211 ⚠ | `exercicioEditorHtml` @11220 |
| 5 | Treino | `treinos` | 2 | `cadastroTreinos` @11278 ⚠ | `treinoModeloEditorHtml` @11297 |
| 6 | Treino | `templates_programa` | 3 | `cadastroTemplatesPrograma` @11339 ⚠ | `templatePrgEditorHtml` @11419 |
| 7 | Prescrição | `produtos` | 1 | `cadastroProdutos` @11460 | `produtoEditorHtml` @11591 |
| 8 | Prescrição | `formulas` | 2 | `cadastroFormulas` @11689 | `formulaEditorHtml` @11715 ★ |
| 9 | Prescrição | `templates_prescricao` | 3 | `cadastroTemplatesPrescricao` @11835 | `templatePrescricaoEditorHtml` @12081 |
| 10 | Exames | `exames_lista` | 1 | `cadastroExames` @12215 | `exameEditorHtml` @12280 |
| 11 | Exames | `modelos_exames` | 3 | `cadastroModelosExames` @12427 | `modeloExamesEditorHtml` @12520 |

**Marcadores:** ★ = padrão de referência ontológico · ⚠ = renderer duplicado (§3.1)

**Ausente:** não há sub-cadastro de **Painel de Exames** (Nível 2 do
domínio Exames). Ver `01-ONTOLOGIA.md` §2.4.2 — implementação atual usa
`tipo_exame='composto'` (LOINC) ou grupo dentro de Modelo de Solicitação.

---

## 2. Diagnóstico — 11 sub-cadastros × 6 critérios

| # | Sub-cadastro | Cabeçalho | Composição N−1 | Metadados ricos | Preview ao editar | Integridade | Padrão UI |
|:-:|---|:-:|:-:|:-:|:-:|:-:|:-:|
| 1 | Alimentos | ✅ | (é átomo) | ✅ | — | ⚠ | ✅ |
| 2 | Refeições-modelo | ✅ | ❌ **falta** | ⚠ falta `perfil` tags | ❌ | ⚠ | ⚠ |
| 3 | Templates de Plano | ✅ | 🔴 `<select multiple>` | 🔴 **destrói** | ❌ | ⚠ | 🔴 |
| 4 | Exercícios | ✅ | (é átomo) | ⚠ só 1 grupo/equip | — | ⚠ | ✅ |
| 5 | Treinos-modelo | ✅ | ❌ **falta** | ✅ | ❌ | ⚠ | ⚠ |
| 6 | Templates de Programa | ✅ | 🔴 `<select multiple>` | ⚠ falta agenda | ❌ | ⚠ | 🔴 |
| 7 | Produtos | ✅ | (é átomo) | ✅ | ✅ (`verProduto`) | ⚠ | ✅ |
| 8 | Fórmulas | ✅ | ✅ autocomplete | ✅ | ⚠ básico | ⚠ | ✅ ★ |
| 9 | Templates de Prescrição | ✅ | N/A (§8.2 disc.) | ✅ | ⚠ básico | — | ✅ |
| 10 | Exames | ✅ | (é átomo) | ✅ | ✅ (`verExame`) | ⚠ | ✅ |
| 11 | Modelos de Solicitação | ✅ | ⚠ `<select>` 500+ | ✅ | ✅ (`verModelo…`) | ⚠ | ⚠ |

**Legenda:** ✅ ok · ⚠ funciona mas melhorável · 🔴 quebrado/perigoso · ❌ ausente

**Padrões identificados:**

- **6 dos 11** editores estão inteiramente ok ou têm pequenas melhorias (1, 4, 7, 8, 9, 10).
- **2 editores** (Refeição-modelo, Treino-modelo) estão **inteiramente quebrados** — só cabeçalho, sem composição. Impossível criar via UI.
- **2 editores** (Templates de Plano e Programa) usam **`<select multiple>` HTML nativo**, destroem metadados clínicos ricos e não têm agenda temporal.
- **1 editor** (Modelo de Solicitação) está quase certo — só o `<select>` de "adicionar exame" precisa virar autocomplete.

---

## 3. Bloqueadores prévios (fazer PRIMEIRO)

### 3.1. Deduplicar 3 renderers do domínio Treino

Confirmado por grep: as três funções abaixo são declaradas **duas
vezes** no mesmo arquivo. Como o JS avalia em ordem, a segunda
declaração **sobrescreve silenciosamente** a primeira — qualquer
correção feita na versão de cima não tem efeito.

| Renderer | Definição obsoleta (remover) | Definição canônica (manter) |
|---|---|---|
| `RENDERERS.cadastroExercicios` | [index.html:5906](../index.html#L5906) | [index.html:11211](../index.html#L11211) |
| `RENDERERS.cadastroTreinos` | [index.html:5924](../index.html#L5924) | [index.html:11278](../index.html#L11278) |
| `RENDERERS.cadastroTemplatesPrograma` | [index.html:5941](../index.html#L5941) | [index.html:11339](../index.html#L11339) |

**Ação:** deletar as 3 funções obsoletas (as de linha 59xx). Verificar
com o grep do §A.

**Custo:** ~30 min. Ganho: sanidade para tudo que vem depois.

### 3.2. Nota correlata (fora de escopo — só menção)

Existe bug em `aplicarTemplate` (fluxo do wizard, linha 7247) que
distribui `pctVet` com `Math.round(100/N)` — dá 99% para 3 refeições,
102% para 6, 98% para 7. **Não é bug de cadastro**, mas fica
**contornado** se a correção do §6.3 (Template de Plano com
`agenda_diaria[]` explícito) for feita — o `aplicarTemplate` deixa de
precisar distribuir. Correção do bug em si pertence ao próximo doc de
correções de wizard.

---

## 4. Padrão de referência — Editor de Fórmula

**Função:** `formulaEditorHtml` ([index.html:11715](../index.html#L11715)).

É o único editor de Nível 2 que compõe corretamente do Nível 1. Serve
de blueprint para os editores 2 e 5 (Refeição-modelo e Treino-modelo)
e para os pickers dentro dos editores 3 e 6 (Templates).

### 4.1. Anatomia

```
┌─ Cabeçalho ────────────────────────────────┐
│ Nome*, tipo farmacêutico, duração,        │
│ posologia geral, observação                │
└────────────────────────────────────────────┘
┌─ Lista de componentes (Nível 1 = Produto) ─┐
│ ┌─ Linha 1 ──────────────────────────────┐ │
│ │ [autocomplete Produto ▼] [dose] [obs] × │ │
│ │  ↳ dropdown flutuante  8 primeiros      │ │
│ │  ↳ hidden .fm_cmp_pid = produto_id      │ │
│ │  ↳ badge: 🟢 vinculado / ⚪ texto livre │ │
│ ├─ Linha 2 ──────────────────────────────┤ │
│ │ ...                                     │ │
│ └─────────────────────────────────────────┘ │
│ [+ Adicionar componente]                   │
└────────────────────────────────────────────┘
```

### 4.2. Peças-chave

| Função | Linha | O que faz |
|---|---|---|
| `componenteRowHtml(c, i)` | 11725 | HTML de uma linha de componente |
| `buscarProdutoParaComponente(inputEl, idx)` | 11743 | Autocomplete via `AutonDB.buscarProdutos(q, {limit:8})` |
| `selecionarProdutoComponente(prod, idx)` | 11757 | Vincula: preenche pid, snapshot do nome, auto-fill de dose com `prod.concentracao` |
| Listener de desvincular | 11768 | Se usuário edita nome depois de vincular → remove vínculo |
| `addComponente()` | 11737 | Adiciona linha vazia |

### 4.3. Regras invioláveis do padrão

1. **Autocomplete quando N−1 é grande** (>50 itens) — nunca `<select>` HTML.
2. **Vinculação por id** — cada linha carrega hidden com `<nivel1>_id`. Preserva referência ao catálogo mesmo quando o nome é editado.
3. **Fallback texto livre** — editar o nome depois de vincular remove o vínculo silenciosamente; nada é perdido.
4. **Auto-fill inteligente** — ao vincular, preenche defaults derivados do item.
5. **Indicador visual do vínculo** — badge verde ou cinza; profissional sempre sabe o estado.
6. **Contexto isolado** — editor de cadastro NUNCA lê/escreve em `state.plano/treino/rx/ex`. Escreve só em `state.cadastros.<tipo>[]`.

---

## 5. Arquitetura de componentes reutilizáveis

Antes de mexer nos editores, **extrair 8 componentes utilitários**. O
mesmo padrão vai ser aplicado várias vezes; extrair uma vez economiza
retrabalho e evita divergência entre editores.

| # | Componente | Assinatura sugerida | Usado em |
|:-:|---|---|---|
| C1 | Autocomplete de Alimento | `_pickAlimento(container, onSelect, {excluirIds})` | Refeição-modelo, wizard Montagem |
| C2 | Autocomplete de Exercício | `_pickExercicio(container, onSelect, {grupoFiltro})` | Treino-modelo, wizard Split |
| C3 | Autocomplete de Refeição-modelo | `_pickRefeicaoModelo(container, onSelect)` | Template de Plano |
| C4 | Autocomplete de Treino-modelo | `_pickTreinoModelo(container, onSelect, {grupoFiltro})` | Template de Programa |
| C5 | Autocomplete de Exame | `_pickExame(container, onSelect, {categoriaFiltro})` | Modelo de Solicitação, wizard `ex_selecao` |
| C6 | Editor de Agenda Diária | `_editorAgendaDiaria(tp, containerId)` | Template de Plano |
| C7 | Editor de Agenda Semanal | `_editorAgendaSemanal(tpp, containerId)` | Template de Programa |
| C8 | Preview lateral ao vivo | `_previewLateral(tipo, dataRef)` | Refeição-modelo, Treino-modelo, ambos Templates |

**Já existem** (não precisa criar, só refatorar para aceitar contexto):

- `searchFoodInline` @7852 → base de C1.
- `searchExercicioParaTreino` @5245 → base de C2.
- `exSearchExec` @13005 → base de C5.

**Novos** (não têm equivalente): C3, C4, C6, C7, C8.

Regra de assinatura: **todo componente recebe um container-alvo e um
callback `onSelect`. Nunca escreve em `state.*` diretamente** — o
editor pai decide o que fazer com a seleção.

---

## 6. Correções por sub-cadastro

Cada sub-seção segue o mesmo formato: **Estado atual → Mudança
necessária → Mockup → Snippet de salvar → Definition of Done**.

### 6.1. ❶ Alimentos — ✅ ok, ajustes menores

**Estado atual:** editor completo ([alimentoEditorHtml @10214](../index.html#L10214)).
Cobre nome, grupo, kcal, P/C/G/100g, porção padrão, alergenos.

**Ajustes propostos:**
- Adicionar campo `fibra_g` no editor (schema já tem, editor ignora).
- Adicionar campo `sodio_mg` idem.
- Botão "importar do catálogo TACO" apontando para
  `renderPainelCatalogoOficial('alimentos')` — já existe para
  Produtos e Exames, replicar para Alimentos.

**DoD:** editor grava todos os campos que o schema `alimentos` suporta
(ver `03-DADOS.md` §2.4).

---

### 6.2. ❷ Refeições-modelo — ❌ SÓ CABEÇALHO (crítico)

**Estado atual:** [refeicaoModeloEditorHtml @10331](../index.html#L10331).
Coleta só `nome` + `categoria`. O código admite:

> *"Após salvar, os itens de alimento serão editáveis (feature em
> desenvolvimento — hoje edita apenas cabeçalho)."*

Impossível criar refeição funcional pela UI. Só as ~116 vindas de seed
têm `itens[]`.

**Mudança necessária:**

```
┌─ Cabeçalho ────────────────────────────────────────────┐
│ Nome*, categoria (café/lanche/almoço/…)                │
│ Perfil clínico: [+ tag] low-carb ⊗  jejum ⊗  sop ⊗    │
└────────────────────────────────────────────────────────┘
┌─ Alimentos da refeição ────────────────────────────────┐
│ ┌─ Linha ─────────────────────────────────────────────┐│
│ │ [autocomplete Alimento▼] [100g] [1 xíc ▾] [obs]  × ││
│ │  🟢 TACO 132 · Arroz integral cozido                ││
│ │                                          115 kcal   ││
│ ├─────────────────────────────────────────────────────┤│
│ │ ...                                                 ││
│ └─────────────────────────────────────────────────────┘│
│ [+ Adicionar alimento]                                 │
├────────────────────────────────────────────────────────┤
│ Total: 3 alimentos · 425 kcal · P22 C55 G14           │
│                       Fibra 8g · Sódio 320 mg          │
└────────────────────────────────────────────────────────┘
```

**Componentes:** C1 (autocomplete alimento), C8 (preview lateral opcional).

**Reaproveitar:**
- `MEDIDAS_CASEIRAS` @10425 — dropdown de medida caseira por alimento.
- `calcularRefeicao(r)` @11054 — total agregado ao vivo.
- `nutriPorGramas(alimento, gramas)` @6635 — por-item ao vivo.

**Snippet salvar:**

```js
function salvarRefeicaoModelo(id) {
  const v = k => document.getElementById(k).value.trim();
  const data = {
    nome: v('rm_nome'),
    categoria: v('rm_cat'),
    perfil: [...document.querySelectorAll('.rm_perfil_chip')].map(c => c.dataset.tag),
    itens: [...document.querySelectorAll('.rm_item_row')].map(row => ({
      alimentoId: row.dataset.alimentoId || null,
      alimento_nome: row.querySelector('.rm_item_nome').value,
      gramas: +row.querySelector('.rm_item_gramas').value || 0,
      medidaCaseira: row.querySelector('.rm_item_medida')?.value || null,
      obs: row.querySelector('.rm_item_obs').value,
    })).filter(it => it.alimentoId || it.alimento_nome),
  };
  if (!data.nome) { toast('Nome é obrigatório'); return; }
  if (id) Object.assign(allRefeicoesModelo().find(x => x.id === id), data);
  else { data.id = 'rm_' + rand6(); allRefeicoesModelo().push(data); }
  scheduleSave(); closeModal(); RENDERERS.cadastroRefeicoes();
}
```

**DoD:**
- [ ] Adicionar alimento por autocomplete funciona
- [ ] Preencher gramas atualiza kcal do item ao vivo
- [ ] Total agregado (kcal/P/C/G/fibra/sódio) recalculado ao vivo
- [ ] Remover linha funciona
- [ ] Ao salvar, `itens[]` é populado no state
- [ ] Ao reabrir, os itens salvos aparecem
- [ ] `verRefeicaoModelo` @10298 mostra os itens (já preparado)
- [ ] Remover a mensagem "feature em desenvolvimento"
- [ ] Remover o `ai-panel` "Este é o cadastro base"

---

### 6.3. ❸ Templates de Plano — 🔴 múltiplos problemas críticos

**Estado atual:** [templatePlanoEditorHtml @11148](../index.html#L11148).
6 campos secos: nome, objetivo, VET, macros P/C/G%, `<select multiple>`
de refeições, textarea de observação.

**Problemas:**

| # | Problema | Gravidade |
|:-:|---|:-:|
| 1 | **Perda de metadados** — editor ignora `categoria`, `especialidade`, `descricao`, `tags`, `visibilidade`, e o `observacao` com 12 seções clínicas markdown que os workflows populam | 🔴 Perda de dados silenciosa ao editar |
| 2 | **`<select multiple>` HTML** — sem preview de kcal/macros, sem reordenar, sem repetir refeição | 🔴 UX inutilizável para plano real |
| 3 | **Falta `pctVet` por refeição** — schema atual é `refeicoesModeloIds:[]` (lista solta); ao aplicar, `aplicarTemplate` distribui uniformemente com bug (§3.2) | 🔴 Trava wizard |
| 4 | **Editor de observação é `<textarea>` cru** — viewer renderiza markdown mas editor destrói formatação | 🟡 Regressão ao editar |
| 5 | **Estrutura de jejum não é campo** — os 21 templates de jejum têm `n_refeicoes_alvo` que hoje só vive no texto | 🟡 Metadado semanticamente perdido |
| 6 | **Sem preview clínico ao editar** — viewer tem tudo, editor tem nada | 🟡 UX pobre |

**Mudança necessária — schema:**

Introduzir `agenda_diaria[]` substituindo `refeicoesModeloIds[]`.
Manter suporte a `refeicoesModeloIds[]` durante migração (§9).

```js
// Antigo
{
  refeicoesModeloIds: ['rmn1', 'rmn5', 'rmn12']
}

// Novo
{
  agenda_diaria: [
    { ordem: 1, horario: '07:00', refeicaoModeloId: 'rmn1',  pctVet: 25 },
    { ordem: 2, horario: '10:00', refeicaoModeloId: 'rmn5',  pctVet: 10 },
    { ordem: 3, horario: '13:00', refeicaoModeloId: 'rmn12', pctVet: 40 },
    { ordem: 4, horario: '16:00', refeicaoModeloId: 'rmn5',  pctVet: 10 },  // repetido OK
    { ordem: 5, horario: '20:00', refeicaoModeloId: 'rmn8',  pctVet: 15 },
  ]
}
```

Regras:
- `Σ pctVet === 100` — validação visual no editor (badge verde/vermelho).
- Repetição permitida (mesmo `refeicaoModeloId` em ordens diferentes).
- `horario` opcional; se presente, ordena automaticamente.

**Mudança necessária — UI:**

```
┌─ Identidade ──────────────────────────────────────────┐
│ Nome*                                                  │
│ Categoria [Check-ups ▾]  Especialidade [nutrição ▾]   │
│ Descrição curta [textarea]                             │
│ Tags: [+] emagrecimento ⊗  low-carb ⊗                 │
│ Visibilidade: (○) privado  (●) equipe  (○) padrão     │
├─ Meta calórica ──────────────────────────────────────┤
│ VET alvo [1800] kcal   Macros P[30] C[45] G[25]       │
├─ Agenda diária ──────────────────────────────────────┤
│ ┌─┬───────┬────────────────────┬──────┬───────┬────┐  │
│ │↕│ 07:00 │ Café mediterrâneo ▾│  25% │ 450   │ ×  │  │
│ │↕│ 10:00 │ Lanche pré-treino ▾│  10% │ 180   │ ×  │  │
│ │↕│ 13:00 │ Almoço tradicional▾│  40% │ 720   │ ×  │  │
│ │↕│ 16:00 │ Lanche pré-treino ▾│  10% │ 180   │ ×  │  │
│ │↕│ 20:00 │ Jantar leve       ▾│  15% │ 270   │ ×  │  │
│ └─┴───────┴────────────────────┴──────┴───────┴────┘  │
│                              Total: 100% · 1800 kcal ✓ │
│ [+ Adicionar refeição]                                 │
├─ Estrutura de jejum (opcional) ──────────────────────┤
│ Nº refeições alvo do protocolo: [3 ▾]                  │
│ Janela alimentar: [08:00 → 20:00]                      │
├─ Racional clínico ───────────────────────────────────┤
│ [editor 2 painéis: markdown | preview lado a lado]     │
│ Botão: [Preencher 12 seções padrão]                    │
└────────────────────────────────────────────────────────┘
```

**Componentes:** C3 (autocomplete refeição-modelo) + C6 (agenda diária).

**Preview lateral (opcional, ganho grande):** painel direito com
"soma real vs alvo" (kcal, macros, distribuição por categoria de
refeição).

**Snippet salvar:**

```js
function salvarTemplatePlano(id) {
  const v = k => document.getElementById(k).value;
  const data = {
    nome: v('tp_nome').trim(),
    categoria: v('tp_categoria') || null,
    especialidade: v('tp_especialidade') || null,
    descricao: v('tp_descricao') || null,
    tags: [...document.querySelectorAll('.tp_tag_chip')].map(c => c.dataset.tag),
    visibilidade: v('tp_visibilidade') || 'privado',
    objetivo: v('tp_obj'),
    vet_alvo: +v('tp_vet'),
    macros: { p: +v('tp_p'), c: +v('tp_c'), g: +v('tp_g') },
    agenda_diaria: [...document.querySelectorAll('.tp_row')].map((row, i) => ({
      ordem: i + 1,
      horario: row.querySelector('.tp_horario').value || null,
      refeicaoModeloId: row.dataset.refId,
      pctVet: +row.querySelector('.tp_pct').value || 0,
    })).filter(x => x.refeicaoModeloId),
    n_refeicoes_alvo: +v('tp_n_refs_alvo') || null,
    janela_alimentar: v('tp_janela') || null,
    observacao: v('tp_obs'),  // markdown
  };
  // Validação soma pctVet
  const soma = data.agenda_diaria.reduce((s, r) => s + r.pctVet, 0);
  if (data.agenda_diaria.length && soma !== 100) {
    toast(`Soma dos % deve ser 100 (atual: ${soma})`); return;
  }
  // ...
}
```

**DoD:**
- [ ] Todos os 12+ campos do schema são coletados e persistidos
- [ ] Agenda diária editável (adicionar, reordenar, repetir, remover)
- [ ] Soma de pctVet validada = 100
- [ ] `n_refeicoes_alvo` coletado quando categoria/tags de jejum
- [ ] Markdown editor com preview lado a lado
- [ ] Preview clínico ao vivo com kcal/macros total (opcional mas recomendado)
- [ ] Backward compat: se template legado tem `refeicoesModeloIds[]`, migração (§9) para `agenda_diaria[]`
- [ ] `verTemplatePlano` @11068 continua funcionando

---

### 6.4. ❹ Exercícios — ✅ ok, um ajuste

**Estado atual:** editor completo ([exercicioEditorHtml @11220](../index.html#L11220)).

**Ajuste único:** hoje editor aceita **1 grupo primário** e **1
equipamento**, mesmo que o modelo permita arrays (`primario[]`,
`equip[]`). Sem-cerimônia: converter os dois campos em checkboxes
(igual grupos musculares do Treino-modelo) para permitir múltiplos.

**DoD:** editor grava arrays em `primario[]` e `equip[]`; freedb-loaded
exercícios continuam com múltiplos primários (não regressão).

---

### 6.5. ❺ Treinos-modelo — ❌ SÓ CABEÇALHO (crítico)

**Estado atual:** [treinoModeloEditorHtml @11297](../index.html#L11297).
Coleta `nome`, `nivel`, checkboxes de `grupos`. Sem itens de exercício.
Código admite:

> *"Após salvar, adicione exercícios editando individualmente ou usando
> este treino-modelo dentro de um programa."*

**Mudança necessária:**

```
┌─ Cabeçalho ────────────────────────────────────────────┐
│ Nome*   Nível [intermediário ▾]                        │
└────────────────────────────────────────────────────────┘
┌─ Exercícios do treino ────────────────────────────────┐
│ [+ Adicionar exercício]  [🤖 Sugerir com IA]           │
│ ┌─ Linha ─────────────────────────────────────────────┐│
│ │ [autocomplete Exercício▼]                           ││
│ │ 🖼️ Supino reto com barra                            ││
│ │ [3 séries][8-12 reps][40 kg][60s][normal ▾][obs] × ││
│ │ Chips: peito · tríceps                              ││
│ ├─────────────────────────────────────────────────────┤│
│ │ ...                                                 ││
│ └─────────────────────────────────────────────────────┘│
├────────────────────────────────────────────────────────┤
│ Total: 5 exercícios · 15 séries · ~2200 kg volume     │
│ Grupos derivados: peito · costas · tríceps            │
│ Override manual: [+ core] [+ ombros]                  │
└────────────────────────────────────────────────────────┘
```

**Componentes:** C2 (autocomplete exercício).

**Reaproveitar (com refactor para contexto isolado):**
- `renderExItem(contexto, item, idx)` @5392 — inputs inline. **Precisa
  aceitar `contexto={source, container, onChange}` em vez de `treinoId`
  hardcoded**, para não tocar em `state.treino.montagem`.
- `iaSugerirExerciciosParaTreino(contexto)` @5251 — mesma refatoração.
- `_deriveGrupos(tm)` @4730 — grupos automáticos.
- `calcVolumeTreino(source)` @4526 — precisa aceitar source em vez de treinoId.

**Regra de contexto (importante):** o editor de cadastro escreve em
`tm.itens[]` local do modelo, **nunca** em `state.treino.montagem.itens`.
Alerta de lesão (`alertaLesao` @5406) só ativa em contexto paciente —
no cadastro é dispensado.

**Snippet salvar:**

```js
function salvarTreinoModelo(id) {
  const v = k => document.getElementById(k).value;
  const data = {
    nome: v('tm_nome').trim(),
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
  // grupos = derivados + override
  const derivados = _deriveGrupos(data);
  const override = [...document.querySelectorAll('.tm_grupo_override:checked')].map(cb => cb.dataset.grupo);
  data.grupos = [...new Set([...derivados, ...override])];
  // ...
}
```

**DoD:**
- [ ] Autocomplete de exercício funciona
- [ ] Séries/reps/carga/descanso/técnica editáveis inline
- [ ] Volume total recalculado ao vivo
- [ ] Grupos derivados dos exercícios automaticamente + override manual
- [ ] Botão IA de sugestão funciona (sem tocar em state.treino)
- [ ] `verTreinoModelo` @11285 mostra os itens (já preparado)
- [ ] Remover mensagem "feature em desenvolvimento"

---

### 6.6. ❻ Templates de Programa — 🔴 lista solta em vez de agenda

**Estado atual:** [templatePrgEditorHtml @11419](../index.html#L11419).
Nome, objetivo, fase, duração, nível, split, `<select multiple>` de
treinos-modelo, observação.

**Problemas:**

| # | Problema | Gravidade |
|:-:|---|:-:|
| 1 | **Lista solta** — `treinosModeloIds:[]` sem ordem semântica. Não representa "segunda=A, terça=B, quarta=descanso" | 🔴 Modelo não bate com realidade |
| 2 | **`<select multiple>` HTML** — sem preview | 🔴 UX pobre |
| 3 | **Perda de metadados** — mesmos ignorados do Template de Plano (categoria, tags, etc.) | ⚠ |
| 4 | **Sem visualização de volume/frequência estimada** | ⚠ |

**Mudança necessária — schema:**

```js
// Antigo
{
  treinosModeloIds: ['tm3', 'tm7', 'tm5']
}

// Novo
{
  agenda_semanal: {
    seg: { tipo: 'treino', treinoModeloId: 'tm3', nome_display: 'A · Peito+Tríceps' },
    ter: { tipo: 'treino', treinoModeloId: 'tm7', nome_display: 'B · Costas+Bíceps' },
    qua: { tipo: 'descanso' },
    qui: { tipo: 'treino', treinoModeloId: 'tm5', nome_display: 'C · Pernas' },
    sex: { tipo: 'treino', treinoModeloId: 'tm3', nome_display: 'A · Peito+Tríceps' },
    sab: { tipo: 'cardio', notas: '30 min esteira zona 2' },
    dom: { tipo: 'descanso' },
  }
}
```

Tipos aceitos: `treino | descanso | cardio | ativa` (recuperação ativa).

**Mudança necessária — UI:**

```
┌─ Identidade ──────────────────────────────────────────┐
│ Nome*   Categoria [hipertrofia ▾]                     │
│ Descrição   Tags   Visibilidade                       │
├─ Programa ───────────────────────────────────────────┤
│ Objetivo, Fase, Duração (semanas), Nível, Split       │
├─ Agenda semanal ─────────────────────────────────────┤
│ ┌───┬──────────────────────────┐                      │
│ │Seg│ Treino A · Peito+Tríceps▾│ 5 ex · 15 séries    │
│ │Ter│ Treino B · Costas+Bíceps▾│ 4 ex · 12 séries    │
│ │Qua│ Descanso ▾                │                     │
│ │Qui│ Treino C · Pernas       ▾│ 6 ex · 18 séries    │
│ │Sex│ Treino A · Peito+Tríceps▾│ 5 ex · 15 séries    │
│ │Sáb│ Cardio · 30 min zona 2  ▾│                     │
│ │Dom│ Descanso ▾                │                     │
│ └───┴──────────────────────────┘                      │
│ Frequência: 4× semana treino · 2× descanso · 1× cardio│
│ Volume estimado semana: ~8400 kg                       │
├─ Racional clínico ───────────────────────────────────┤
│ [editor markdown com preview]                          │
└────────────────────────────────────────────────────────┘
```

**Componentes:** C4 (autocomplete treino-modelo), C7 (agenda semanal).

**DoD:**
- [ ] Agenda por dia da semana com dropdown de tipo
- [ ] Ao escolher `tipo=treino`, dropdown adicional de treino-modelo
- [ ] Preview de exercícios/séries por dia
- [ ] Volume semanal calculado
- [ ] Backward compat com `treinosModeloIds[]` legado
- [ ] `verTemplatePrograma` @11404 continua funcionando

---

### 6.7. ❼ Produtos — ✅ ok

Editor completo com 4 blocos ([produtoEditorHtml @11591](../index.html#L11591)):
Identidade / Clínica / Segurança / Códigos avançados (accordion).
Visualizador esconde campos vazios. Sem correções necessárias no
editor em si.

**Ajuste (opcional):** botão "importar do catálogo ANVISA" já existe
via `renderPainelCatalogoOficial('produtos')` — só verificar
descoberta pelo usuário.

---

### 6.8. ❽ Fórmulas — ✅ padrão de referência

Não modificar. É o blueprint dos outros editores de Nível 2 (§4).

---

### 6.9. ❾ Templates de Prescrição — decisão pendente

**Estado atual:** [templatePrescricaoEditorHtml @12081](../index.html#L12081).
Editor rico com 6 seções (identificação, prescrição base, campos
específicos, segurança, acompanhamento, observações). Mas é **template
textual** — não compõe Produtos/Fórmulas como itens.

**Decisão de produto pendente** (§8.2 do doc anterior):

- **Opção A** — manter textual. Fica coerente com "protocolo de
  referência". Sem mudança neste doc.
- **Opção B** — evoluir para composicional (`itens: [{tipo:'produto|
  formula', ref_id, ...posologia}]`). Fica coerente com os outros
  Níveis 3. Precisa nova seção neste doc e migration.

**Ação recomendada:** decidir com o time clínico antes de qualquer
mudança. Se opção B, refinar este doc com seção 6.9 completa.

---

### 6.10. ❿ Exames — ✅ ok

Editor completo com 5 blocos ([exameEditorHtml @12280](../index.html#L12280)):
principais, coleta/preparo, resultado, componentes, referências.
Sem correções necessárias no editor em si.

**Ajuste único:** LOINC/TUSS/CBHPM não são expostos no editor manual
(só via import). Se profissional quiser adicionar manualmente, precisa
adicionar os 4 campos no bloco "Interoperabilidade" (opcional, ver
`03-DADOS.md` §2.3).

---

### 6.11. ⓫ Modelos de Solicitação — ⚠ trocar 1 `<select>`

**Estado atual:** [modeloExamesEditorHtml @12520](../index.html#L12520).
Editor CORRETO em quase tudo — grupos + itens com obrigatório/opcional
+ observação. **Único problema:** ao adicionar exame ao grupo, o widget
é `<select>` HTML com 500+ opções ativas (`grupoModeloHtml @12529`).
Trava o browser em cadastros grandes.

**Mudança necessária:** trocar o `<select>` por autocomplete
(componente **C5**).

```
── Grupo 1: Metabolismo glicêmico ──
[✓ obrig] Glicemia de jejum  (soro)     [obs...] ×
[✓ obrig] Insulina           (soro)     [obs...] ×
[  opc ] HbA1c              (sangue T.) [obs...] ×

+ Adicionar exame ao grupo:
[autocomplete via AutonDB.buscarExames(q, {limit:20})]  [+ Adicionar]
```

**Reaproveitar:** padrão do modal `ex_selecao` @13022.

**DoD:**
- [ ] Autocomplete substitui o `<select>` em `grupoModeloHtml`
- [ ] `addExameAoGrupo` @12547 aceita o novo widget
- [ ] Comportamento de dedup (§ "jaTem") preservado

---

## 7. Integridade referencial entre cadastros

Hoje excluir um item de Nível N−1 deixa refs órfãs silenciosas nos
consumidores de Nível N. Precisa proteção.

**Relações a proteger:**

```
Alimento              → Refeição-modelo (via itens[].alimentoId)
Refeição-modelo       → Template de Plano (via agenda_diaria[].refeicaoModeloId)
Exercício             → Treino-modelo (via itens[].exercicioId)
Treino-modelo         → Template de Programa (via agenda_semanal.{dia}.treinoModeloId)
Produto               → Fórmula (via componentes[].produto_id)
Exame                 → Modelo de Solicitação (via grupos[].exames[].exameId)
```

**Ação para cada `excluirX(id)`:**

```js
function excluirRefeicaoModelo(id) {
  const consumidores = allTemplatesPlano()
    .filter(tp => (tp.agenda_diaria || []).some(r => r.refeicaoModeloId === id)
               || (tp.refeicoesModeloIds || []).includes(id));
  if (consumidores.length) {
    const msg = `Esta refeição é usada em ${consumidores.length} template(s):\n`
              + consumidores.map(c => `  · ${c.nome}`).join('\n')
              + `\n\nO que deseja fazer?`;
    const ok = confirm(msg + '\n\nOK = excluir e limpar refs / Cancel = manter');
    if (!ok) return;
    // limpar refs órfãs
    consumidores.forEach(tp => {
      tp.agenda_diaria = (tp.agenda_diaria || []).filter(r => r.refeicaoModeloId !== id);
      tp.refeicoesModeloIds = (tp.refeicoesModeloIds || []).filter(rid => rid !== id);
    });
  }
  state.cadastros.refeicoes_modelo = allRefeicoesModelo().filter(x => x.id !== id);
  scheduleSave(); RENDERERS.cadastroRefeicoes();
}
```

Aplicar o mesmo padrão a: `excluirAlimento`, `excluirExercicio`,
`excluirTreinoModelo`, `excluirProduto`, `excluirExame`.

**Padrão-guia já existe:** `__carregarSeedsTreino` @4461+ remove
templates de programa cujos `treinosModeloIds` não existem mais no
boot. Extrair a lógica como `_limparRefsOrfas()` global e chamar em
todos os excluires.

---

## 8. Padronização visual

Regras válidas em **todos** os editores de cadastro:

1. **Sem emojis** nos `ai-panel` (herdados do design antigo — remover).
2. **Sem modal aninhado** — busca secundária vira dropdown flutuante inline (padrão C1-C5), nunca segundo modal.
3. **`<select multiple>` HTML nativo proibido**.
4. **Reordenar via setas ↑↓** no mínimo (drag opcional).
5. **Preview lateral quando útil** — kcal/volume/macros à direita.
6. **Nenhuma mensagem apologética** ("feature em desenvolvimento", "por enquanto edita só cabeçalho") — remover conforme cada editor for completado.
7. **Botões-padrão:** `[Cancelar]` (secundário) + `[Salvar]` (primário) no rodapé do modal, alinhados à direita.
8. **Salvar** sempre com `scheduleSave()` + `closeModal()` + `RENDERERS.<sub-cadastro>()`.

---

## 9. Migrações de schema

Duas evoluções de schema exigem migração de dados existentes no
`localStorage['autonState_v1']` dos usuários que já usaram o app.

Adicionar no boot, junto das migrações existentes ([index.html:6248+](../index.html#L6248)).

### 9.1. Template de Plano: `refeicoesModeloIds[]` → `agenda_diaria[]`

```js
allTemplatesPlano().forEach(tp => {
  if (!tp.agenda_diaria && Array.isArray(tp.refeicoesModeloIds) && tp.refeicoesModeloIds.length) {
    const n = tp.refeicoesModeloIds.length;
    // distribuição corrigida (fecha 100 exatamente)
    const base = Math.floor(100 / n);
    const resto = 100 - (base * n);
    tp.agenda_diaria = tp.refeicoesModeloIds.map((rid, i) => ({
      ordem: i + 1,
      horario: null,
      refeicaoModeloId: rid,
      pctVet: base + (i < resto ? 1 : 0),
    }));
    // mantém refeicoesModeloIds por compat, mas app novo usa agenda_diaria
  }
});
```

### 9.2. Template de Programa: `treinosModeloIds[]` → `agenda_semanal{}`

```js
allTemplatesPrograma().forEach(tpp => {
  if (!tpp.agenda_semanal && Array.isArray(tpp.treinosModeloIds) && tpp.treinosModeloIds.length) {
    const dias = ['seg','ter','qua','qui','sex','sab','dom'];
    const tms = tpp.treinosModeloIds;
    tpp.agenda_semanal = {};
    // distribui treinos, preenche resto com descanso
    dias.forEach((d, i) => {
      tpp.agenda_semanal[d] = i < tms.length
        ? { tipo: 'treino', treinoModeloId: tms[i] }
        : { tipo: 'descanso' };
    });
  }
});
```

**Nota:** rodar essas migrações uma única vez por versão do seed
(incrementar `SEED_VERSION` ou adicionar `_seed_alimentacao_v` /
`_seed_treino_v` — padrão já em uso em §6.3 de `03-DADOS.md`).

---

## 10. Ordem de implementação e Definition of Done

### 10.1. Ordem obrigatória

| # | Passo | §  | Esforço | Depende |
|:-:|---|:-:|:-:|:-:|
| 0 | Deduplicar 3 renderers | §3.1 | 🟢 30 min | — |
| 1 | Extrair 8 componentes reutilizáveis (esqueleto) | §5 | 🟡 4h | 0 |
| 2 | Refeição-modelo — editor completo | §6.2 | 🟡 2h | 1 (C1, C8) |
| 3 | Treino-modelo — editor completo + refactor contexto | §6.5 | 🟡 3h | 1 (C2) |
| 4 | Template de Plano — metadados + agenda diária | §6.3 | 🔴 4h | 1 (C3, C6, C8), 9.1 |
| 5 | Template de Programa — agenda semanal | §6.6 | 🟡 2h | 1 (C4, C7), 9.2 |
| 6 | Modelo de Solicitação — autocomplete no add exame | §6.11 | 🟢 1h | 1 (C5) |
| 7 | Integridade referencial em todos os excluires | §7 | 🟡 2h | 2,3,4,5,6 |
| 8 | Migrations no boot | §9 | 🟢 30 min | 4,5 |
| 9 | Padronização visual em todos os editores | §8 | 🟢 1h | tudo |
| 10 | Ajustes menores (Alimentos, Exercícios, Produtos, Exames) | §6.1/6.4/6.7/6.10 | 🟢 1h | 9 |

**Total estimado:** ~21h (~2,5 dias de dev experiente).

### 10.2. DoD global

- [ ] `grep -c 'RENDERERS\..\+ = function' index.html` retorna 0 duplicações.
- [ ] Nenhum `<select multiple>` HTML em nenhum editor.
- [ ] Nenhuma mensagem "feature em desenvolvimento" restante.
- [ ] Todos os 11 sub-cadastros abrem, editam, salvam sem console.error.
- [ ] Cada editor de Nível 2 permite criar item com composição completa via UI.
- [ ] Cada editor de Nível 3 preserva metadados clínicos ricos ao salvar.
- [ ] Migrações rodam idempotentemente no boot.
- [ ] Excluir Nível N−1 avisa consumidores no Nível N.
- [ ] Testes de fumaça: criar Refeição → usar em Template de Plano → aplicar em Paciente → Instrumento emitido corretamente.

---

## Anexo A · Comandos úteis para o dev

### Detectar duplicações restantes

```sh
grep -oE 'RENDERERS\.[a-zA-Z_]+' auton-v2/index.html | sort | uniq -c | sort -rn | awk '$1 > 1'
```

Também para editores/renderers auxiliares:

```sh
grep -c 'function verTemplatePrograma' auton-v2/index.html
grep -c 'function treinoModeloEditorHtml' auton-v2/index.html
grep -c 'function templatePrgEditorHtml' auton-v2/index.html
```

### Validar contagens do state após migração

Abrir DevTools no app e rodar:

```js
console.table({
  refeicoes: allRefeicoesModelo().length,
  templates_plano: allTemplatesPlano().length,
  com_agenda_diaria: allTemplatesPlano().filter(t => t.agenda_diaria?.length).length,
  treinos_modelo: allTreinosModelo().length,
  templates_programa: allTemplatesPrograma().length,
  com_agenda_semanal: allTemplatesPrograma().filter(t => t.agenda_semanal).length,
});
```

### Detectar refs órfãs (executar antes/depois do §7)

```js
const refIds = new Set(allRefeicoesModelo().map(r => r.id));
const orfas = allTemplatesPlano().flatMap(t =>
  (t.agenda_diaria || []).filter(r => !refIds.has(r.refeicaoModeloId)).map(r => ({
    template: t.nome, refIdOrfa: r.refeicaoModeloId
  }))
);
console.table(orfas);
```

### Preview do editor antes de commitar

O ideal é ter um Storybook simples — se não tiver, criar página HTML
isolada `docs/_previews/editor-refeicao-modelo.html` que só carrega
sql.js + o snippet do editor, isolado do resto do app. Facilita
iteração sem passar pelo boot inteiro.

---

## Anexo B · Fora deste doc (para próximas correções)

Itens correlatos que ficam para outros docs:

- Bug `Math.round(100/N)` em `aplicarTemplate` @7247 → **`06-CORRECOES-FLUXO.md`** (a criar). Fica **contornado** pelo §6.3 (agenda_diaria com pctVet explícito) mas não corrigido.
- `RENDERERS.cadastros` chamando `RENDERERS.cadastros()` ao invés do sub-renderer específico (padrão de re-render largo demais) → performance, próximo doc.
- Botão "importar do catálogo oficial" ausente para Alimentos → conjunto de melhorias de importação, próximo doc.
- Discussão ontológica de Painel de Exames, Template de Prescrição composicional, Aluno como entidade → mantidas em `01-ONTOLOGIA.md`.
