---
titulo: "Arquitetura observada"
tipo: "nota"
estado: "consulta"
atualizado: "2026-11-14"
tags: ["horde-breaker"]
fontes: ["project.godot", "docs/tech/ARCHITECTURE.md", "docs/registry/architecture.yaml", "docs/architecture/tr-registry.yaml", "game/world/island_run.gd"]
---

# Arquitetura observada

## Organização presente

| Área | Papel a investigar |
|---|---|
| `game/main.gd`, `states/` | Entrada, transições e ecrãs de estado |
| `game/core/` | Perfil, contexto e configurações |
| `game/data/` | Resources, registos YARD e constantes GameData |
| `game/world/island_run.gd` | Regras da simulação, separadas da apresentação |
| `game/world/island.gd`, `handmade/` | Cena, input, render e mapas |
| `game/horde/` | Simulação espacial da horda |
| `game/ui/`, `game/audio/` | Interface e apresentação sonora |

[[05 Desenvolvimento/Mapa do código]] lista classes e bases efetivamente declaradas. O projeto contém dependências autoload em `project.godot`; não assumir os três autoloads propostos no documento antigo de arquitetura.

[[90 Referências/docs/tech/ARCHITECTURE|ARCHITECTURE]] apresenta-se como proposta de pré-produção e preserva estruturas que não são automaticamente as atuais. [[90 Referências/docs/registry/architecture.yaml|Registo de arquitetura]] e [[90 Referências/docs/architecture/tr-registry.yaml|Registo técnico]] ficam disponíveis como referências, sem lhes atribuir atualização garantida.
