# Exportação para Windows

Estado: **validada** (2026-10-18). Com o Godot 4.7.2 e os templates normais, o
export gera `build/HordeBreaker.exe` (cerca de 303 MB, com o PCK embutido) e o
executável arranca em modo headless, corre 300 frames e sai com código 0, sem
erros de script.

O `export_presets.cfg` não está versionado (está no `.gitignore`, porque guarda
caminhos da máquina). Quem exporta cria o preset uma vez, com os passos abaixo.

## Templates

- A versão do editor é `4.7.2.stable`. O editor procura os templates em
  `%APPDATA%\Godot\export_templates\4.7.2.stable\` (com o patch).
- Os templates normais vêm do repositório oficial do Godot
  (`Godot_v4.7.2-stable_export_templates.tpz`, cerca de 1,28 GB). Instalam-se em
  **Editor → Gerir modelos de exportação**, ou extraindo a pasta `templates/` do
  `.tpz` para a pasta acima.
- Os de **mono** (`4.7.stable.mono`) não servem: o projeto é só GDScript.

## Preset (uma vez)

1. Projeto → Exportar → Adicionar → Windows Desktop.
2. Caminho: `build/HordeBreaker.exe` (a pasta `build/` está no `.gitignore`).
3. Exportar PCK embutido no executável: sim.
4. Filtro de recursos **a excluir**:
   - `addons/GD-Sync/keys.cfg` (chaves; nunca sair com o jogo)
   - `game/world/handmade/world_test_handmade.tscn` e `game/world/handmade/world_test_handmade_data/*` (cena pessoal)
   - `Arts/*` (pasta sem uso no jogo; tem UIDs duplicados)
   - `addons/dialogue_manager/example_balloon/*` e `addons/dialogue_manager/nodes/dialogue_label/*` (exemplos do addon, com ficheiros C#)
5. Filtro a **incluir**: `assets/LICENSES.md`, para as licenças irem com o jogo.
6. Versão e nome no separador do Windows. A versão (`application/config/version`)
   já está em `0.1.0`.

## Comando

Com o preset criado, na raiz do projeto:

```bash
godot --headless --path . --export-release "Windows Desktop" build/HordeBreaker.exe
```

## Armadilhas encontradas

- **Editor aberto a bloquear a DLL.** Com o editor aberto a usar o Terrain3D, o
  export falha ao copiar `libterrain.windows.debug.x86_64.dll` (`~libterrain...`).
  Fecha o editor antes de exportar, ou exporta a partir de um clone limpo.
- **Clone limpo.** Para exportar sem o editor: `git clone` do repositório para
  uma pasta nova, copiar o `export_presets.cfg` para lá e correr o comando acima.
  No Windows, ativar `git config core.longpaths true` no clone: alguns ficheiros
  de `assets/` ultrapassam o limite de 260 caracteres.
- **Nome do preset com espaços.** Em `Start-Process`, passar o nome entre aspas
  dentro de uma linha única, ou usar `&` com os argumentos separados.

## Avisos conhecidos (não afetam o executável)

- `ColorGrading._notification` (addon `Color grading`, `Compositor/General/BaseCompositorEffect.gd`):
  erro `_reload` ao libertar o efeito durante o export. Ocorre só no ramo do editor
  (`Engine.is_editor_hint()`); o executável não passa por ele. Não corrigido no addon.
- `leaked at exit` no fim do processo: o mesmo aviso de encerramento que os testes
  mostram no Windows.

## O que verificar antes de distribuir

- O executável arranca sem editor e chega ao título. (Feito em headless; a janela
  e o ecrã ainda não foram vistos.)
- Não há `Test Island` nem noclip: ambos dependem de `OS.is_debug_build()`, que é
  falso numa exportação de release.
- `user://` tem perfil e telemetria no caminho de utilizador esperado.
- Os testes headless correm sobre o projeto, não sobre o executável.
