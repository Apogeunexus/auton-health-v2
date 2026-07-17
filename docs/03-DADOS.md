# 03 · Dados

> Descrição completa do que existe em `data/auton.db`, dos seeds inline
> no `index.html`, dos JSONs em `data/seeds/`, do CSV opcional e do
> `localStorage`. Cada tabela com campos, contagem real e proveniência.

---

## 1. Panorama

O Auton Health armazena dados em **quatro camadas** com regras de
autoridade distintas:

| Camada | Onde | Autoridade | Escrita pela UI? |
|---|---|---|---|
| **SQLite catálogo oficial** | `data/auton.db` (~127 MB) | Read-only pela UI. Alterado apenas pelo pipeline ETL. | Não. |
| **Seeds inline no HTML** | Constantes `PRODUTOS_SEED`, `EXAMES_SEED`, etc. | Fallback quando SQLite não está pronto. | Não (código-fonte). |
| **Seeds JSON externos** | `data/seeds/*.json` | Curados. Carregados no boot. | Não (código-fonte). |
| **State do consultório** | `localStorage['autonState_v1']` | Mutável pelo profissional. | Sim (via wizards e cadastros). |

**Chave de tema** — `localStorage['auton-theme']` (separada, não é
resetada pelo `reset()`).

---

## 2. `data/auton.db` — SQLite embarcado

**Tamanho:** ~127 MB.
**Engine:** sql.js 1.14.1 (WASM, no browser).
**Modo de uso:** carregado em memória via `fetch → Uint8Array →
new SQL.Database(buf)`.

### 2.1. Contagem por tabela (em 2026-07-16)

| Tabela | Linhas | Descrição |
|---|---:|---|
| `alimentos` | **597** | TACO 4ª ed. Unicamp. |
| `produtos` | **53.717** | Medicamentos + suplementos + fitoterápicos ANVISA. |
| `exames` | **98.554** | LOINC + TUSS + CBHPM + SIGTAP + curados. |
| `categorias` | 34 | Taxonomia (medicamento, suplemento, bioquimica, hematologia…). |
| `fontes` | 23 | Proveniência de dados. |
| `exames_fts` | 98.554 | Índice FTS5 (populado mas **não usado** — ver §7). |
| `produtos_fts` | 53.717 | Idem. |
| `subcategorias` | 0 | Vazio. |
| `produtos_precos` | 0 | Vazio (CMED não populado). |
| `produtos_sinonimos` | 0 | Vazio. |
| `produtos_alergenos` | 0 | Vazio. |
| `formulas_componentes` | 0 | Fórmulas vivem no localStorage; tabela reservada. |
| `exames_componentes` | 0 | Vive no localStorage (`state.cadastros.exames[].componentes`). |
| `exames_referencias` | 0 | Idem. |
| `exames_sinonimos` | 0 | Idem. |
| `modelos_exames` | 0 | Vive no localStorage. |
| `modelos_exames_itens` | 0 | Idem. |
| `crosswalk_medicamentos` | 0 | Reservada. |
| `crosswalk_exames` | 0 | Reservada. |
| `crosswalk_pendencias` | 0 | Reservada. |
| `sqlite_sequence` | 0 | Interna. |

**Views:** `view_produtos_com_preco`, `view_exames_resumo`,
`view_modelos_exames_resumo`.

**Índices:** 25 índices btree (categoria, ATC, LOINC, TUSS, DCB, EAN13,
GGREM, status, sinônimo texto, etc.).

### 2.2. `produtos` — schema

```sql
CREATE TABLE produtos (
    id                    TEXT PRIMARY KEY,       -- 'm09', 's11', 'p_abc123'
    categoria             TEXT NOT NULL,          -- FK categorias.key
    subcategoria          TEXT,
    nome                  TEXT NOT NULL,
    nome_alternativo      TEXT,
    fabricante            TEXT,
    codigo_interno        TEXT,                   -- SKU próprio da clínica

    -- Campos comuns (promovidos do atributos_json)
    principio_ativo       TEXT,
    concentracao          TEXT,
    forma_farmaceutica    TEXT,
    apresentacao          TEXT,
    classe_terapeutica    TEXT,
    tarja                 TEXT,
    marco_regulatorio     TEXT,

    -- Agregação de marcas (dedup clínico por composição)
    marcas                TEXT,                   -- "marca1; marca2; ..."
    marcas_count          INTEGER,

    -- Interoperabilidade / crosswalk universal
    codigo_ean13          TEXT,
    codigo_dcb            TEXT,                   -- Denominação Comum Brasileira
    codigo_atc            TEXT,                   -- WHOCC ATC 5 níveis
    codigo_unii           TEXT,                   -- FDA UNII
    codigo_rxcui          TEXT,                   -- RxNorm CUI
    codigo_chebi          TEXT,
    codigo_pubchem_cid    TEXT,
    codigo_registro_anvisa TEXT,                  -- 13 dígitos
    codigo_ggrem          TEXT,                   -- CMED

    fonte                 TEXT NOT NULL,          -- FK fontes.key
    fonte_versao          TEXT,
    status                TEXT NOT NULL DEFAULT 'ativo',
    origem_registro       TEXT NOT NULL DEFAULT 'oficial',

    created_at            TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Blob JSON de atributos específicos por categoria
    atributos_json        TEXT,

    FOREIGN KEY (categoria) REFERENCES categorias(key),
    FOREIGN KEY (fonte)     REFERENCES fontes(key)
);
```

**status ∈** `ativo | rascunho | inativo | arquivado`.
**origem_registro ∈** `oficial | curadoria | personalizado`.

### 2.3. `exames` — schema

```sql
CREATE TABLE exames (
    id                    TEXT PRIMARY KEY,       -- 'ex001', 'loinc_2345-7', 'tuss_40301010'
    nome                  TEXT NOT NULL,
    sigla                 TEXT,
    nome_tecnico          TEXT,                   -- nome oficial LOINC
    descricao             TEXT,

    categoria             TEXT NOT NULL,          -- FK categorias.key
    subcategoria          TEXT,

    tipo_exame            TEXT NOT NULL,          -- individual|painel|composto
    tipo_resultado        TEXT NOT NULL,          -- decimal|inteiro|percentual|indice|
                                                  -- pos_neg|det_naodet|reag_naoreag|
                                                  -- pres_aus|texto_livre|lista_opcoes|composto

    -- Coleta e preparo
    material              TEXT,                   -- 'soro', 'sangue total (EDTA)'
    jejum                 INTEGER DEFAULT 0,      -- boolean
    jejum_horas           TEXT,                   -- '8 a 12h'
    horario_preferencial  TEXT,
    restricoes            TEXT,
    obs_paciente          TEXT,
    obs_profissional      TEXT,

    -- Resultado
    unidade               TEXT,
    casas_decimais        INTEGER,
    opcoes_resultado      TEXT,                   -- JSON array

    -- Interoperabilidade
    codigo_loinc          TEXT,
    codigo_tuss           TEXT,                   -- ANS 8 dígitos
    codigo_cbhpm          TEXT,                   -- AMB
    codigo_sus            TEXT,                   -- SIGTAP

    fonte                 TEXT NOT NULL,
    fonte_versao          TEXT,
    status                TEXT NOT NULL DEFAULT 'ativo',

    created_at            TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    atributos_json        TEXT,

    FOREIGN KEY (categoria) REFERENCES categorias(key),
    FOREIGN KEY (fonte)     REFERENCES fontes(key)
);
```

### 2.4. `alimentos` — schema (TACO)

Composição centesimal por 100 g de porção comestível. Muitos campos NULL
para alimentos sem análise completa.

```sql
CREATE TABLE alimentos (
    id                    TEXT PRIMARY KEY,       -- 'taco_1', 'taco_2', ...
    codigo                TEXT,                   -- número TACO oficial
    nome                  TEXT NOT NULL,
    grupo                 TEXT,                   -- 'Cereais e derivados', 'Frutas', ...
    fonte                 TEXT NOT NULL DEFAULT 'taco_unicamp_4ed',

    -- Composição centesimal
    umidade_g             REAL,
    energia_kcal          REAL,
    energia_kj            REAL,
    proteina_g            REAL,
    lipidios_g            REAL,
    colesterol_mg         REAL,
    carboidrato_g         REAL,
    fibra_g               REAL,
    cinzas_g              REAL,

    -- Minerais (mg/100g)
    calcio_mg, magnesio_mg, manganes_mg, fosforo_mg,
    ferro_mg, sodio_mg, potassio_mg, cobre_mg, zinco_mg,

    -- Vitaminas
    retinol_mcg, re_mcg, rae_mcg,
    tiamina_b1_mg, riboflavina_b2_mg, piridoxina_b6_mg,
    niacina_mg, vitamina_c_mg,

    -- Ácidos graxos (g/100g)
    ag_saturados_g, ag_mono_g, ag_poli_g,

    -- Aminoácidos (g/100g) — 18 no total
    aa_triptofano_g, aa_treonina_g, aa_isoleucina_g, aa_leucina_g,
    aa_lisina_g, aa_metionina_g, aa_cistina_g, aa_fenilalanina_g,
    aa_tirosina_g, aa_valina_g, aa_arginina_g, aa_histidina_g,
    aa_alanina_g, aa_ac_aspartico_g, aa_ac_glutamico_g, aa_glicina_g,
    aa_prolina_g, aa_serina_g,

    created_at            TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

### 2.5. `categorias` e `fontes` — taxonomias

```sql
CREATE TABLE categorias (
    key         TEXT PRIMARY KEY,     -- 'medicamento', 'suplemento', 'bioquimica'
    dominio     TEXT NOT NULL,        -- 'prescricao' | 'exame'
    label       TEXT NOT NULL,
    icone       TEXT,
    cor         TEXT,
    profissoes  TEXT,                 -- JSON — quem pode prescrever
    ordem       INTEGER DEFAULT 0
);

CREATE TABLE fontes (
    key                TEXT PRIMARY KEY,
    nome               TEXT NOT NULL,
    url                TEXT,
    tipo               TEXT NOT NULL,     -- oficial | comercial | acadêmica | curadoria
    licenca            TEXT,
    permite_comercial  INTEGER DEFAULT 1,
    pais               TEXT DEFAULT 'BR',
    dominio            TEXT NOT NULL,     -- prescricao | exame | ambos
    prioridade         INTEGER DEFAULT 5, -- 1=alta, 5=baixa
    atualizacao        TEXT,              -- mensal | trimestral | anual | contínua | estática
    volume_estimado    INTEGER,
    observacao         TEXT
);
```

### 2.6. Sub-entidades reservadas mas vazias

Tabelas no schema mas com 0 linhas. Existem para o pipeline ETL preencher,
ou para migração futura da fonte-de-verdade das entidades correspondentes
do localStorage para o SQLite.

- **produtos_sinonimos** — sinônimo, nome popular, marca comercial, nome alternativo.
- **produtos_alergenos** — `(produto_id, alergeno)` PK composta.
- **produtos_precos** — histórico CMED (PF + PMC por 8 alíquotas de ICMS).
- **formulas_componentes** — componente de fórmula manipulada.
- **exames_componentes** — componentes de exame composto.
- **exames_referencias** — faixas de referência por sexo/idade.
- **exames_sinonimos** — sinônimos multilíngues.
- **modelos_exames** e **modelos_exames_itens** — modelos de solicitação com grupos.
- **crosswalk_medicamentos** — DCB, UNII, CAS, RxCUI, ATC, MeSH, SNOMED, InChIKey, INN.
- **crosswalk_exames** — LOINC↔TUSS↔CBHPM↔SUS↔SNOMED.
- **crosswalk_pendencias** — log de falhas de enriquecimento.

### 2.7. Views SQL

**view_produtos_com_preco** — junta `produtos` com o preço CMED mais
recente (`produtos_precos` com `MAX(data_referencia)`).

**view_exames_resumo** — `exames.*` + `n_componentes` + `n_referencias`
(subquery COUNT).

**view_modelos_exames_resumo** — `modelos_exames.*` + `total_exames` +
`total_grupos`.

### 2.8. FTS5

**Tabelas populadas mas não usadas pela UI atual** (ver §7):

```sql
CREATE VIRTUAL TABLE produtos_fts USING fts5(
    produto_id UNINDEXED,
    nome, sinonimos, principio_ativo, nome_cientifico,
    fabricante, categoria, codigo_dcb, codigo_atc, codigo_ean13,
    tokenize = 'porter unicode61 remove_diacritics 2'
);

CREATE VIRTUAL TABLE exames_fts USING fts5(
    exame_id UNINDEXED,
    nome, sigla, sinonimos, nome_tecnico, categoria, material,
    codigo_loinc, codigo_tuss,
    tokenize = 'porter unicode61 remove_diacritics 2'
);
```

O sql.js oficial (`sql-wasm.js` no `lib/`) **não vem compilado com FTS5**,
então mesmo com essas tabelas populadas, o `MATCH` retornaria erro. A UI
usa `LOWER(col) LIKE '%q%'` puro.

---

## 3. Seeds inline no `index.html`

Grandes constantes JavaScript declaradas no próprio HTML. Usadas como
fallback quando o AutonDB não carrega ou como dados-de-partida para
funcionalidades que ainda não migraram para SQLite.

| Constante | Linhas (aprox.) | Contagem | Uso |
|---|---|---:|---|
| `PRODUTOS_SEED` | 2822–3031 | ~137 | Fallback de `state.cadastros.produtos`. Curadoria manual. |
| `FORMULAS_SEED` | 3034 | **0** | Comentário: "zerado. Vamos recomeçar com nova estratégia." |
| `TEMPLATES_PRESCRICAO_SEED` | 3037 | **0** | Comentário: "zerado. Vamos recomeçar." |
| `GRUPOS_CLINICOS_TP` | 3038 | **0** | Filtro sem opções. |
| `EXAMES_SEED` | 3107–3486 | 186 | Exames curados (ex1..ex186). Fallback local. |
| `MODELOS_EXAMES_SEED` | 3488–4258 | 44 | Modelos de solicitação (me1..me44). |
| `EXERCICIOS_SEED` | 4342 | **0** | Vazio — freedb via JSON. |
| `TREINOS_MODELO_SEED` | 4458 | **0** | Vazio — seed via JSON. |
| `TEMPLATES_PROGRAMA_SEED` | 4459 | **0** | Vazio — seed via JSON. |
| `ALIMENTOS_SEED` | — | (via SQLite) | 597 do TACO. |
| `REFEICOES_MODELO_SEED` | — | ~30 | Refeições curadas. |
| `TEMPLATES_PLANO_SEED` | ~2559+ | ~5 | tpn1, tpn5, tpn16, tpn72, tpn86. |

### 3.1. Metadados taxonômicos inline

**Categorias:**
- `CATEGORIAS_PRESCRICAO` (10 categorias — linha 2669).
- `CATEGORIAS_EXAME` (24 categorias com key/label/color/subs — linhas 3043–3068).

**Schemas dinâmicos:**
- `SCHEMAS_PRESCRICAO[categoria]` (2747–2820) — define campos por categoria de produto.
- `CAMPOS_COMUNS_PRODUTO` (2711–2717).
- `CAMPOS_OBS` (2720–2726).
- `CAMPOS_INTEROP` (2729–2738).
- `CAMPOS_POSOLOGIA = []` (2744) — **regra: produto não tem posologia**.

**Opções de campo:**
- `TIPOS_EXAME` (3), `TIPOS_RESULTADO` (11), `MATERIAIS_BIOLOGICOS` (21),
  `UNIDADES_MEDIDA` (37).
- `OPCOES_FORMA_FARMACEUTICA`, `OPCOES_UNIDADE`, `OPCOES_FREQUENCIA`,
  `OPCOES_VIA`, `OPCOES_ASSOCIACAO_REFEICOES`, `OPCOES_NIVEL_EVIDENCIA` (11951–11961).
- `FONTES_DADOS` (17 opções — linha 2683).

**Alimentação/Treino:**
- `FATORES_ATIVIDADE` (2350) — 5 níveis com multiplicadores.
- `OBJETIVOS` (2358) — 10 objetivos nutricionais.
- `FORMULAS` (2371) — 6 fórmulas de TMB.
- `STEPS` (2261) + `PHASES` (2273) — plano.
- `STEPS_TREINO` (2281) + `PHASES_TREINO` (2296) — treino.
- `STEPS_RX` (2306) + `PHASES_RX` (2320) — prescrição.
- `STEPS_EX` (2322) + `PHASES_EX` (2334) — exames.
- `FLUXOS` (2337) — mapa dos 4 wizards.
- `GRUPOS_MUSCULARES` (2653) + `GRUPOS_MUSC` (4319) — 10 grupos (duplicação).
- `SPLITS` (linha 4310), `OBJETIVOS_TREINO` (4284), `FASES_PERIODIZACAO`
  (4295), `NIVEIS_TREINO`, `FREEDB_MAP` (4352).
- `SPLITS_LABELS`, `OBJETIVOS_LABELS_PT`, `FASES_LABELS` (11331–11333) —
  duplicação para cadastros.

**Alimentos:**
- `MEDIDAS_CASEIRAS` (10425+) — dicionário `taco_N → {q, u, g}` para
  conversão porção↔gramas.

---

## 4. Seeds JSON externos

Carregados no boot via `fetch()`.

### 4.1. `data/exercicios_freedb.json` (1.5 MB)
Base pública **free-exercise-db** (Unlicense — domínio público).
**~873 exercícios**.

Loader: `window.__carregarExerciciosFreeDB()` (linha 4378) — fetch,
mapeia EN→PT via `FREEDB_MAP`, dedup por nome normalizado (`_normNome`),
mescla em `state.cadastros.exercicios` como `freedb_*` ids. Também
limpa treinos-modelo com refs quebradas.

**Formato de cada exercício** (após tradução):
```
{
  id: 'freedb_<n>' | 'ex_<hash>',
  nome: string (PT),
  nome_en: string,
  primario: [grupo],
  secundario: [grupo],
  equip: [equipamento],
  padrao: 'empurrar_horizontal' | 'empurrar_vertical' |
          'puxar_horizontal' | 'puxar_vertical' | 'agachar' |
          'dobrar' | 'rotacionar' | 'estabilizar',
  nivel: 'iniciante' | 'intermediario' | 'avancado',
  tipo: 'composto' | 'isolado' | 'isometrico',
  categoria: string,
  instrucoes: [string],
  instrucoes_en: [string],
  imagens: [url],           // GitHub raw
  fonte: 'free-exercise-db'
}
```

**Imagens:** hot-linked de `FREEDB_IMG_CDN =
'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/'`
(linha 4350). O app não hospeda mídia.

### 4.2. `data/seeds/treinos_modelo.json` (197 KB)
20 treinos-modelo curados (124 prescrições de exercício, todas
referenciando IDs reais do freedb).

Loader: `window.__carregarSeedsTreino()` (linha 4461).

### 4.3. `data/seeds/templates_programa.json` (61 KB)
16 templates de programa curados:
- 6 hipertrofia
- 4 emagrecimento
- 2 saúde geral
- 2 força
- 1 condicionamento
- 1 reabilitação

Loader: mesma função `__carregarSeedsTreino()`.

**Importação manual pelo usuário:** documentada em
`data/seeds/importar.md` — bloco JS que faz `fetch` dos dois JSONs, dedup
por id, `scheduleSave()`, re-renderiza.

### 4.4. Backups locais

`data/seeds/treinos_modelo.json.bak_68` e
`data/seeds/templates_programa.json.bak_68` — snapshots antigos
mantidos manualmente (sem VCS).

---

## 5. CSV externos opcionais

`loadCadastrosFromCSV()` (linha 12686) tenta carregar 6 arquivos CSV
opcionais em `./data/*.csv`; se algum estiver presente e não-vazio,
sobrescreve o seed correspondente e marca
`state.cadastros.__sources.<tipo> = 'CSV externo · N registros'`.

Chamado no boot final (linha 13145).

| CSV esperado | Alimenta |
|---|---|
| `data/produtos.csv` | `state.cadastros.produtos` |
| `data/exames.csv` | `state.cadastros.exames` (headers principais) |
| `data/exames_componentes.csv` | mescla em `exames[].componentes` por `exame_id` |
| `data/exames_referencias.csv` | mescla em `exames[].referencias` por `exame_id` |
| `data/modelos_exames.csv` | `state.cadastros.modelos_exames` (headers) |
| `data/modelos_itens.csv` | mescla em `modelos_exames[].grupos[].exames` |

**Exportação:** `exportarCSVsCadastros()` (12745) gera os mesmos 6 CSVs
a partir do state atual.

**Nenhum desses CSVs existe no diretório atualmente** — funcionalidade
disponível mas dormente.

---

## 6. `localStorage['autonState_v1']`

Chave única. Persistência via `save()` (6519) chamada por `scheduleSave()`
(debounce 500 ms).

### 6.1. Chaves de topo

```
state = {
  __seed: 'auton-v2-unified',     // gate de compatibilidade
  currentStep: 'pacientes',       // rota ativa

  // Modelo ontológico atual
  pacientes: [{...}],
  pacienteAtivoId: null,
  pacienteDetalheTab: 'visao-geral',
  pacienteDetalheSubTab: null,
  pacientesFiltro: { q: '', status: 'todos' },
  contextoInstrumento: null,       // set durante wizard de paciente

  // Modelo LEGADO — sub-state single-paciente do wizard de plano
  paciente:  {nome, idade, sexo, dataNasc},
  atendimento: {tipo, data},
  anamnese: {...},
  avaliacao: {...},
  objetivo: {...},
  estrategia: {...},
  macros: {...},
  estrutura: {...},
  plano: {...},
  activeMealTab, activeAnamneseTab, origem_template_id,

  // Sub-states dos wizards (isolados)
  treino: { aluno, atendimento, anamnese, avaliacao, objetivo,
            periodizacao, programa, semana, split, montagem, ... },
  rx:     { atendimento, paciente, itens, observacoes, numero, dataEmissao },
  ex:     { atendimento, paciente, exames, modeloAplicado,
            observacoes, numero, dataEmissao },

  // Biblioteca de conhecimento
  cadastros: { activeTopTab, activeSubTab, categoriaFilter,
               _seed_alimentacao_v, _seed_treino_v, _sources,
               alimentos, refeicoes_modelo, templates_plano,
               exercicios, treinos_modelo, templates_programa,
               produtos, formulas, templates_prescricao,
               exames, modelos_exames },

  // Estado UI persistente
  activeTreinoTab, activeAnamneseTab, justificativasAvisos, ...
}
```

### 6.2. Sub-schemas por wizard

**state.plano** (plano alimentar em edição):
```
plano: {
  itens: { r1: [{alimentoId, gramas, obs}], ... },
  substituicoes: { 'r1:a15': [{alimentoId, gramas}], ... },
  observacoesPaciente, dataInicio, dataFim,
  validacoes: [],
  justificativasAvisos: {},
  publicado?, publicadoEm?
}
```

**state.treino** (programa de treino em edição):
```
treino: {
  aluno: { nome, idade, sexo, dataNasc, email?, telefone? },
  atendimento: { tipo, data },
  anamnese: { queixa, historicoClinico, medicamentos[],
              qualidadeSono, nivelEstresse, experienciaPrevia,
              disponibilidadeSemanal, tempoDisponivelMin, localTreino,
              preferencias[], aversoes[], objetivoDetalhado,
              lesoes[{regiao, quando, status, observacao}],
              restricoesMovimento[] },
  avaliacao: { peso, altura, dataMedicao, massaMagra, massaGorda,
               percGordura, metodoComposicao, cintura, quadril,
               dobras: { tricipital, subescapular, suprailiaca,
                         abdominal, peitoral, axilarMedia, crural },
               fc_repouso },
  objetivo: { key, descricao },
  periodizacao: { fase },
  programa: { nome, duracao_semanas, nivel },
  semana: { dias_treino, tempo_treino_min, dias_semana[] },
  split: { tipo, treinos: [{id, ordem, nome, grupos[], dia}] },
  montagem: { itens: { t1: [{exercicioId, series, reps, carga,
                             descanso, tecnica, notas}] } },
  observacoesAluno, dataInicio, activeTreinoTab, activeAnamneseTab,
  justificativasAvisos: {},
  templatePickerAberto?, _expandedTreinos?, _didInitialExpand?,
  _processandoRevisao?, avaliacaoIA?, avaliacaoIAGeradaEm?,
  observacoesRevisao?, publicado?, publicadoEm?
}
```

**state.rx** (prescrição em edição):
```
rx: {
  atendimento: { tipo: 'inicial'|'renovacao'|'ajuste', data: YYYY-MM-DD },
  paciente: { nome, idade, sexo, dataNasc, cpf, peso, altura, alergias[] },
  itens: [{ tipo: 'produto'|'formula', categoria, ref_id, ref_nome,
            dose, frequencia, horario, duracao, obs }],
  observacoes: '',
  numero: 'RX-XXXXXXXX' | null,
  dataEmissao: ISO | null
}
```

**state.ex** (solicitação de exames em edição):
```
ex: {
  atendimento: { tipo: 'inicial'|'seguimento'|'urgencia', data: YYYY-MM-DD },
  paciente: { nome, idade, sexo, dataNasc, cpf, jejum: bool },
  exames: [{ exameId, nome, obrigatorio, obs }],
  modeloAplicado: id | null,
  observacoes: '',
  numero: 'EX-XXXXXXXX' | null,
  dataEmissao: ISO | null
}
```

**state.pacientes[i]** (o modelo ontológico canônico):
```
{
  id, nome, email, telefone, cpf,
  dataNasc: 'YYYY-MM-DD', sexo: 'F'|'M',
  cidade, estado, status: 'ativo'|'inativo'|'arquivado',
  criadoEm: 'YYYY-MM-DD',

  ficha: {
    anamnese: {
      queixa, historicoClinico, antecedentesFamiliares,
      medicamentosEmUso: [], suplementos: [],
      alergias: [{agente, gravidade}],
      intolerancias: [], cirurgias: [],
      habitos: { sonoHoras, agua_ml, alcool, tabaco, intestino },
      atualizadaEm
    },
    antropometria: [{ data, peso, altura, cintura, quadril,
                      percGordura, massaMagra }],  // série temporal
    objetivo: { tipo, descricao, metaPeso, prazoMeses,
                definidoEm, status },
    estiloVida: { fatorAtividade, disponibilidadeTreinoSemanal,
                  preferencias: [], aversoes: [],
                  restricoesReligiosas: [] }
  },

  atendimentos: [{ id, data, tipo, profissional, motivo,
                   status, instrumentosIds: [] }],

  instrumentos: [{ id, tipo, emitidoEm, atendimentoId,
                   estado, resumo }]
}
```

**state.cadastros** (biblioteca do profissional):

Cada uma das 12 chaves de tipo (alimentos, produtos, exames, exercicios,
refeicoes_modelo, treinos_modelo, formulas, templates_plano,
templates_programa, templates_prescricao, modelos_exames) segue o schema
do respectivo cadastro descrito em `02-TELAS.md` §8.

### 6.3. Migrações inline

O boot roda uma sequência de sanitizações antes de `goTo(state.currentStep)`.
São migrações "por presença" — cada uma checa se um invariante é
respeitado, corrige se não é.

Principais (linhas 6248–6398 e 13122–13143):

- **SEED_VERSION gate** (6248) — se `state.__seed !== 'auton-v2-unified'`,
  descarta o storage inteiro.
- **Reseed de sub-cadastros** (`_seed_alimentacao_v`, `_seed_treino_v`) —
  6313–6350 — atualiza sem apagar o que o profissional criou.
- **Migração de `pacientes[]`** — 13124–13127 — preenche padrão se
  ausente.
- **Migração de IDs legados** — remove `formulas` com id `/^f\d+$/`
  (6302), remove `templates_prescricao` com id `/^(tp|tprc)\d+/`
  (6298).
- **`_STEP_MIGRATION`** (6737, 13129) — redireciona
  `state.currentStep` de steps removidos:
  - `t_periodizacao → t_objetivos`
  - `t_montagem → t_split`
  - `revisar_publicar → distribuicao_macros`
  - `sucesso → distribuicao_macros`
  - etc.

### 6.4. `reset()`

Função em 6529–6533:
```js
function reset() {
  localStorage.removeItem('autonState_v1');
  state = structuredClone(DEFAULT_STATE);
  goTo('inicio');
}
```

Não afeta `auton-theme`. Chamada apenas pelos CTAs "Novo atendimento"
das telas de sucesso (não há botão Sair na sidebar).

---

## 7. FTS5 vs LIKE

**Verdicto:** o app usa **LIKE em 100% das buscas**. FTS5 está
provisionado mas não é usado.

- As tabelas `produtos_fts` e `exames_fts` estão populadas no
  `data/auton.db` (~98k + 54k rows) e existem para uso futuro.
- `AutonDB.buscarProdutos(q)` e `buscarExames(q)` (linhas 1988 e 2013)
  usam `LOWER(col) LIKE '%q%'` com AND multi-termo.
- Comentário na linha 1993: *"sql.js oficial não vem com FTS5 compilado
  — usamos LIKE"*.
- Função `escapeFTS(q)` está definida (1965) mas nunca é referenciada.

**Consequências práticas:**
- Busca por prefixo funciona (`losartana` acha `losartana potássica 50 mg`).
- Ordenação `ORDER BY LENGTH(nome), nome` prioriza matches curtos.
- Não há stemming, sinônimos automáticos, nem tokenização
  `remove_diacritics`.
- Performance: até ~500 rows por render (hard limit `__HARD_LIMIT_LISTA`),
  cache 5s.

---

## 8. Pipeline de enriquecimento (planejado / parcial)

O brief cita um pipeline ETL que enriquece os 43.308 registros ANVISA
com dados de CMED (concentração, forma farmacêutica, tarja) e RxNav (ATC).

**Estado atual no `data/auton.db`:**
- ANVISA (produtos): populado — 53.717 registros (número maior que 43k
  porque inclui suplementos ANVISA-alimentos + cannabis).
- CMED (`produtos_precos`): **vazio** (0 rows). Enriquecimento não rodou.
- ATC (`codigo_atc` em `produtos`): parcial (não conferido nesta doc).
- SIGTAP (`codigo_sus` em `exames`): campo existe, populado nos 98k.

**Regras invioláveis do enriquecimento** (herdadas do brief):
- Nenhum dado ANVISA é alterado — só preenche campos vazios.
- Nada de invenção — se não achou, deixa vazio.
- Cada campo enriquecido grava fonte (`fonte_enrich`) para auditoria.
- Match apenas exato após normalização (remove "cloridrato de",
  "potássica", etc.).
- 43.308 linhas ANVISA preservadas 1:1 (sem dedup por composição).

**Fontes autorizadas** (Brasil, oficiais, uso comercial permitido):

| Fonte | URL |
|---|---|
| ANVISA Dados Abertos — Medicamentos | dados.anvisa.gov.br/dados/DADOS_ABERTOS_MEDICAMENTOS.csv |
| ANVISA Alimentos (suplementos) | dados.anvisa.gov.br/dados/DADOS_ABERTOS_ALIMENTO.csv |
| ANVISA Cannabis | dados.anvisa.gov.br/dados/TA_DA_PRODUTO_CANNABIS.CSV |
| CMED (só composição/tarja — ignorar preço) | dados.anvisa.gov.br/dados/TA_PRECOS_MEDICAMENTOS.csv |
| TACO | nepa.unicamp.br/publicacoes/tabela-taco |
| SIGTAP/DATASUS | ftp2.datasus.gov.br/pub/sistemas/tup/downloads/ |

**Fontes internacionais para códigos técnicos** (padrões mundiais):
- **LOINC** (95k exames) — loinc.org (grátis, cadastro).
- **RxNav (NIH)** para ATC — rxnav.nlm.nih.gov/REST/ (grátis, API).

**Fontes proibidas:**
- Scraping de fabricantes/e-commerce (ToS).
- Bases pagas (DrugBank, SNOMED).
- UNII (código FDA sem uso clínico BR).
- Preço CMED (fora do escopo — ignorar coluna PMC/PF).
- Qualquer fonte estrangeira para o campo Tarja/Receita (só CMED +
  Portaria SVS/MS 344/1998).

O pipeline em si vive fora do `auton-v2/` (na irmã `../auton-etl/`, que
não está no escopo desta doc).

---

## 9. Validação rápida do DB

Comando para conferir contagens em qualquer momento:

```sh
sqlite3 auton-v2/data/auton.db "
SELECT
  (SELECT COUNT(*) FROM produtos)  AS produtos,
  (SELECT COUNT(*) FROM exames)    AS exames,
  (SELECT COUNT(*) FROM alimentos) AS alimentos;
"
```

Contagens esperadas em `2026-07-16`:
- produtos: 53.717
- exames: 98.554
- alimentos: 597

---

## 10. Fluxo de leitura em runtime

Quando a UI precisa ler produtos/exames/alimentos:

1. Chama `allProdutos()` / `allExames()` / `allAlimentos()` (linhas
   6422–6486).
2. Se `AutonDB.isReady()` → chama método correspondente do AutonDB,
   grava em `__all<Tipo>Cache` (TTL 5s), hard-limit 500 rows.
3. Se AutonDB não pronto → devolve `state.cadastros.<tipo>` (seed local).
4. Evento `autondb:ready` (6491–6499) invalida caches e re-renderiza a
   tela atual.

**Escrita:** sempre em `state.cadastros.*` (localStorage). SQLite é
imutável pela UI.
