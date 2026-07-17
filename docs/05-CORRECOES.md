# 05 · Correções — Composição Ontológica dos Cadastros

> **Problema-raiz:** os editores dos Níveis 2 e 3 dos 4 domínios não
> respeitam a ontologia. Regra que precisa valer em todos:
>
> **Cada Nível N precisa ter UI para selecionar itens do Nível N−1.**
>
> Hoje isso só acontece corretamente em **Prescrição → Fórmula**. Os
> outros editores ou coletam só o cabeçalho, ou usam `<select multiple>`
> HTML nativo (Ctrl+click, sem preview).
>
> Este documento é o **plano de correção**. Nada é código — são
> instruções para o dev implementar. Todas as mudanças são **UI-only**;
> os schemas já suportam o que precisa.

---

## 1. Diagnóstico — matriz atual (4 domínios × 3 níveis)

| Domínio | Nível 1 · Átomo | Nível 2 · Composto | Nível 3 · Template |
|---|---|---|---|
| **Alimentação** | Alimento — CRUD ✅ | Refeição-modelo — ❌ **só cabeçalho**, sem seletor de Alimentos | Template de Plano — ⚠️ `<select multiple>` de Refeições |
| **Treino** | Exercício — CRUD ✅ | Treino-modelo — ❌ **só cabeçalho** (nome + nível + grupos), sem seletor de Exercícios | Template de Programa — ⚠️ `<select multiple>` de Treinos-modelo |
| **Prescrição** | Produto — CRUD ✅ | Fórmula manipulada — ✅ **CORRETO** (autocomplete de Produto por componente) | Template de Prescrição — N/A (é template textual de posologia, não composição) |
| **Exames** | Exame — CRUD ✅ | (Painel não existe como cadastro — ver §5) | Modelo de Solicitação — ⚠️ tem grupos, mas add exame é `<select>` HTML |

**Legenda:** ✅ ok · ⚠️ funciona mas UI ruim · ❌ falta composição inteira

**Impacto para o usuário:**
- Não é possível criar uma Refeição-modelo completa (com alimentos e gramas).
- Não é possível criar um Treino-modelo completo (com exercícios, séries, reps, carga).
- Templates de Plano e Programa selecionam listas texto sem preview do conteúdo.
- Modelos de Solicitação de Exames dão pra montar mas o `<select>` fica travado quando há 500+ exames ativos no cadastro.

---

## 2. Padrão de referência — Editor de Fórmula Manipulada

Este editor **já implementa o padrão ontológico correto** e serve de
referência para todos os outros editores de Nível 2.

**Local:** `index.html` linhas 11715–11794 (função `formulaEditorHtml`).

### 2.1. Estrutura

```
Cabeçalho (nome, tipo farmacêutico, duração, posologia geral, observação)
└── Lista de Componentes (Nível 1 = Produto)
    ├── Linha 1: [autocomplete Produto] [dose] [obs] [×]
    │             └── vinculação com produto_id (hidden)
    │             └── indicador de vínculo (vinculado ao catálogo | texto livre)
    ├── Linha 2: ...
    └── [+ Adicionar componente]
```

### 2.2. Peças-chave a reutilizar

| Função | Linha | O que faz |
|---|---|---|
| `componenteRowHtml(c, i)` | 11725 | Renderiza cada linha de componente com input+dose+obs+botão remover |
| `buscarProdutoParaComponente(inputEl, idx)` | 11743 | Autocomplete via `AutonDB.buscarProdutos(q, {limit:8})` — dropdown flutuante |
| `selecionarProdutoComponente(prod, idx)` | 11757 | Preenche `pid` hidden, nome, auto-fill de dose com `prod.concentracao` |
| Listener de desvincular | 11768 | Se usuário edita o nome depois de vincular → remove o vínculo |
| `addComponente()` | 11737 | Adiciona nova linha vazia |

### 2.3. Regras invioláveis do padrão

1. **Autocomplete sempre que o Nível N−1 for grande** (>50 itens) — nunca `<select>` HTML nativo.
2. **Vinculação por id** — cada linha carrega hidden com `<nivel1>_id`. Isso preserva referência ao catálogo oficial mesmo quando o nome é editado.
3. **Fallback texto livre** — se o profissional edita o nome depois de vincular, o vínculo cai e vira "item em texto livre". Nunca perde o que foi digitado.
4. **Auto-fill inteligente** — quando vincula, preenche defaults derivados do item (dose = `concentracao`, gramas = medida caseira padrão, séries/reps = últimos usados, etc.).
5. **Indicador visual do vínculo** — badge verde ("vinculado ao catálogo") ou cinza ("texto livre").

---

## 3. Instruções de correção — por editor

### 3.1. 🍽️ Alimentação → Refeição-modelo

**Editor atual** (linhas 10331–10346, função `refeicaoModeloEditorHtml`):
```html
<input id="rm_nome">              [OK]
<select id="rm_cat">              [OK]
<div>Após salvar, os itens serão editáveis (em desenvolvimento).</div>
<div class="ai-panel">Este é o cadastro base — a montagem completa é feita no Plano.</div>
```

**Precisa virar:**
```
Cabeçalho: nome, categoria [MANTÉM]
── Alimentos da refeição ──
[+ Adicionar alimento]
Linha por item:
  [autocomplete Alimento] [gramas: 100] [obs] [medida caseira: 1 xíc]  [×]
  └── indicadores: vínculo TACO | badge alergeno (se paciente tem alergia) | kcal calculado
Rodapé (calculado ao vivo):
  Total: N alimentos · X kcal · P g · C g · G g · Fibra g · Sódio mg
```

**Peças a reutilizar:**
- Autocomplete de alimento — **já existe** `searchFoodInline(refId, q)` (linha 7852) usado na Etapa 7 (Montagem) do wizard de Plano. **Extrair como componente reutilizável** e usar aqui.
- Cálculo nutricional — usar `nutriRefeicao(refId)` (6644) ou `calcularRefeicao(r)` (11054).
- `MEDIDAS_CASEIRAS` (10425+) — mapa `taco_N → {q, u, g}` para conversão porção↔gramas.
- Bloqueio alergeno — `isAlergenoBlocked(alimentoId)` (7902) — desativa opções perigosas se em contexto de paciente.

**Salvar:**
```js
function salvarRefeicaoModelo(id) {
  const data = {
    nome: ...,
    categoria: ...,
    itens: [...document.querySelectorAll('.rm_item_row')].map(row => ({
      alimentoId: row.dataset.alimentoId,
      alimento_nome: row.querySelector('.rm_item_nome').value,  // snapshot
      gramas: +row.querySelector('.rm_item_gramas').value,
      obs: row.querySelector('.rm_item_obs').value,
    })).filter(it => it.alimentoId || it.alimento_nome),
  };
  // ...
}
```

**Impacto no viewer** `verRefeicaoModelo` (10298): já suporta `t.itens`
com cálculo — só passa a ter dados reais para mostrar.

---

### 3.2. 💪 Treino → Treino-modelo

**Editor atual** (linhas 11297–11322, função `treinoModeloEditorHtml`):
```html
<input id="tm_nome">              [OK]
<select id="tm_nivel">            [OK]
<checkboxes grupos musculares>    [OK — mas pode ser derivado dos exercícios]
<div>Após salvar, adicione exercícios editando individualmente.</div>
```

**Precisa virar:**
```
Cabeçalho: nome, nível [MANTÉM]
── Exercícios do treino ──
[+ Adicionar exercício]  [🤖 Sugerir com IA]
Linha por item:
  [autocomplete Exercício]  [séries: 3]  [reps: 8-12]  [carga: 20 kg]  [descanso: 60s]  [técnica ▾]  [×]
  └── indicadores: grupo primário (chip colorido) | imagem thumb | ⚠ lesão (se paciente)
Rodapé:
  Total: N exercícios · S séries · V kg volume · grupos primários: [chips]
Grupos musculares:
  [DERIVADO AUTOMATICAMENTE dos exercícios; permitir override manual]
```

**Peças a reutilizar:**
- Autocomplete de exercício — **já existe** `searchExercicioParaTreino(treinoId, value)` (5245) usado na Etapa 8 (Split+Montagem). **Extrair como componente reutilizável**.
- IA sugerir — `iaSugerirExerciciosParaTreino(treinoId)` (5251) — pega composto+isolado por grupo, params por fase/nível.
- Renderização de item — `renderExItem(treinoId, item, idx)` (5392) — já tem inputs inline de séries/reps/carga/descanso/técnica.
- `alertaLesao(ex)` (5406) — cross-check com lesões cadastradas.
- `_deriveGrupos(tm)` (4730) — deriva grupos automaticamente dos `primario` dos exercícios.
- Cálculo — `calcVolumeTreino(treinoId)` (4526).

**Salvar:**
```js
function salvarTreinoModelo(id) {
  const data = {
    nome: ...,
    nivel: ...,
    grupos: [...document.querySelectorAll('.tm_grupo_cb:checked')].map(cb => cb.dataset.grupo),
    itens: [...document.querySelectorAll('.tm_ex_row')].map(row => ({
      exercicioId: row.dataset.exercicioId,
      series: +row.querySelector('.tm_ex_series').value,
      reps: row.querySelector('.tm_ex_reps').value,
      carga: +row.querySelector('.tm_ex_carga').value,
      descanso: +row.querySelector('.tm_ex_descanso').value,
      tecnica: row.querySelector('.tm_ex_tecnica').value,
    })).filter(it => it.exercicioId),
  };
  // ...
}
```

**Impacto no viewer** `verTreinoModelo` (11285): já mostra a tabela
`#/Exercício/Séries/Reps/Carga/Descanso` — só passa a ter dados reais.

---

### 3.3. 🍽️ Alimentação → Template de Plano

**Editor atual** (linhas 11148–11151, função `templatePlanoEditorHtml`):

O que existe (`<select multiple>`):
```html
<label>Refeições-modelo (Ctrl+click para múltiplos)</label>
<select id="tp_refs" multiple size="6">
  <option value="rmn1">Café antioxidante: shake ... (cafe)</option>
  ...
</select>
```

**Precisa virar** — grid de cards clicáveis com preview e agrupamento por categoria:

```
── Refeições selecionadas (N) — 1800 kcal alvo ──
[card selecionado] Café antioxidante · cafe · 420 kcal · P30 C45 G25   [✓] [×]
[card selecionado] Almoço tradicional · almoco · 650 kcal · P35 C45 G20 [✓] [×]

── Adicionar refeições ──
Filtros: [Todas ▾] [Café] [Almoço] [Jantar] [Lanche] [Pré-treino]
Busca: [                          ]

Grid de cards por categoria:
┌─────────────────────────────┐  ┌─────────────────────────────┐
│ Café mediterrâneo           │  │ Café renal                  │
│ 🍽️ cafe                    │  │ 🍽️ cafe                    │
│ Ovos, tomate, azeitona      │  │ Tapioca leve, abobrinha, ovo│
│ 380 kcal · P22 C40 G22       │  │ 340 kcal · P18 C48 G20       │
│           [+ Adicionar]      │  │           [+ Adicionar]      │
└─────────────────────────────┘  └─────────────────────────────┘

Rodapé (calculado ao vivo com base nas selecionadas):
Total: X refeições · Y kcal · Z% do VET alvo · Distribuição P/C/G real
```

**Peças a reutilizar:**
- `calcularRefeicao(r)` (11054) — perfil nutricional por refeição.
- `categoriasRef` (mapeamento cafe→'Café da Manhã' etc — usado em `verTemplatePlano` 11068).
- `_scoreTemplateParaAluno` (4619) — modelo de card com pontuação (reaplicar padrão visual).

**Salvar:**
```js
function salvarTemplatePlano(id) {
  const data = {
    // ...campos existentes...
    refeicoesModeloIds: [...document.querySelectorAll('.tp_ref_card.selected')].map(el => el.dataset.refId),
  };
}
```

---

### 3.4. 💪 Treino → Template de Programa

Mesmo padrão do §3.3 aplicado a Treinos-modelo em vez de Refeições.

**Editor atual** (linhas 11419–11423, função `templatePrgEditorHtml`):
```html
<label>Treinos-modelo (Ctrl+click múltiplos)</label>
<select id="tpp_treinos" multiple size="6">...</select>
```

**Precisa virar:** grid de cards de Treino-modelo com:
- Nome + nível + chips de grupos musculares
- Contagem de exercícios e volume estimado
- Toggle selecionado/não
- Filtro por grupo muscular
- Preview do que tem dentro (accordion?)

**Peças a reutilizar:**
- `verTemplatePrograma` (11404) já monta accordion inline de treino → exercícios (`toggleTreinoInline`, `toggleExercicioInline`). Componente de card selecionável pode reutilizar essa preview.
- `_deriveGrupos(tm)` (4730) — para mostrar chips.
- `calcVolumeTreino` (4526) — para stat do card.

**Também:** ordem dos treinos importa (segunda, quarta, sexta...). Adicionar drag-to-reorder ou setas ↑↓ no card selecionado.

---

### 3.5. 🩺 Exames → Modelo de Solicitação (melhorar, não reescrever)

**Editor atual** (linhas 12520–12557, `modeloExamesEditorHtml` +
`grupoModeloHtml` + `addExameAoGrupo`):

Este é o **único do Nível 3 que já tem estrutura correta** — permite
grupos e itens dentro. **Mas o widget de "adicionar exame ao grupo"
usa `<select>` HTML nativo** com 500+ opções (todos os exames ativos).
Isso trava com muitos exames.

**Precisa virar:** trocar o `<select>` por autocomplete com busca
similar ao `exSearchExec(q)` do wizard de solicitação (linha 13005):

```
── Grupo 1: Metabolismo glicêmico ──
[✓ obrig] Glicemia de jejum         (soro) [obs...] [×]
[✓ obrig] Insulina                  (soro) [obs...] [×]
[  opc ] HbA1c                      (sangue total) [obs...] [×]

+ Adicionar exame ao grupo:
[busca autocomplete via AutonDB.buscarExames  ]  [+ Adicionar]
```

**Peças a reutilizar:**
- `AutonDB.buscarExames(q, {limit: 20})` (2013).
- Padrão do wizard `ex_selecao` (13022) — modal com input `exSearchInputRx` e área de resultados.

Adicional (opcional): permitir **importar de outro modelo** — "usar exames deste modelo aqui" — para compor entre modelos.

---

### 3.6. 💊 Prescrição → Template de Prescrição (ver §5)

Este editor **não é composição** de Produtos como Fórmula é. Ele é um
**template textual de posologia** com campos estruturados (dose,
frequência, horário, duração, via, associação com refeições,
contraindicações, exames de acompanhamento, protocolo em fases).

Não se aplica a mesma correção — o schema é diferente. Ver §5 para
discussão ontológica.

---

## 4. Ordem sugerida de implementação

Prioridade por **impacto no usuário** × **esforço**:

| Ordem | Editor | Impacto | Esforço | Justificativa |
|:-:|---|:-:|:-:|---|
| 1 | Refeição-modelo | 🔥 Alto | 🟢 Baixo | Reutiliza `searchFoodInline` e `calcularRefeicao`; padrão Fórmula |
| 2 | Treino-modelo | 🔥 Alto | 🟢 Baixo | Reutiliza `searchExercicioParaTreino`, `renderExItem`, `iaSugerirExerciciosParaTreino` |
| 3 | Template de Plano | 🟡 Médio | 🟡 Médio | Precisa criar padrão de "grid de cards com preview" — inédito na base |
| 4 | Template de Programa | 🟡 Médio | 🟢 Baixo | Reusa o padrão criado em (3) |
| 5 | Modelo de Solicitação | 🟢 Baixo | 🟢 Baixo | Só trocar `<select>` por autocomplete no botão "+ Adicionar exame" |

**Estimativa combinada:** um dev experiente entrega 1+2 em meio dia, 3+4
em um dia (o card grid é o único componente novo a projetar), 5 em ~2h.
**Total: ~2 dias de trabalho.**

---

## 5. Discussão ontológica pendente — questões abertas

Enquanto o dev trabalha nos editores, valem duas discussões estratégicas:

### 5.1. "Painel de Exames" deve existir como Nível 2 formal?

Hoje o cadastro de Exames tem só 2 níveis (Exame + Modelo de Solicitação).
O que o brief original chamava de "Painel" hoje aparece como:

- Exame com `tipo_exame='composto'` (ex: Hemograma agrupando HB, HT, leucócitos como `componentes[]`) — LOINC oficial.
- Grupo dentro de um Modelo de Solicitação (ex: "Metabolismo glicêmico" agrupando 4 exames).

**Pergunta:** ganharíamos algo criando um cadastro separado "Painel"
como Nível 2? Prós: reutilização entre modelos ("Perfil lipídico" pode
aparecer em vários modelos). Contras: mais uma entidade pra manter e
duplicação parcial com "composto" LOINC.

**Sugestão:** manter 2 níveis por enquanto. Se aparecer necessidade
real (mesmo painel em N modelos), então promove.

### 5.2. Template de Prescrição vs Fórmula — quando usar cada um?

A Fórmula (Nível 2) já compõe Produtos. O Template de Prescrição
(Nível 3) **não compõe Fórmulas nem Produtos** hoje — ele é um
"protocolo de prescrição" texto com metadados clínicos.

**Isso é intencional?** Ou o Template de Prescrição deveria também
poder referenciar Produtos/Fórmulas como itens (do jeito que o wizard
`rx_itens` faz)?

**Cenário ideal:**
```
Template "Tratamento SIBO — 4 semanas"
├── Item 1: Fórmula manipulada "Berberina + Alicina 500 mg" · 1 cáp 2×dia · 30d
├── Item 2: Produto "Rifaximina 550mg" · 1 comp 3×dia · 14d
├── Item 3: Fórmula "Enzimas digestivas plus" · 1 cáp antes de cada refeição · 30d
└── Instruções ao paciente: [texto]
```

Se o time endossar essa direção, o Template de Prescrição vira o
**Nível 3 composicional** do domínio Prescrição, coerente com os
outros 3 domínios. Pergunta clínica/de produto para o time definir.

### 5.3. "Aluno" ainda vai virar entidade separada?

Documentado em `01-ONTOLOGIA.md` §2.1 — hoje "Aluno" é só label para
Paciente no contexto de Treino. Se o produto for expandir para
academias/estúdios (onde aluno ≠ paciente), precisa evoluir o modelo
ontológico. Pergunta para o time de produto.

---

## 6. Checklist para a equipe

Cada editor a corrigir precisa passar por:

- [ ] Editor coleta itens do Nível N−1 (não só cabeçalho)
- [ ] Autocomplete usa a base oficial correspondente (TACO / freedb / ANVISA / LOINC via AutonDB)
- [ ] Cada item é vinculado por `id` (não só nome), com fallback para texto livre
- [ ] Cada item guarda os campos do relacionamento (gramas / séries+reps+carga / dose)
- [ ] Cálculo agregado ao vivo (kcal total / volume total / N itens)
- [ ] Preview visual do que já foi adicionado (não só lista texto)
- [ ] Botão remover por item e reordenar (opcional)
- [ ] Ao salvar, escreve em `itens[]` no schema (já existe!)
- [ ] Viewer (`verX`) mostra o conteúdo real (já preparado — só precisa dados)
- [ ] Nenhum uso de `<select multiple>` HTML nativo — sempre autocomplete ou grid de cards
