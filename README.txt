AUTON Health — v2 unificado
============================

App único para uso local (HTML + SQLite via sql.js).
Contém TODOS os fluxos clínicos em um único index.html:

  · Novo Plano Alimentar
  · Novo Programa de Treino
  · Nova Prescrição
  · Nova Solicitação de Exames
  · Cadastros (biblioteca de conhecimento reutilizável)

Como rodar
----------

Mac:      duplo-clique em `start.command`
Windows:  duplo-clique em `start.bat`

O launcher sobe um servidor Python http.server na porta 8787 e abre
o navegador em http://localhost:8787/index.html

Requer Python 3 instalado.

Estrutura
---------

  index.html         → app único (todos os fluxos + cadastros)
  data/auton.db      → SQLite com catálogos oficiais (ANVISA, TACO, LOINC, SIGTAP)
  lib/sql-wasm.js    → biblioteca sql.js (v1.14.1)
  lib/sql-wasm.wasm  → binário WASM da sql.js
  start.command      → launcher Mac
  start.bat          → launcher Windows

Estado persistido
-----------------

Chave de localStorage: `autonState_v1`
Reset via botão "Sair" no rodapé da sidebar (com confirmação).

Ontologia (3 níveis) — universal a todos os domínios
----------------------------------------------------

Cada domínio segue a mesma estrutura de 3 camadas:

  Domínio        Nível 1 (átomo)      Nível 2 (composto)      Nível 3 (modelo)
  Alimentação    Alimento (TACO)      Refeição-modelo         Plano Alimentar
  Treino         Exercício            Treino-modelo           Programa de Treino
  Prescrição     Produto (ANVISA)     Fórmula manipulada      Prescrição/Template
  Exames         Exame (LOINC/SIGTAP) Painel de exames        Modelo de Solicitação
