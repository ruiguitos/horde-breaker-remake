---
titulo: "Horda e diretor"
tipo: "nota"
estado: "consulta"
atualizado: "2026-11-14"
tags: ["horde-breaker"]
fontes: ["game/world/director.gd", "game/world/island_run.gd", "game/world/zombie_model.gd", "TODO.md", "docs/tech/SPECIAL_ENEMY_MODELS.md"]
---

# Horda e diretor

O diretor alterna crescimento, pico e alívio. A horda usa agentes como dados, pesquisas espaciais e flow field; a apresentação usa MultiMesh e shaders nos comuns. Não corresponde a um nó completo por zombie.

| Área | Fonte de implementação |
|---|---|
| Simulação da horda | `game/horde/` |
| Ritmo de população | `game/world/director.gd` |
| Regras de combate da ilha | `game/world/island_run.gd` |
| Aparência e deformação | `game/world/zombie_model.gd` e shaders associados |
| Especializados e boss | `game/world/special_enemy_model.gd` |

Limites de população dependem do modo e da dificuldade. O TODO pede observação da distribuição depois da correção de 2026-11-10; a existência do teste não prova leitura visual satisfatória.

[[02 Conteúdo/Inimigos]] · [[03 Sistemas/Exfil]] · [[05 Desenvolvimento/Desempenho]] · [[90 Referências/docs/tech/SPECIAL_ENEMY_MODELS|SPECIAL_ENEMY_MODELS]].
