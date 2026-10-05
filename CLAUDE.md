# Horde Breaker Remake

Remake do Horde Breaker (repositório original: `ruiguitos/horde-breaker`).
O jogo está a ser **reformulado a partir dos documentos de design**, não do
código antigo. Estado atual: **vertical slice em grey-box** (1 ilha, missão
"Activate 3"); ver `game/README.md`.

## Idioma

- Comunicação, documentação e mensagens para o utilizador: **português de Portugal**.
- Código, nomes de ficheiros, identificadores, comentários e texto dentro do
  jogo: **inglês**.
- Mensagens de commit em inglês, estilo Conventional Commits (`feat:`, `docs:`, `test:`…).

## Engine

- **Godot 4.7 stable**, GDScript **tipado**, renderer Forward+. Sem C# por agora.
- Em sessões na cloud, o hook `SessionStart` (`.claude/settings.json`) corre
  `tools/cloud/setup_godot.sh`, que instala o Godot em `~/.local/bin/godot` e
  importa o projeto. Se `godot` não estiver no PATH, usar `~/.local/bin/godot`.
- A cloud não tem GPU nem janela: só se valida em `--headless`. Nunca afirmar
  que algo "fica bem visualmente" sem o ter visto; indicar como o utilizador o
  testa no editor (Windows).

## Fontes de verdade, por ordem

1. `docs/DECISIONS.md` — decisões fechadas pelo utilizador. Prevalece sobre tudo.
2. `docs/design/*.md` e `docs/tech/*.md` — design e arquitetura do remake.
3. `docs/design/BRAINSTORM.md` — ideias em discussão, não decisões.
4. `docs/legacy/` — documentos do jogo original. **Referência histórica**:
   úteis para intenção, inspirações e lições; não são especificação.

## Estrutura

```
game/          código e cenas do jogo (vertical slice; ver game/README.md)
spikes/<nome>/ protótipos isolados; cada spike tem cena, scripts, tests/ e README.md
tests/         testes headless do jogo
tools/         ferramentas (tools/cloud/ = setup das sessões na cloud)
docs/          DECISIONS, design/, tech/, legacy/
```

## Comandos

```bash
godot --headless --path . --import                                  # regista class_name novos
godot --headless --path . --script res://tests/test_smoke.gd        # teste de fumo
godot --headless --path . --script res://spikes/<nome>/tests/<t>.gd # testes de um spike
```

Testes: `extends SceneTree`, lógica em `_initialize()`, imprimem `TEST: ...` ou
`TEST FAIL: ...` e chamam `quit(0|1)` em **todos** os caminhos (um teste sem
`quit()` pendura a sessão).

## Regras para agentes

- **Uma só sessão de desenvolvimento**: o utilizador trabalha numa conversa,
  sem tarefas paralelas. Commit e push direto para `master`, sem PR; antes
  de cada push, `git pull --rebase origin master`.
- **Não editar `docs/DECISIONS.md`.** Propor decisões numa secção
  "Decisões propostas" do teu próprio documento; o utilizador decide.
- **Sem assets externos** nem downloads de addons: usar primitivas Godot
  (`BoxMesh`, `CapsuleMesh`, CSG, materiais simples).
- Spikes ficam em `spikes/<nome>/` e não dependem uns dos outros nem de `game/`.
- Depois de criar um `class_name`, correr `--import` antes de testar.
- Commitar os ficheiros `.uid` que o Godot gera; nunca commitar `.godot/`.
- Preferir medir a supor: benchmarks imprimem números (ms, contagens) e o
  README do spike regista hardware/ambiente e limites da medição.
- Mudanças pequenas e explicáveis: o utilizador está a aprender
  desenvolvimento de jogos. Explicar o porquê das escolhas nos docs.

## Lições do projeto original (não repetir)

- Mudar a identidade do jogo a meio deixou sistemas órfãos. Cada feature tem
  de servir um pilar do GDD; o resto vai para a lista "não vamos fazer".
- Medir em jogo, não nos assets: sintomas de gameplay medem-se com consultas
  reais (física, navegação) na cena.
- `preload` de scripts que dependem de autoloads, a partir de `--script`,
  falha; usar `load()` em runtime.
- Documentação curta e viva: uma fonte por assunto, sem listas concorrentes
  de prioridades.
