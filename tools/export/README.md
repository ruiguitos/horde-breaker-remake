# Exportação para Windows

Estado: **não validada**. Não há `export_presets.cfg` versionado (está no
`.gitignore`, porque guarda caminhos da máquina), e a exportação precisa dos
templates **4.7 stable** (não os de mono). Quem exporta cria o preset uma vez
e corre o comando abaixo.

## Preset (uma vez, no editor)

1. Projeto → Exportar → Adicionar → Windows Desktop.
2. Caminho: `build/HordeBreaker.exe` (a pasta `build/` já está no `.gitignore`).
3. Exportar PCK embutido no executável: sim.
4. Filtro de recursos **a excluir**, para não sair com o pacote:
   - `addons/GD-Sync/keys.cfg`, se existir (chaves; nunca sair com o jogo; hoje o co-op não está ligado)
   - `game/world/handmade/world_test_handmade.tscn` e `game/world/handmade/world_test_handmade_data/*` (cena pessoal)
5. Filtro a **incluir**: `assets/LICENSES.md`, para as licenças irem com o jogo
   (os créditos no ecrã já existem; o ficheiro cobre a parte escrita).
6. Versão e ícone no separador do Windows. A versão do projeto
   (`application/config/version`) ainda não está definida; a telemetria regista
   `dev` até estar. Definir antes da primeira versão distribuída.

## Comando

Depois de o preset existir, em PowerShell na raiz do projeto:

```bash
godot --headless --path . --export-release "Windows Desktop" build/HordeBreaker.exe
```

## O que verificar antes de distribuir

- O executável arranca sem editor e chega ao título.
- Não há Opção de teste (`Test Island`) nem noclip: ambos dependem de
  `OS.is_debug_build()`, que é falso numa exportação de release.
- `user://` tem perfil e telemetria no caminho de utilizador esperado.
- Os testes headless correm sobre o projeto, não sobre o executável; não
  substituem esta verificação.
