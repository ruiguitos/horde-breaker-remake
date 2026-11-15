---
titulo: "docs/tech/ASSETS2GODOT.md"
tipo: "referencia"
estado: "referencia_a_confrontar"
atualizado: "2026-11-15"
tags: ["horde-breaker", "referencia"]
fontes: ["docs/tech/ASSETS2GODOT.md"]
---

# docs/tech/ASSETS2GODOT.md

> [!warning] Cópia de consulta
> Esta é uma cópia de consulta. A fonte continua no repositório; mudanças nesta cópia não alteram o original.

Fonte: `docs/tech/ASSETS2GODOT.md` · SHA-256: `5ab3131998e48a698693aaf2de2899629448f600a6535dbb2312e56aa0e033f3`

# Assets2Godot — ferramenta de assets do editor

Integração iniciada em **2026-11-14**, após o utilizador aceitar explicitamente
GPLv2 para este addon como ferramenta do editor. Codex não alterou
`docs/DECISIONS.md`; o agente principal pode registar essa decisão com a data.

## Âmbito e versão

- Assets2Godot 0.8.2, commit `177b79b940afd80b2cf67816dff0d86b4e2d8fce`.
- Pacote oficial sem executáveis; checksum e mudanças locais em
  `addons/assets2godot/PROJECT_INTEGRATION.md`.
- Destino inicial: procurar modelos, texturas e materiais **CC0** na Poly Haven
  e ambientCG. O addon é alpha; a compatibilidade tem de ser medida localmente.
- Cliente auxiliar e BlendKit bloqueados por defeito, antes da primeira
  ativação. As preferências globais do editor não podem ligar o cliente.
- Preferência inicial de texturas de 1K em ambos os fornecedores; não é um
  limite rígido nem uma operação automática de redução de polígonos.

## Como utilizar

1. Abrir o projeto no Godot. O addon está na lista de plugins ativos.
2. Abrir **A2G** na barra de espaços de trabalho do editor e escolher
   **Polyhaven** ou **ambientCG**.
3. Procurar um asset e confirmar a resolução/formato antes de descarregar.
   Começar em 1K; preferir glTF/GLB nos modelos quando disponível.
4. Rever materiais, escala, colisão e custo numa cena de ensaio. A aprovação
   do addon não aprova a colocação automática de conteúdo nas ilhas.
5. Copiar os recursos finais escolhidos para `assets/`, ajustar as referências
   para essa cópia e registar origem/licença em `assets/LICENSES.md`.

O Blender local serve a conversão de ficheiros `.blend` e materiais que a
exijam; a instalação do addon não troca modelos nem materiais existentes.

## Cache, Git e exportação

As descargas por defeito ficam em `Assets2Godot/`, ignorada pelo Git. Essa
pasta não é uma entrega versionada. O staging do upstream também pode criar
`imported_assets/`; neste projeto os assets finais devem ir para `assets/`.

O preset Windows exclui `addons/assets2godot/*` e `Assets2Godot/*`. Não usar
nas cenas do jogo referências que só existam na cache. A licença do addon é
distinta da dos assets descarregados; os ficheiros GPL permanecem na
ferramenta do editor.

## Testes e evidência

Ambiente: Windows, Godot **4.7.2 stable**. Evidência local em
`.scratch/assets2godot_install_20261114/` (ignorada pelo Git).

- Teste de política: primeiro falhou sem a proteção, depois passou com
  código de saída 0. Um segundo caso reproduziu o conflito do enum `State`
  com a classe global de `PlayerCharacter/StateMachine/`; o nome local
  `ClientState` corrigiu-o sem remover a tipagem.
- Importação headless do projeto: saída 0, sem `SCRIPT ERROR` ou `Parse Error`.
  Repetida no fim com os outros processos Godot fechados, também com saída 0,
  sem falhas de carregamento de extensões; as DLLs Terrain3D ficaram intactas.
  Log final: `import_closed_editor_stdout.log`, na pasta de evidência acima.
  Persistem avisos de UID duplicado em `Arts/` e recursos por libertar ao sair;
  isto não equivale a um arranque sem avisos.
- Ensaio num projeto isolado com o addon: Poly Haven com 2388 entradas e
  ambientCG com 2936, ambos online; preferência inicial 1K; cliente desligado,
  estado 0, BlendKit oculto. As contagens são um snapshot, não um contrato.
  Uma segunda execução, com saída 0, confirmou também que uma chamada direta
  a `set_client_enabled(true)` continua bloqueada. O editor isolado deixou
  avisos de recursos/RIDs na saída; não é um ensaio sem avisos.
- Descarregados pelo addon, apenas para o ensaio: `metal_jerrycan_green`
  (glTF 1K) e `wood_planks_grey` (conjunto JPG 1K), Poly Haven CC0.
  Após importação headless, o modelo instanciou e o material carregou com
  albedo, normal e ORM a 1024×1024. Teste com saída 0. Não foi avaliada a
  aparência em jogo, a colisão nem a escala destes dois assets.
- Exportação de um PCK mínimo, com marcadores em subpastas: num consumidor
  separado o recurso normal ficou disponível e os recursos da ferramenta e
  cache ficaram ausentes; teste com saída 0. Não foi exportado o jogo inteiro.
- Bateria completa `tests/run_all.gd`: **88/88 passaram**, saída 0, em
  1 507 902 ms (25 min 8 s). `TEST: all tests passed`; sem exceções de crash
  adicionadas, testes omitidos ou critérios enfraquecidos: 85 testes em
  `tests/` (incluindo o novo teste de política) e 3 nos spikes.

O teste `tests/test_assets2godot.gd` verifica a política de arranque: sem
permissão do projeto, uma preferência global não pode iniciar o cliente;
valores inválidos falham fechados; ambas as autorizações são necessárias.

Na primeira descarga do ensaio apareceram mensagens de tarefa `reimport`
concorrente do editor; a importação headless posterior e o carregamento dos
recursos passaram. Na abertura do projeto completo apareceram também erros
em `Compositor/General/BaseCompositorEffect.gd` (`free_rid`/`_reload`). O ensaio
isolado não os reproduziu; esta integração não os corrigiu. A automação de
cliques falhou com `SendInput ... GetLastError=87`; a verificação dos painéis e
descargas foi programática no editor, não uma aprovação visual da interface.

JEV: revisão consultiva guardada em
`vault/99 Ferramentas/JEV/04_integracao_assets2godot_revisao.json`. Indicou
lacuna de testes na primeira revisão, feita antes de terminar o ensaio;
o parecer não substitui os resultados executados. O segundo parecer, com
diff real e evidência do ensaio, está em `05_integracao_assets2godot_gate.json`:
validou as duas afirmações sobre a política e o ensaio, mas manteve a revisão
da alteração em `escalate` por baixa confiança/lacuna de testes. Não representa
aprovação automática da integração nem prova de segurança de todo o addon.

## Limites e alterações futuras

O addon não cria LODs nem garante orçamento de triângulos ou FPS. O índice
local dependente do daemon não está disponível com o cliente desligado.
Ativar BlendKit, autenticar uma conta ou permitir o cliente exige uma alteração
consciente da política do projeto e validação própria das licenças.

Fontes: [Asset Library](https://godotengine.org/asset-library/asset/5603),
[upstream](https://github.com/ikonnow/Assets2Godot).
