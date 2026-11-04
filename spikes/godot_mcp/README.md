# Spike: godot-mcp (servidor MCP para Godot)

Teste de 2026-11-04 ao pacote `@coding-solo/godot-mcp`, para decidir se o Claude pode abrir, editar e correr o projeto Godot através de ferramentas MCP. Isto é uma medição, não uma adoção: a decisão fica por tomar (ver «Recomendação»).

## Ambiente e versões

| Item | Valor |
|---|---|
| Hardware | PC de desenvolvimento, NVIDIA GeForce RTX 5060 (8 GB, `TODO.md:42`); Godot reportou `Vulkan 1.4 - Forward+ - NVIDIA GeForce RTX 5060` |
| Sistema | Windows 11 Pro 10.0.26300; shell Git Bash e PowerShell 7 |
| Godot | 4.7.2 stable (console exe em `Downloads`) |
| Node.js / npm | v24.18.0 / 11.16.0 |
| Claude Code | 2.1.317 |
| Pacote | `@coding-solo/godot-mcp` **0.1.1** (MIT); tarball `sha512-tSwmKN5D3JWGfnyPFxijxjdsT+GKIQrf9g6zYNefLvOVYx2UTC9PhyFFHc9vphtjyFrtjYf1n5Vq1zRNN3UXBA==` |
| Repositório de origem | `Coding-Solo/godot-mcp`, 6,5 mil estrelas, último push a 2026-04-16 |

A instalação fez-se numa pasta de teste fora do repositório, com `npm install --prefix <pasta> --ignore-scripts @coding-solo/godot-mcp@0.1.1`. O servidor reporta `serverInfo.version` 0.1.0, diferente da versão do pacote (0.1.1). Não investiguei a causa.

## Inspeção estática (antes de executar)

- `build/index.js` (78 KB): nenhum URL nem pedido HTTP. A dependência `axios` está declarada e não é usada.
- Execução de processos: só `execFile` e `spawn` com vetores de argumentos (sem shell), sempre sobre o executável indicado em `GODOT_PATH`.
- `build/scripts/godot_operations.gd` (49 KB): 46 chamadas de acesso a ficheiros, sem HTTP e sem `OS.execute`. Apaga só os ficheiros de teste que ele próprio cria (`DirAccess.remove_absolute`).
- Isto não substitui uma revisão ao código fonte completo: é o que foi possível verificar no pacote publicado.

## Como repetir

Os scripts estão em `tests/` (`mcp_client.mjs`, `scenario_basic.mjs`, `scenario_long.mjs`). Não têm dependências além do Node. Escrevem apenas em `WORK_DIR`, que tem de ficar **fora do repositório**. Proteções: recusam caminhos com `horde-breaker-remake` e raízes de unidade; `scenario_basic.mjs` só apaga a pasta `proj` que criou (marcada com `.godot-mcp-spike-fixture`) e recusa, sem apagar, uma `proj` sem essa marca; `scenario_long.mjs` só corre sobre um `proj` marcado. Os resultados (`results_*.json`) ficam dentro de `WORK_DIR`. O projeto de teste é gerado pelo próprio script; não há projetos Godot aninhados no repositório.

```
PKG_DIR=<pasta de instalação>   # onde está node_modules/@coding-solo/godot-mcp
GODOT_PATH=<Godot_v4.7.2-stable_win64_console.exe>
WORK_DIR=<pasta de trabalho fora do repositório>
MODE=run SCENARIO=./scenario_basic.mjs node tests/mcp_client.mjs   # passagem 1: cria o projeto
MODE=run SCENARIO=./scenario_long.mjs  node tests/mcp_client.mjs   # passagem 2: importa, corre 30 s, para
```

## Resultados

Números de execuções de 2026-11-04. Os JSON brutos ficam na pasta de trabalho, fora do repositório: não se podem verificar a partir do repositório sem voltar a correr.

**Passagem 1** (`scenario_basic.mjs`): 13 de 18 chamadas com `ok=true`. As cinco restantes são as esperadas, exceto `export_mesh_library`, `update_project_uids` e `get_uid`, que estão marcadas abaixo.

| Ferramenta | Resultado | Nota |
|---|---|---|
| `get_godot_version` | OK | `4.7.2.stable.official` |
| `list_projects` (recursivo) | OK | encontra o projeto de teste |
| `get_project_info` | OK | estrutura e versão |
| `create_scene` | OK | cria `.tscn` (Node3D ou Node2D) |
| `add_node` | OK | nó presente no `.tscn`; ver instabilidade abaixo |
| `save_scene` (`newPath`) | OK | cria a variante |
| `load_sprite` | **falha sem import** | `No loader found for resource: res://icon.png` |
| `export_mesh_library` | **sucesso sem efeito** | reporta «exported successfully»; o ficheiro não foi criado (cena sem malhas) |
| `update_project_uids` | **sucesso sem efeito** | «updated successfully», 0 ficheiros `.uid` (projeto não importado) |
| `get_uid` | **sucesso sem efeito** | devolve «UID for main.gd:» sem `uid://` (projeto não importado) |
| `run_project` | OK | arranca o projeto em modo debug (abre janela) |
| `get_debug_output` (a meio) | OK | captura o início e os ticks |
| `get_debug_output` (depois de terminar) | erro | «No active Godot process»: a saída não é devolvida |
| `stop_project` (já terminado) | erro | «No active Godot process to stop» |
| `get_project_info` (caminho inexistente) | erro claro | «Not a valid Godot project» |
| `create_scene` com `..` no caminho | recusado | «Invalid path»; nada escrito fora do projeto |

**Passagem 2** (`scenario_long.mjs`): 8 de 9 chamadas com `ok=true`. Depois do `--import` feito pelo Godot fora do MCP: `update_project_uids` reporta 1 ficheiro `.uid` (`main.gd.uid`), `get_uid` devolve um `uid://`, e `load_sprite` referencia a textura. Não se separa aqui o que o import criou do que o MCP criou. Com um projeto de 30 s, a saída lida a meio mostra 7 ticks aos ~9 s e 13 aos ~15 s. `stop_project` a meio funciona. A única chamada com erro é `get_debug_output` depois de parar, que é o comportamento esperado.

## Limites e observações

1. **Sucesso sem efeito.** Três ferramentas reportam sucesso sem criar o resultado (`export_mesh_library`, `get_uid`, `update_project_uids`). Não se pode confiar só no `ok`: é preciso verificar o ficheiro ou o UID depois.
2. **Depende do import.** `load_sprite` e os UIDs só funcionam depois de o projeto ser importado. Um PNG inválido fica com `valid=false` no `.import` e nunca é carregado. O teste usou um PNG gerado no script, válido.
3. **Saída só enquanto o projeto corre.** Um projeto que termina sozinho deixa de ter saída disponível. Para testes curtos, é mais simples correr o Godot em `--headless` pela linha de comandos.
4. **Instabilidade do `add_node`.** Numa execução, a leitura imediata do `.tscn` falhou (o nó não estava lá), e depois de 1 s estava presente. Nas duas execuções seguintes, a leitura imediata passou. Não encontrei a causa. Fica registado como intermitente.
5. **Reescrita das cenas.** As cenas passam pelo Godot: ganham `unique_id=` (formato 4.6+) e podem ser reformatadas. Por isso não devem ser usadas nas cenas geradas por `tools/dev/build_islands.gd` nem em `game/world/handmade/` (ver `tools/dev/build_islands.gd:7-8` e `.gitignore:18-20`).
6. **Não testado:** `launch_editor` (abre o editor), `export_mesh_library` com malhas, comportamento em sessões na cloud, e resposta a pedidos concorrentes.

## Recomendação

Testado, funciona para criar e editar cenas e para correr o projeto e ler a saída. Dos três repositórios avaliados, é o que mais pode ajudar já, mas com ganho ainda não medido face ao Godot por linha de comandos que já usamos.

Se for adotado, com estas regras: fixar a versão (0.1.1); não usar nas cenas geradas nem nas feitas à mão; verificar o efeito no disco depois de cada operação de escrita; usar só para cenas de teste em `spikes/` e para correr o jogo e ler erros. A decisão de adotar fica com o utilizador.

## Critério de decisão (acordado a 2026-11-04)

O MCP fica registado para três tarefas reais, feitas em sessão depois de reiniciar o Claude Code (as ferramentas só aparecem depois do reinício):

1. Correr o jogo e ler um erro real (`run_project` e `get_debug_output`).
2. Criar uma cena de teste em `spikes/` e confirmar o ficheiro no disco.
3. Editar uma cena de teste existente e confirmar a alteração no disco.

Para cada tarefa, registar o tempo e se o resultado está correto, e comparar com a linha de comando que já usamos. Se não ganhar em pelo menos uma tarefa, remove-se. Regras que se mantêm: versão 0.1.1 fixa; nunca em cenas geradas nem em `game/world/handmade/`; verificar sempre o efeito no disco.

Registo atual: o MCP fica registado **só para este projeto, nesta máquina** (escopo `local`, fora do repositório). Para remover: `claude mcp remove godot --scope local`.
