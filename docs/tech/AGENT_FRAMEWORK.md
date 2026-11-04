# Framework de agentes (Claude Code Game Studios)

Estado a 2026-11-04. Origem: [Donchitos/Claude-Code-Game-Studios](https://github.com/Donchitos/Claude-Code-Game-Studios), versão 1.2.0 (commit 05ad7c8), licença MIT (`.claude/LICENSE`). Este documento regista o que foi instalado, o que foi adaptado, as lacunas conhecidas e as decisões tomadas a 2026-11-04. É a fonte única deste assunto; o `CLAUDE.md` aponta para aqui.

## Instalado

| Caminho | Conteúdo |
|---|---|
| `.claude/agents/` | 49 agentes do upstream. `ui-designer.md` (nosso) mantém-se. |
| `.claude/skills/` | 74 skills (`/start`, `/dev-story`, `/design-review`…). |
| `.claude/hooks/` | 18 scripts bash: validação de commits, push, leituras e escritas; arranque; registo de agentes. |
| `.claude/rules/` | 14 regras por caminho (`paths:`). |
| `.claude/scripts/`, `.claude/docs/`, `.claude/statusline.sh` | Apoio aos hooks e skills. `.claude/docs/effects-map.md` é a referência do `project.yaml`. |
| `.claude/settings.json` | Permissões e hooks do upstream, mais o arranque da cloud do projeto (`tools/cloud/setup_godot.sh`, primeiro). |
| `project.yaml` | Motor Godot 4.7, GDScript, especialistas, plataforma, convenções de nomes, `modes` explícito. |
| `docs/engine-reference/` | Snapshot de Godot 4.7 (APIs, mudanças, depreciações). |
| `docs/architecture/`, `docs/registry/` | Registos vazios, usados pelos skills de arquitetura. |
| `docs/WORKFLOW-GUIDE.md`, `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md`, `docs/skill-flow-diagrams.md` | Guias do framework. |
| `production/.gdignore` | O Godot ignora a pasta `production/` (estado de sessão). |

Ignorados pelo git (locais): `.claude/settings.local.json`, `CLAUDE.local.md`, `project.local.yaml`, `production/session-logs/`, `production/session-state/`, `.scratch/`, `.claude/agent-memory/`.

## Adaptações ao upstream

1. **Raiz do código.** O framework usa `src/` para o Godot. Acrescentou-se `engine.code_root` em `project.yaml` e um passo 0 em `resolve_code_root()` (`.claude/hooks/yaml-helper.sh`) que o respeita. Cada fonte (`project.local.yaml`, depois `project.yaml`) é validada à parte: um valor inválido é ignorado e lê-se a fonte seguinte. São rejeitados caminhos absolutos (`/`, `\`, letra de unidade, UNC) e com `..`. Sem valor válido, vale a cadeia do upstream. Aqui vale `game`.
2. **Testes.** `.claude/rules/test-standards.md` prescreve gdUnit4. O projeto usa scripts `extends SceneTree` (secção Comandos do `CLAUDE.md`). Acrescentou-se uma nota no topo da regra.
3. **`CLAUDE.md`.** Não se importou o `CLAUDE.md` do upstream. Acrescentou-se uma secção com a versão, os ponteiros e a precedência das regras do projeto. O import do `VERSION.md` passou a ponteiro, lido sob demanda.
4. **`.claude/.gdignore`.** O Godot ignora a pasta do framework (importação e exportação).
5. **`.gitignore`.** Só as entradas locais do Claude. Não se adotaram a exceção que volta a incluir `.godot/global_script_class_cache.cfg` (o projeto nunca commita `.godot/`), nem as regras para `*.dll`, `*.exe`, `*.zip`, `bin/` ou `export_presets.cfg`.
6. **Fins de linha.** `.gitattributes` mantém `* text=auto eol=lf`. Os ficheiros copiados ficaram em LF.
7. **Não instalados:** `studio-tests/` (testes do próprio framework), `.github/`, `design/` e `src/` (pastas de outro layout), `docs/CLAUDE.md` (regras de ADR que se aplicariam a todo o `docs/`), `CHANGELOG.md`, `CONTRIBUTING.md`, `UPGRADING.md`, `SECURITY.md`.
8. **Regras por caminho de código.** `ui-code.md` passou a `game/ui/**`; `gameplay-code.md` passou a `game/horde/**` e `game/world/**`. As restantes (`engine-code.md`, `network-code.md`, `ai-code.md`, `prototype-code.md`) continuam em `src/` e não se aplicam. Mapeadas a 2026-11-04.

## Lacunas conhecidas

- Os scans de código dos hooks (valores fixos, TODO sem dono) correm em `game/`. Continuam a ser avisos, não bloqueios.
- **Conflitos de conteúdo nas regras mapeadas.** `ui-code.md` pede que todo o texto de UI passe pelo sistema de localização, e que existam modo daltónico, texto escalável e animações ignoráveis. O projeto ainda não tem estes sistemas; não verifiquei o estado de cada um. Ao editar UI, o agente vai assinalá-lo. `gameplay-code.md` pede valores só de ficheiros de dados e nada de singletons globais. Não verifiquei quantos casos existem em `game/`; o agente vai assinalá-los ao editar.
- Regras inativas: `engine-code.md`, `network-code.md`, `ai-code.md` e `prototype-code.md` apontam para `src/`. `shader-code.md` (`**/*.gdshader`) e `scene-files.md` (`**/*.tscn`, `**/*.tres`) aplicam-se a qualquer pasta.
- Os skills escrevem, por omissão, em `src/` e `design/`. Ao usar um skill que escreva código ou GDDs, indicar `game/` e `docs/design/`.
- `setup_godot.sh` (cloud) instala agora o Godot 4.7.2-stable, alinhado com as medições locais. Continua a ignorar falhas de importação e a reutilizar um executável existente sem verificar a versão.
- `update-check.sh` faz um pedido diário à API do GitHub (`updates.check: true`).
- `jq` não está instalado. Os hooks usam o fallback com `grep`: funciona, com menos precisão.
- O guard de leitura inteira (acima de 40 KB) vigia só `design/`, `docs/architecture/` e `production/session-state/`. Os nossos `docs/design/` não são vigiados.
- `validate-push` não bloqueia: avisa ao fazer push para `main`, `master` e `release/*`. A proteção contra `push --force` é a regra `deny` do `settings.json`, aplicada pelo Claude Code e não pelo hook.
- `.claude/scripts/test-run.sh` não corre testes Godot sem gdUnit4: reporta `ran no` e sai com código **0** (linhas 289–296). Um skill que só veja o código de saída lê isto como sucesso. Não usar este runner como prova. Os skills de teste (`/test-setup`, `/smoke-check`, `/regression-suite`) usam-no; não verifiquei cada um.

## Verificação (2026-11-04)

- `bash -n` em todos os hooks, scripts e `statusline.sh`: sem erros de sintaxe. Nenhum ficheiro instalado tem CRLF (contagem por bytes).
- `settings.json` é JSON válido, e a entrada de arranque da cloud existe uma vez e em primeiro lugar.
- `project.yaml`: `engine.code_root` é lido e resolve para `game`. O arranque não reporta erros de esquema.
- Hooks num repositório descartável, fora do projeto: JSON inválido em `assets/data/` bloqueado (exit 2); valores fixos e TODO em `game/` avisados (exit 0); leitura inteira de um doc de 60 KB em `design/` recusada (exit 2), e por intervalo permitida.
- Passo 0 do `resolve_code_root`, repetido depois da correção: `engine.code_root` inválido numa fonte (`../x`, `C:/outside`, UNC) é ignorado e o valor válido da outra fonte é usado; um valor local válido (`tools`) tem precedência.
- Arranque: o checkpoint de `production/session-state/active.md` é recuperado e mostrado.
- Godot 4.7.2 headless: `tests/test_smoke.gd` passa, sem `TEST FAIL` nem `SCRIPT ERROR`.
- URL do Godot 4.7.2-stable para a cloud: HTTP 200.
- Por verificar: exportação (não executada), sessões na cloud, ordem de execução dos hooks de arranque, e o bloqueio de `push --force` pela regra `deny`.
- godot-mcp: ver `spikes/godot_mcp/README.md`.

## Como atualizar

Não copiar o `.claude/` do upstream às cegas. Reaplicar as adaptações 1–8 depois de comparar com `git diff`. `project.yaml`, `.claude/settings.json`, `CLAUDE.md`, `.gitignore`, `AGENTS.md` e `.claude/agents/ui-designer.md` fundem-se à mão. Passos do upstream: `UPGRADING.md` no repositório de origem.

## Decisões de 2026-11-04

1. **Protocolo de colaboração.** Não importado. Os skills usam `modes.automation: collaborative` (explícito em `project.yaml`), por isso pedem aprovação antes de cada escrita. No trabalho direto, a prática mantém-se: escrever e mostrar o `git diff`. Decisões de design e de âmbito têm aprovação explícita.
2. **Raiz do código.** `game/` confirmado (`engine.code_root`). Regras mapeadas (adaptação 8). Conflitos de conteúdo listados acima.
3. **`docs/DECISIONS.md`.** Regra por âmbito: só o agente principal regista decisões explícitas do utilizador, com data. Subagentes e Codex não editam o ficheiro e propõem alterações nos seus próprios documentos. `AGENTS.md` e `.claude/agents/ui-designer.md` foram alterados para o dizer. Registadas duas linhas: instalação do framework; godot-mcp sem adoção.
4. **Gestão de contexto.** O checkpoint `production/session-state/active.md` é atualizado pelo agente em cada marco e antes de tarefas longas (o `pre-compact.sh` só regista). O custo de arranque que resta (secção do `CLAUDE.md`, listas de skills e agentes) não está medido em tokens.
5. **Nível de rigor.** `modes.rigor: minimal` fica explícito em `project.yaml`. O nível fixa também a documentação (`terse`), o QA (`minimal`) e a revisão (`solo`). Rever antes de um playtest, ou se se quiser que os skills registem evidência de testes (`standard`).
6. **Runner de testes.** Não adaptado. Gatilho para adaptar: quando se quiser um skill de QA a correr os testes `extends SceneTree`. Até lá, os testes correm pela linha de comando do `CLAUDE.md`.
7. **godot-mcp.** Mantido registado para três tarefas concretas (critério em `spikes/godot_mcp/README.md`). Remove-se se não ganhar em pelo menos uma.
8. **Pasta de design.** `docs/design/` mantém-se. Não se cria `design/`, e os skills que escrevem GDD em `design/gdd/` não se usam para GDD.
9. **Verificação de atualizações.** `updates.check: true` mantido.
10. **Godot na cloud.** 4.7.2-stable em `tools/cloud/setup_godot.sh`.
