# 01 · Ontologia do Auton Health v2

> Documento mestre. Segue o método ontológico: primeiro delimita o **domínio**,
> depois identifica **entidades**, seus **atributos**, **relacionamentos**,
> **estados**, **eventos** e **regras**. Só depois passa a como isso é
> implementado (ver `02-TELAS.md` e `04-ARQUITETURA.md`).
>
> Toda afirmação sobre comportamento é rastreável ao `index.html` (13.147
> linhas) e ao `data/auton.db` (~127 MB). Números de linha citados são do
> `index.html` em `2026-07-16`.

---

## 1. Domínio

**Auton Health** é o software clínico usado por um profissional de saúde
(médico, nutricionista, personal trainer) para atender pacientes e emitir
os quatro artefatos que estruturam o cuidado:

- **Plano Alimentar**
- **Programa de Treino**
- **Prescrição** (medicamento / suplemento / fórmula manipulada)
- **Solicitação de Exames**

O software roda **localmente** no computador do profissional. Um único
`index.html` hospeda todos os fluxos. O SQLite (`auton.db`) hospeda o
conhecimento oficial reutilizável (ANVISA, TACO, LOINC, TUSS, CBHPM). O
`localStorage` do navegador hospeda o consultório: pacientes, atendimentos,
instrumentos emitidos, biblioteca pessoal do profissional.

**Não pertencem ao domínio** (não estão modelados): agendamento externo,
faturamento, telemedicina, integração com convênios, PEP compartilhado com
outra clínica, gestão de estoque.

---

## 2. Entidades

O domínio se organiza em três camadas ontológicas que se repetem em cada
domínio-clínico. É a **regra dos 3 níveis**:

| Domínio      | Nível 1 · Átomo          | Nível 2 · Composto       | Nível 3 · Modelo/Template   |
|--------------|--------------------------|--------------------------|-----------------------------|
| Alimentação  | Alimento (TACO)          | Refeição-modelo          | Template de Plano Alimentar |
| Treino       | Exercício (freedb)       | Treino-modelo            | Template de Programa        |
| Prescrição   | Produto (ANVISA/curado)  | Fórmula manipulada       | Template de Prescrição      |
| Exames       | Exame (LOINC/TUSS/CBHPM) | **[não existe]** *(ver §2.4.2)* | Modelo de Solicitação |

Além dessas 12 entidades de catálogo, há **6 entidades operacionais** que
representam o consultório:

- **Paciente** (âncora — tudo se aplica a um paciente)
- **Ficha Clínica** (composição da anamnese, antropometria, objetivo, estilo de vida — pertence ao paciente)
- **Atendimento** (evento datado; conterá 1+ instrumentos)
- **Instrumento** (o artefato emitido — Plano, Programa, Prescrição ou Solicitação — atracado num Atendimento e num Paciente)
- **Categoria** (taxonomia — medicamento, suplemento, fitoterápico, bioquímica, hematologia…)
- **Fonte** (proveniência do dado — ANVISA, TACO, LOINC, curadoria interna, freedb, CSV externo…)

### 2.1. Paciente (entidade-âncora)

> A ontologia declarada em comentário do código (linhas 8773–8776):
> `Paciente → FichaClínica + Atendimentos[] + Instrumentos[]`

**Atributos essenciais:**
- `id`, `nome`, `dataNasc` (`YYYY-MM-DD`), `sexo` (`F | M`)
- `cpf`, `email`, `telefone`, `cidade`, `estado` (UF)
- `status` (`ativo | inativo | arquivado`)
- `criadoEm` (`YYYY-MM-DD`)

**Composição** (não são atributos escalares, são sub-agregados):
- `ficha` → uma Ficha Clínica (§2.2)
- `atendimentos[]` → série temporal de Atendimentos (§2.3)
- `instrumentos[]` → todos os instrumentos emitidos para este paciente (§2.5)

**Não estão no modelo atual:** endereço detalhado (rua/número/CEP/bairro),
contato de emergência, foto, alergias globais no nível do Paciente
(alergias vivem dentro da Ficha).

**Ambiguidade resolvida — "Aluno" vs "Paciente":** o app usa a palavra
"Aluno" apenas no wizard de Treino, para acomodar a linguagem de
coaching esportivo. **Aluno NÃO é entidade separada**: é um snapshot do
Paciente pré-preenchido em `state.treino.aluno` no início do wizard. O mesmo
padrão aparece em `state.rx.paciente` (para Prescrição) e `state.ex.paciente`
(para Exames). O ID canônico está sempre em `Paciente`.

### 2.2. Ficha Clínica

Pertence a **um único** Paciente. Serve para alimentar todos os wizards com
dados clínicos que não devem ser recoletados a cada instrumento.

**Sub-agregados (4 seções):**

- **anamnese** — `queixa`, `historicoClinico`, `antecedentesFamiliares`,
  `medicamentosEmUso[]`, `suplementos[]`, `alergias[{agente, gravidade}]`,
  `intolerancias[]`, `cirurgias[]`,
  `habitos{ sonoHoras, agua_ml, alcool, tabaco, intestino }`,
  `atualizadaEm`.
  - `alcool ∈ { nao, ocasional, social, diario }`
  - `tabaco ∈ { nao, ex, atual }`
  - `intestino ∈ { diario, regular, irregular, obstipacao }`

- **antropometria** — **série temporal**: `[{ data, peso, altura, cintura,
  quadril, percGordura, massaMagra }]`. IMC é sempre derivado (nunca
  armazenado). Dobras cutâneas não moram aqui; ficam em `state.treino.avaliacao.dobras`
  (uso transiente durante o wizard).

- **objetivo** — `{ tipo, descricao, metaPeso, prazoMeses, definidoEm, status }`.
  - `tipo ∈ { emagrecimento, ganho_massa, manutencao, reducao_gordura,
    performance, saude, reabilitacao }`
  - `status ∈ { ativo, atingido, revisado, abandonado }`

- **estiloVida** — `{ fatorAtividade, disponibilidadeTreinoSemanal,
  preferencias[], aversoes[], restricoesReligiosas[] }`.
  - `fatorAtividade ∈ { sedentario, leve, moderado, ativo, extremo }`

### 2.3. Atendimento

Evento clínico datado. É a "consulta". **NÃO existe UI de agendamento** —
Atendimentos nascem implicitamente quando o profissional emite o primeiro
Instrumento do dia para aquele paciente.

**Atributos:**
- `id`, `data` (`YYYY-MM-DD`), `tipo`, `profissional`, `motivo`, `status`,
  `instrumentosIds[]`.
- `tipo ∈ { primeira, retorno }` (auto-decidido: primeira se
  `atendimentos.length === 0`, senão retorno) **ou**
  `{ inicial, retorno, urgencia, ajuste }` quando o wizard é standalone.
- `status ∈ { em_andamento, concluido }`.
- `profissional` — hoje hardcoded como `'Dra. Camila'`.

**NÃO estão no modelo:** `cancelado`, `agendado`, modalidade
`presencial | telemedicina`, sala, prontuário eletrônico compartilhado.

### 2.4. Nível 1 — Átomos de Catálogo

#### 2.4.1. Alimento (TACO)

Item da Tabela Brasileira de Composição de Alimentos (Unicamp, 4ª ed.).
597 registros. Composição centesimal completa: energia, macros, minerais
(9 minerais), vitaminas (A, B1, B2, B6, niacina, C), ácidos graxos, 18
aminoácidos.

Tabela `alimentos` (schema em `03-DADOS.md`).

#### 2.4.2. Exame (LOINC + TUSS + CBHPM)

Codificação laboratorial e de procedimentos. 98.554 registros.

**Atributos essenciais:** `id`, `nome`, `sigla`, `nome_tecnico`, `categoria`,
`tipo_exame`, `tipo_resultado`, `material`, `jejum`, `jejum_horas`,
`unidade`, `codigo_loinc`, `codigo_tuss`, `codigo_cbhpm`, `codigo_sus`
(SIGTAP).

**tipo_exame ∈ { individual, painel, composto }** — porém, no seed atual e
nos 98k registros, apenas `individual` e `composto` são usados. `painel`
está na taxonomia mas sem uso — **na prática o "painel" é implementado
como grupo dentro de um Modelo de Solicitação, ou como `composto` com
`componentes[]`**.

**Sub-entidades:**
- `exames_componentes[]` — para exames compostos (ex: Hemograma tem HB, HT,
  leucócitos… cada com seu próprio código LOINC, unidade, faixa de referência).
- `exames_referencias[]` — faixas de normalidade por sexo, idade
  (em meses, para precisão pediátrica), condição (`geral`, `gestante`,
  `ideal_funcional`).
- `exames_sinonimos[]` — nome popular, nome científico, tradução.

> **Correção ontológica importante do brief:** o brief menciona "SIGTAP" como
> fonte primária. O código guarda o código SUS em `codigo_sus` (que é
> SIGTAP), mas a UI e a busca priorizam **LOINC, TUSS e CBHPM**. Nada em
> Português-BR nas etiquetas menciona SIGTAP.

#### 2.4.3. Produto (ANVISA + curados)

Item que pode ser prescrito. 53.717 registros.

**Regra ontológica inviolável:** *Produto = IDENTIDADE físico-química do
que existe no mundo. NÃO tem dose sugerida, frequência, horário nem
duração. Isso pertence à Prescrição, não ao Produto.* Comentário nas
linhas 2703–2708 e constante `CAMPOS_POSOLOGIA = []` na 2744.

**Atributos comuns:** `id`, `categoria`, `nome`, `fabricante`,
`principio_ativo`, `concentracao`, `forma_farmaceutica`, `apresentacao`,
`classe_terapeutica`, `tarja`, `marco_regulatorio`.

**Códigos de interoperabilidade:** `codigo_ean13`, `codigo_dcb`,
`codigo_atc`, `codigo_unii`, `codigo_rxcui`, `codigo_chebi`,
`codigo_pubchem_cid`, `codigo_registro_anvisa`, `codigo_ggrem`.

**Blob de atributos específicos por categoria (JSON):** `atributos_json`.
O schema muda conforme `categoria`:

| categoria     | atributos-chave (schema em `SCHEMAS_PRESCRICAO`) |
|---------------|---------------------------------------------------|
| medicamento   | principio_ativo*, concentracao, forma_farmaceutica, apresentacao, classe_terapeutica, registro_anvisa, receita_especial |
| suplemento    | nutriente*, forma_quimica, dose_elementar, dose_total, biodisponibilidade, pureza |
| fitoterapico  | nome_cientifico*, nome_popular, parte_utilizada, tipo_extrato, razao_extrato, padronizacao, marcador_quimico |
| nutraceutico  | composto_ativo*, origem, padronizacao, biodisponibilidade |
| probiotico    | cepas*, ufc, quantidade_cepas, tecnologia |
| hormonio      | hormonio*, ester, concentracao, monitoramento |
| peptideo      | sequencia, concentracao, diluente, volume_diluente, volume_por_aplicacao, conservacao, pureza |
| cannabis      | cbd_mg_ml, thc_mg_ml, cbg_mg_ml, cbn_mg_ml, terpenos, tipo_extrato |
| homeopatia    | nome_cientifico*, potencia, forma |
| injetavel     | principio_ativo*, concentracao, volume_ampola, aplicacao |

> "dose_elementar", "dose_total", "concentracao", "volume_por_aplicacao"
> são **atributos químicos/de apresentação**, NÃO posologia. Ex.:
> `concentracao: '50 mg/ml'` é característica intrínseca do produto;
> `dose: '2 ml, 3× ao dia'` é característica da Prescrição.

**Segurança administrativa (não é posologia, é advertência intrínseca do
produto):** `jejum`, `apos_refeicao`, `antes_refeicao`, `evitar_alcool`,
`obs_livre`.

**Sub-entidades:**
- `produtos_sinonimos[]` — sinônimo, nome popular, marca comercial, nome alternativo.
- `produtos_alergenos[]` — `{ produto_id, alergeno }` (lactose, glúten, ovos, amendoim, castanhas, soja).
- `produtos_precos[]` — histórico CMED (PF, PMC por ICMS).

#### 2.4.4. Exercício (free-exercise-db)

Item para composição de treinos. Base pública **free-exercise-db** (873
exercícios, Unlicense). Carregada de `data/exercicios_freedb.json` (1.5 MB)
no boot; **não** vive no SQLite.

**Atributos:** `id`, `nome`, `nome_en`, `primario[]` (grupos musculares),
`secundario[]`, `equip[]` (barra, halteres, máquina, cabo, kettlebell,
elástico, peso_corporal…), `padrao` (empurrar_horizontal, puxar_vertical,
agachar, dobrar, rotacionar, estabilizar), `nivel` (iniciante/intermediário/avançado),
`tipo` (composto/isolado/isométrico), `categoria`, `instrucoes[]` (passo a
passo PT), `imagens[]` (CDN raw do GitHub — origem freedb).

**Tradução:** `FREEDB_MAP` (linhas 4352–4371) mapeia EN→PT para músculo,
equipamento, nível, mecânica.

**Grupos musculares oficiais** (`GRUPOS_MUSCULARES`, 10 grupos): peito,
costas, ombros, biceps, triceps, core, gluteos, quadriceps, posteriores,
panturrilha, lombar, trapezio, pescoco, antebracos, abdutores, adutores.

### 2.5. Nível 2 — Compostos

#### 2.5.1. Refeição-modelo

Composição reutilizável de Alimentos que representa "café da manhã do
paciente X" ou "lanche pré-treino padrão".

**Atributos:** `id`, `nome`, `categoria` (`cafe | lanche | almoco | jantar
| ceia | pre_treino | pos_treino`), `itens[]` onde cada item é
`{ alimentoId, gramas, obs }`.

Perfil nutricional (kcal, P, C, G) é sempre **derivado** dos itens via
`calcularRefeicao()`.

#### 2.5.2. Treino-modelo

Composição reutilizável de Exercícios (ex: "Peito+Tríceps",
"Perna–força").

**Atributos:** `id`, `nome`, `nivel`, `grupos[]` (grupos musculares
alvo), `itens[]` onde cada item é `{ exercicioId, series, reps, carga,
descanso }`.

`grupos[]` pode ser explícito ou derivado (`_deriveGrupos()`, linha 4730,
fallback aos `primario` dos exercícios).

Seed: `data/seeds/treinos_modelo.json` (20 treinos curados).

#### 2.5.3. Fórmula manipulada

Composição de N Produtos em UMA forma farmacêutica (cápsula, sachê,
solução oral, pomada, creme, xarope, gel).

**Atributos:** `id`, `nome`, `tipo_farmaceutica`, `duracao`, `posologia`
(texto livre aplicado à fórmula toda, NÃO por componente), `observacao`,
`componentes[]`.

**Componente:** `{ produto_id | null, produto_nome | nome_livre, dose,
obs }`. Se `produto_id` estiver setado, o componente é rastreável ao
Produto do catálogo (permite auditoria de proveniência). Se apenas
`nome_livre`, é ativo digitado manualmente pelo profissional.

SEED atual: **vazio** (comentário na linha 3034: "zerado. Vamos recomeçar
com nova estratégia").

#### 2.5.4. "Painel de Exames" — não existe como entidade separada

Ver §2.4.2. O que o brief chama de "Painel" tem 3 representações
possíveis no modelo atual:
1. Exame com `tipo_exame = 'composto'` e `componentes[]` (ex: Hemograma).
2. `Grupo` dentro de um Modelo de Solicitação (§2.6.4).
3. Exame com `tipo_exame = 'painel'` — reservado, mas nenhum seed usa.

### 2.6. Nível 3 — Templates / Modelos

Instâncias reutilizáveis nomeadas, que serão *aplicadas* a um Paciente
para gerar o Instrumento final.

#### 2.6.1. Template de Plano Alimentar

`{ id, nome, vet_alvo, macros:{p,c,g}, objetivo, refeicoesModeloIds[],
observacao }`.

`observacao` aceita mini-markdown clínico (parseado por
`renderMarkdownClinico`, linha 10399).

Seeds: 5 exemplos (`tpn1`, `tpn5`, `tpn16`, `tpn72`, `tpn86`) em
`TEMPLATES_PLANO_SEED`.

#### 2.6.2. Template de Programa de Treino

`{ id, nome, objetivo, fase, duracao_semanas, nivel, split,
treinosModeloIds[], observacao }`.

`fase` é derivada do `objetivo` via `_FASE_POR_OBJETIVO_TREINO`. `split`
usa `SPLITS_LABELS`.

Seed: `data/seeds/templates_programa.json` (16 templates curados;
6 hipertrofia, 4 emagrecimento, 2 saúde, 2 força, 1 condicionamento, 1
reabilitação).

#### 2.6.3. Template de Prescrição

Schema mais rico que os outros templates (23+ campos). Cobre `dose`,
`unidade`, `frequencia`, `horario`, `duracao_tratamento`,
`quantidade_total`, `via_administracao`, `associacao_refeicoes`,
`nivel_evidencia`, `ativos_sugeridos[]`, `protocolo_fases[]`,
`exames_acompanhamento[]`, `grupo_clinico`, `condicao_alvo`.

SEED atual: **vazio** (comentário na linha 3037: "zerado. Vamos recomeçar").

#### 2.6.4. Modelo de Solicitação de Exames

`{ id, nome, descricao, categoria, especialidade, objetivo, tags[],
visibilidade, grupos[] }` onde cada grupo é
`{ id, ordem, nome, exames[{ exameId, obrigatorio, obs }] }`.

`visibilidade ∈ { privado, compartilhado_com_equipe, padrao_do_sistema }`.

Cada grupo é a coisa-que-o-brief-chamou-de-Painel: um sub-conjunto
nomeado de exames dentro de um modelo maior (ex: "Metabolismo glicêmico"
+ "Perfil lipídico" dentro do modelo "Check-up cardiometabólico").

Seed: 44 modelos (`MODELOS_EXAMES_SEED`, linhas 3488–4258).

### 2.7. Instrumento (o artefato emitido)

Quando o profissional termina um wizard e clica "Publicar" (ou
"Emitir"), nasce um Instrumento — o registro de que o Paciente recebeu
um Plano/Programa/Prescrição/Solicitação naquele Atendimento.

**Atributos:** `id`, `tipo`, `emitidoEm`, `atendimentoId`, `estado`,
`resumo`.

- `tipo ∈ { plano_alimentar, programa_treino, prescricao, solicitacao_exames }`
- `estado ∈ { vigente, substituido }`
- `resumo` — string curta ("1860 kcal · 5 refeições · déficit −400",
  "Programa · 8 semanas", "3 medicamentos", "12 exames").

**Limitação importante:** o Instrumento **NÃO guarda o conteúdo integral**
do wizard. Apenas o metadado. Os dados detalhados (itens do plano, séries
do treino, itens da prescrição, exames selecionados) vivem apenas no
sub-state do wizard (`state.plano`, `state.treino`, `state.rx`, `state.ex`),
e são sobrescritos ao criar o próximo instrumento do mesmo tipo. Reabrir
um instrumento antigo para editar **não é possível** — a regra ontológica
implícita é: **emissão imutável, novo substitui vigente**.

---

## 3. Relacionamentos

Diagrama textual (o `→` representa "tem/pertence a"; o `↔` representa
associação com cardinalidade):

```
Paciente
  → Ficha (1:1)
  → Atendimentos (1:N)
      → Instrumentos (0:N)  [via instrumentosIds]
  → Instrumentos (1:N)      [também linkados no paciente diretamente]

Atendimento
  ↔ Paciente (N:1)
  → Instrumentos (0:N)      [via instrumentosIds]

Instrumento
  ↔ Paciente (N:1)
  ↔ Atendimento (N:1)
  — resumo textual do conteúdo (não referencia entidade de catálogo)

Template de Plano Alimentar
  ↔ Refeição-modelo (N:N)   [via refeicoesModeloIds[]]
Refeição-modelo
  ↔ Alimento (N:N)          [via itens[].alimentoId]

Template de Programa de Treino
  ↔ Treino-modelo (N:N)     [via treinosModeloIds[]]
Treino-modelo
  ↔ Exercício (N:N)         [via itens[].exercicioId]

Template de Prescrição
  ↔ Produto (N:N)           [via ativos_sugeridos + itens legados]
  ↔ Fórmula (N:N)           [via itens]
Fórmula (composto)
  ↔ Produto (N:N)           [via componentes[].produto_id]

Modelo de Solicitação de Exames
  → Grupo (1:N)             [embutido no JSON]
Grupo
  ↔ Exame (N:N)             [via exames[].exameId]

Categoria
  ↔ Produto (1:N)
  ↔ Exame (1:N)

Fonte
  ↔ Produto (1:N)           [proveniência]
  ↔ Exame (1:N)             [proveniência]
```

**Relações operacionais** (não são associações estáveis, são resultado de
eventos de aplicação):

- Aplicar um Template de Plano em um Paciente → gera um Instrumento
  `plano_alimentar` cujo `resumo` inclui id do template de origem.
- Aplicar um Template de Programa → idem para `programa_treino`
  (`origem_template_id` marcado em `state.treino`).
- Importar um Produto/Exame do Catálogo Oficial (SQLite) → copia para
  `state.cadastros` local com marca `_importado_do_catalogo_em`.

---

## 4. Estados

Cada entidade tem um pequeno vocabulário de estados finitos.

### 4.1. Paciente
- `status ∈ { ativo, inativo, arquivado }` — filtro na lista de pacientes.

### 4.2. Ficha
Não tem estado nomeado. Existe sempre associada ao Paciente. Pode estar
"completa o suficiente para X" ou não — checagem via `_fichaTemMinimo(p, tipo)`
(linha 8995): exige peso+altura para qualquer wizard; exige objetivo vigente
para Plano e Treino.

### 4.3. Atendimento
- `em_andamento` — recém-criado ou reaberto no mesmo dia.
- `concluido` — profissional clicou "Concluir".

### 4.4. Instrumento
- `vigente` — o único ativo daquele tipo para aquele paciente.
- `substituido` — havia sido vigente, foi trocado por um novo do mesmo tipo.

Não existe `cancelado`, `rascunho` nem `arquivado` para Instrumento no
modelo atual.

### 4.5. Objetivo (dentro da Ficha)
- `ativo | atingido | revisado | abandonado`.

### 4.6. Alimento / Exercício / Produto / Exame
- `ativo | rascunho | inativo | arquivado`.
- Somente registros criados/editados pelo profissional podem ter estado
  alterado. Registros do catálogo oficial (SQLite) são efetivamente
  read-only pela UI (ver §6.3).

---

## 5. Eventos

Eventos são transições de estado ou criações/atualizações relevantes.

### 5.1. Ciclo de emissão de um Instrumento

Este é o evento central do sistema. Ele acontece em quatro fases:

1. **Iniciar wizard a partir do Paciente** —
   `criarInstrumento(tipo)` (linha 9063). Efeitos:
   - Valida `_fichaTemMinimo(paciente, tipo)`; se falhar, aborta e mostra
     o toast do que falta.
   - `_resetWizardState(tipo)` — limpa o sub-state do wizard.
   - Define `state.contextoInstrumento = { pacienteId, pacienteNome,
     tipo, stepInicial, iniciadoEm }`.
   - Pré-preenche o sub-state com dados do Paciente e da Ficha.
   - Navega para `stepInicial` (o wizard "pula" etapas que já viriam da
     Ficha — ver `_WIZARD_HERDADOS`, linha 8991).

2. **Percorrer o wizard** — user preenche telas. Cada mudança dispara
   `scheduleSave()`, persistindo o state em `localStorage`.

3. **Publicar** — botão final do wizard chama a função-de-publicação do
   domínio:
   - Plano Alimentar: `window.publicarPlanoAlimentar()` (linha 8569).
   - Programa de Treino: `window.publicarProgramaTreino()` (linha 5594).
   - Prescrição: `rxEmitir()` (linha 12947).
   - Solicitação de Exames: `exSolicitar()` (linha 13089).

4. **Salvar no Paciente** — `salvarInstrumentoNoPaciente()` (linha 9615):
   - Procura Atendimento do dia com status `em_andamento` → usa.
   - Senão, procura Atendimento concluído do dia → **reabre** para
     `em_andamento`.
   - Senão, cria novo Atendimento (`atd_<timestamp>`,
     status `em_andamento`, tipo derivado da existência de atendimentos
     anteriores).
   - Cria Instrumento novo (`ins_<timestamp>`, `estado = 'vigente'`,
     `resumo` gerado).
   - **Marca qualquer Instrumento anterior do mesmo tipo do mesmo
     paciente como `estado = 'substituido'`** (regra da unicidade — §6.1).
   - Anexa `instrumentosIds` no Atendimento.
   - Limpa `state.contextoInstrumento`.
   - Navega de volta para a aba `instrumentos` do Paciente.

### 5.2. Fechar Atendimento
`concluirAtendimento(atdId)` (linha 10052) — muda status para
`'concluido'`. Não fecha instrumentos.

### 5.3. Aplicar Template
- Plano Alimentar: `aplicarTemplate(id)` (linha 7224) — copia
  `refeicoesModeloIds` para `state.estrutura.refeicoes` e `state.plano.itens`,
  seta `state.origem_template_id`.
- Programa de Treino: `tAplicarTemplate(id)` (linha 4744) — seta
  objetivo, fase, programa, split, montagem simultaneamente. Reseta
  `state.treino.semana` com base em `disponibilidadeSemanal`.
- Prescrição: templates apenas populam a lista de itens no wizard
  (implementação atual mínima, já que templates estão zerados).
- Exames: `exAplicarModelo(id)` (linha 13056) — achata
  `m.grupos[].exames[]` em `state.ex.exames`, dedup por `exameId`.

### 5.4. Importar do Catálogo Oficial
`importarDoCatalogoOficial(tipo, id)` (linha 2195). Consulta SQLite,
verifica se já existe (por id ou `codigo_registro_anvisa`/`codigo_loinc`),
copia campos curados para `state.cadastros.<tipo>` com marca
`_importado_do_catalogo_em: ISO`. Não altera o SQLite.

### 5.5. Editar Item de Catálogo
Item que veio do SQLite não é editado no SQLite; a UI força o "clone e
edite" — o item aparece em `state.cadastros.<tipo>` local (localStorage) e
o `allXxx()` fallback merges com o catálogo.

### 5.6. Boot / Migração
Ao carregar a página:
1. Lê `localStorage['autonState_v1']`.
2. Valida `__seed === SEED_VERSION` (`'auton-v2-unified'`); se não bater,
   descarta e usa `DEFAULT_STATE`.
3. Roda migrações inline (seed de refeições/templates novos, saneamento
   de IDs legados, `_STEP_MIGRATION` redirecionando steps deletados).
4. Aguarda `AutonDB.ready()` → dispara `autondb:ready` → invalida caches
   e re-renderiza a tela atual.
5. Chama `goTo(state.currentStep)` — restaura a última tela.

### 5.7. Autosave
Toda mudança em `state.*` deve chamar `scheduleSave()` (linha 6536), que
debounce em 500 ms e grava JSON em `localStorage`. UI mostra "Salvando…"
→ "Auto-salvo".

### 5.8. Trocar Tema
`window.toggleTheme()` (linha 1926) — alterna `html[data-theme]` entre
`light` e `dark`, persiste em `localStorage['auton-theme']` (chave
separada do `autonState_v1`; **não** é resetada pelo `reset()`).

---

## 6. Regras e restrições

### 6.1. Unicidade do Instrumento vigente
Para cada Paciente e cada `tipo`, existe **no máximo um** Instrumento com
`estado = 'vigente'`. Publicar um novo empurra o anterior para
`'substituido'`. Implementação em `salvarInstrumentoNoPaciente` (linhas
9674–9678).

### 6.2. Produto não tem posologia
Produto descreve identidade química/regulatória. Posologia (dose,
frequência, horário, duração, via) só existe em:
- Item de Prescrição (`state.rx.itens[]`).
- Fórmula (campo `posologia` de texto livre, aplicado à fórmula toda).
- Template de Prescrição (todos os campos posológicos).

Regra formalizada no código como `CAMPOS_POSOLOGIA = []` (linha 2744) e
comentário nas linhas 2703–2708. Verificado: nenhum schema de categoria
em `SCHEMAS_PRESCRICAO` viola essa regra.

### 6.3. Dado oficial é imutável
Registros originários do SQLite (`ANVISA`, `TACO`, `LOINC`, `TUSS`,
`CBHPM`) não são alterados pelo app. Editar exige clonar para
`state.cadastros` local. `duplicarProduto` sempre vai para o cadastro
pessoal (linha 11669). `excluirProduto` só permite excluir do cadastro
pessoal (linha 11679).

### 6.4. Wizard iniciado no contexto de Paciente pula etapas herdadas
Se `state.contextoInstrumento` existir, os steps listados em
`_WIZARD_HERDADOS[tipo]` (linha 8991) ficam ocultos e o wizard começa em
`_WIZARD_START_EM_CONTEXTO[tipo]` (linha 8984). Contexto:
- `plano_alimentar` herda `inicio + anamnese + avaliacao` (vêm da Ficha).
- `programa_treino` herda o mesmo trio.
- `prescricao` herda `rx_inicio + rx_paciente` (começa em `rx_itens`).
- `solicitacao_exames` herda `ex_inicio + ex_paciente` (começa em `ex_selecao`).

### 6.5. Emissão imutável
Um Instrumento emitido não pode ser reaberto para edição no state atual
(§2.7). Para "corrigir", o profissional publica um novo — o anterior vira
`'substituido'`.

### 6.6. Só um Atendimento em andamento por dia por paciente
Regra decorrente do §5.1: se já existe atendimento em_andamento do dia,
o próximo instrumento atraca nele. Se só existe concluído do dia, é
reaberto. Nunca há dois em_andamento simultâneos do mesmo paciente no
mesmo dia.

### 6.7. Fórmula precisa de ao menos 1 componente
`salvarFormula` (linha 11788) exige `componentes.length >= 1` e nome
preenchido.

### 6.8. Componente de Fórmula desvincula ao editar o nome
Se o componente foi vinculado a um `produto_id` do catálogo e o
profissional edita o campo de nome, o vínculo é **removido** e o
componente vira "ativo em texto livre" (linha 11768). Isso preserva a
rastreabilidade — só produtos realmente selecionados do catálogo mantêm o
`produto_id`.

### 6.9. Ficha mínima antes de emitir
`_fichaTemMinimo(paciente, tipo)` (linha 8995):
- Todos os tipos: peso + altura obrigatórios na Ficha.
- `plano_alimentar` e `programa_treino`: objetivo com status `ativo`
  obrigatório.

### 6.10. IMC não é armazenado
Sempre derivado: `peso / (altura/100)²`. Idem para relação C/Q, %
gordura por dobras, kcal por refeição, volume por treino, VET, etc. O
princípio: **fatos primitivos ficam no state; agregados são funções
puras**.

### 6.11. Registros de série temporal preservam histórico
`ficha.antropometria` é `[{ data, ... }]` — cada medição vira nova
entrada, nunca sobrescreve. Isso permite gráfico de evolução (não
implementado ainda; ver aba "Evolução Fotográfica" `_renderPacEvolucao`,
placeholder linha 10115).

### 6.12. Fonte de exercícios é externa (não editável no catálogo)
Exercícios do free-exercise-db vêm com id `freedb_<n>`. Editar cria uma
cópia local `ex_<hash>`. As imagens são hot-linked do GitHub raw
(`FREEDB_IMG_CDN`, linha 4350) — o app não hospeda mídia.

### 6.13. LOINC/TUSS/CBHPM só via import
O editor de Exame **não expõe** campos `codigo_loinc`, `codigo_tuss`,
`codigo_cbhpm`. Um exame só ganha esses códigos se for importado do
Catálogo Oficial via `importarDoCatalogoOficial` (linhas 2238–2240).

### 6.14. Dado ANVISA preservado 1:1
Nenhum campo de linha ANVISA é modificado pelo app. Enriquecimento (ATC,
tarja, forma farmacêutica) só preenche campos vazios — ver
`03-DADOS.md` §5.

### 6.15. Chave de state é versionada
`SEED_VERSION = 'auton-v2-unified'`. Alterar o seed exige incrementar a
constante para invalidar storage existente. Alternativa: adicionar
migração inline (padrão atual — ver §5.6).

---

## 7. Delimitações do domínio (o que a ontologia NÃO cobre hoje)

Documentado aqui para não confundir escopo:

- **Impressão / PDF real** — botões "Imprimir" e "Enviar por email" em
  todos os wizards são stubs (`toast('em breve')`).
- **Agendamento** — não há calendário, não há status `agendado`, não há
  "próximas consultas hoje". A tela inicial é a lista de pacientes.
- **Multiusuário** — profissional é hardcoded (`'Dra. Camila'`).
- **Time-line de evolução** — dados existem (`antropometria[]`,
  `atendimentos[]`), gráficos não.
- **Interações fármaco-fármaco / fármaco-suplemento** — não modeladas.
- **Compartilhamento entre profissionais** — não modelado.
- **Faturamento / convênios** — fora de escopo.
- **Prescrição digital ICP-Brasil (assinatura)** — não modelada.

---

## 8. Glossário

| Termo | Definição |
|---|---|
| **Instrumento** | Artefato clínico emitido (Plano, Programa, Prescrição, Solicitação) — a "receita" ou o "pedido" no ordinário. |
| **Wizard** | Sequência de telas que coleta dados até o Instrumento ser publicado. |
| **Substep** | Cada tela de um wizard. Substeps do Plano vivem numa única `screen-plano_completo`, roladas por scroll suave. |
| **Sub-state** | Sub-árvore de `state` dedicada a um wizard (`state.plano`, `state.treino`, `state.rx`, `state.ex`). |
| **Contexto** | `state.contextoInstrumento` — presente quando o wizard nasce de um Paciente; ausente em modo standalone. |
| **Catálogo Oficial** | Dados do SQLite (`auton.db`), imutáveis pela UI. |
| **Biblioteca Pessoal** | Dados que o profissional cria/edita, persistidos em `localStorage` sob `state.cadastros.*`. |
| **Freedb** | Base pública `free-exercise-db` (Unlicense, 873 exercícios). |
| **TACO** | Tabela Brasileira de Composição de Alimentos, Unicamp, 4ª ed., 597 alimentos. |
| **ANVISA-dados-abertos** | Datasets públicos ANVISA de medicamentos, cosméticos, alimentos, cannabis. |
| **CMED** | Câmara de Regulação do Mercado de Medicamentos — fonte de tarja, concentração, forma farmacêutica. |
| **LOINC** | Logical Observation Identifiers Names and Codes — padrão mundial para exames. |
| **TUSS** | Terminologia Unificada da Saúde Suplementar (ANS) — código de procedimento. |
| **CBHPM** | Classificação Brasileira Hierarquizada de Procedimentos Médicos (AMB). |
| **SIGTAP** | Sistema de Gerenciamento da Tabela de Procedimentos, Medicamentos e OPM do SUS. |
| **ATC** | Anatomical Therapeutic Chemical (WHOCC) — classificação global de medicamentos, 5 níveis. |
| **RxNav** | API pública NIH que oferece cross-walk RxCUI ↔ ATC. |
| **DCB** | Denominação Comum Brasileira — nome oficial de fármacos no BR. |
| **UNII / RxCUI / ChEBI / PubChem CID** | IDs universais para cross-walk químico e farmacológico. |
| **Ontologia dos 3 níveis** | Convenção do app: Átomo (Nível 1) → Composto (Nível 2) → Template (Nível 3). Vale para os 4 domínios clínicos. |
