# Importação dos seeds de Treinos-Modelo e Templates de Programa

Duas formas de importar. **A opção A é a mais rápida e testável agora**, sem tocar em código.

## Opção A — Importar via console do navegador (recomendado para testar agora)

1. Abrir o app: `http://localhost:8787/index.html`
2. Abrir o console do browser: `F12` (ou `Cmd+Opt+I` no Mac) → aba **Console**
3. Colar o bloco abaixo inteiro e apertar Enter:

```js
(async () => {
  const [treinos, templates] = await Promise.all([
    fetch('/data/seeds/treinos_modelo.json').then(r => r.json()),
    fetch('/data/seeds/templates_programa.json').then(r => r.json()),
  ]);
  // Merge (não sobrescreve — só adiciona os que não existem por id)
  const tmIds = new Set(state.cadastros.treinos_modelo.map(x => x.id));
  const tpIds = new Set(state.cadastros.templates_programa.map(x => x.id));
  const novosTM = treinos.filter(t => !tmIds.has(t.id));
  const novosTP = templates.filter(t => !tpIds.has(t.id));
  state.cadastros.treinos_modelo.push(...novosTM);
  state.cadastros.templates_programa.push(...novosTP);
  scheduleSave();
  console.log(`✅ Importados ${novosTM.length} treinos-modelo e ${novosTP.length} templates.`);
  console.log(`Total agora: ${state.cadastros.treinos_modelo.length} treinos, ${state.cadastros.templates_programa.length} templates.`);
  if (typeof RENDERERS.cadastros === 'function') RENDERERS.cadastros();
})();
```

4. Ir em **Cadastros → Treinos-modelo** e **Cadastros → Templates de Programa** para conferir.

Para reimportar do zero (apagar tudo antes):

```js
state.cadastros.treinos_modelo = [];
state.cadastros.templates_programa = [];
scheduleSave();
// depois rode o bloco acima
```

## Opção B — Fazer os seeds serem carregados sempre no boot (permanente)

Editar `index.html` e adicionar dentro de `window.__carregarExerciciosFreeDB` (ou criar função similar) o `fetch` dos dois JSONs. Fazer só quando confirmar que o conteúdo está correto.

## Conteúdo entregue

- **20 treinos-modelo** (`treinos_modelo.json`) — 124 prescrições de exercício, todos referenciando IDs reais do freedb
- **16 templates de programa** (`templates_programa.json`) — cobrindo hipertrofia (6), emagrecimento (4), saúde geral (2), força (2), condicionamento (1), reabilitação (1)

## Checagem rápida antes de importar

Contagem esperada após primeira importação limpa:
- `state.cadastros.treinos_modelo.length` → 20
- `state.cadastros.templates_programa.length` → 16
- Todos os `treinosModeloIds` dentro de templates referenciam ids válidos (validado)
- Todos os `exercicioId` dentro de treinos-modelo referenciam IDs do freedb (validado)
