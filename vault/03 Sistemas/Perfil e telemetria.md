---
titulo: "Perfil e telemetria"
tipo: "nota"
estado: "consulta"
atualizado: "2026-11-15"
tags: ["horde-breaker"]
fontes: ["game/core/profile.gd", "game/core/run_context.gd", "docs/tech/COMBAT_CATALOG.md", "TODO.md"]
---

# Perfil e telemetria

O perfil persiste preferências, Intel e desbloqueios; o contexto da run liga os estados durante a viagem. A lógica deve suportar saves antigos e tratar seleções inválidas.

| Ficheiro | Papel a consultar |
|---|---|
| `game/core/profile.gd` | Perfil, preferências e migrações |
| `game/core/run_context.gd` | Estado que transita entre partes da run |
| `game/world/island_run.gd` | Eventos e resultados da simulação |

A remoção da Heavy Pistol deve converter seleções antigas para Shotgun sem reembolso, conforme o catálogo técnico e a escolha do utilizador. Isso não implica conceder uma arma nova ou devolver Intel.

Para telemetria e limitações por modo, consultar [[90 Referências/game/README|README]], [[90 Referências/TODO|TODO]] e os testes correspondentes. Não foram abertos saves pessoais nesta tarefa.
