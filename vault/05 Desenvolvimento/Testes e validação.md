---
titulo: "Testes e validação"
tipo: "nota"
estado: "consulta"
atualizado: "2026-11-15"
tags: ["horde-breaker"]
fontes: ["AGENTS.md", "tests/run_all.gd", "TODO.md"]
---

# Testes e validação

89 ficheiros de teste foram descobertos; consultar [[05 Desenvolvimento/Inventário de testes]]. **Não foram corridos nesta tarefa documental.**

## Regra atual de aprovação

O teste passa se termina com código 0, imprime pelo menos uma linha `TEST: ` e não contém `TEST FAIL`, `SCRIPT ERROR` ou `Parse Error`. Crash codes falham mesmo depois dos resultados, salvo exceção explicitamente listada em `KNOWN_SHUTDOWN_CRASH`.

## Comandos no diretório do projeto

```powershell
& 'C:/Users/Rui/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/run_all.gd
```

Teste isolado: substituir `res://tests/run_all.gd` pelo teste pretendido. Depois de novos `class_name`, seguir a importação e o restauro das bibliotecas atuais indicados no AGENTS; não reutilizar o comando antigo com Orchestrator e TerraBrush.

Playtests, comando físico, validação visual, som e medição em GPU não são substituídos por testes headless.

Fontes: [[90 Referências/AGENTS - referência|AGENTS]] · `tests/run_all.gd` · [[90 Referências/TODO|TODO]].
