---
titulo: "Combate e movimento"
tipo: "nota"
estado: "consulta"
atualizado: "2026-11-15"
tags: ["horde-breaker"]
fontes: ["game/data/game_data.gd", "game/world/island_run.gd", "docs/DECISIONS.md", "docs/tech/COMBAT_CATALOG.md"]
---

# Combate e movimento

O jogador escolhe posição e orientação; o auto-fire decide disparar quando há um alvo válido. A mira e os testes de headshot diferem entre a câmara fixa e as câmaras com mira. Ver [[04 Arte e interface/Câmaras e controlos]].

O sprint dispara por regra base desde 2026-10-14. Carregar bidões impõe restrições próprias. O Breaker abre caminho e liberta Grabbers. As fórmulas de classe, cartas, perks e dificuldade modificam os valores base abaixo.

| Constante observada | Valor literal |
|---|---|
| `PLAYER_MAX_HP` | 100.0 |
| `PLAYER_SPEED` | 6.0 |
| `PLAYER_RADIUS` | 0.4 |
| `BREAKER_DISTANCE` | 5.0 |
| `BREAKER_DURATION` | 0.18 |
| `BREAKER_COOLDOWN` | 6.0 |
| `BREAKER_RADIUS` | 2.2 |
| `BREAKER_DAMAGE` | 15.0 |
| `BREAKER_STUN` | 1.0 |
| `SPRINT_MULTIPLIER` | 1.6 |
| `STAMINA_MAX` | 3.0 |
| `STAMINA_REGEN` | 0.75 |
| `STAMINA_REGEN_DELAY` | 0.8 |
| `MAX_MELEE_PER_FRAME` | 25.0 |
| `HEADSHOT_MULTIPLIER` | 2.5 |
| `HEADSHOT_CONE_DEG` | 9.0 |
| `CROSSHAIR_CONE_DEG` | 6.0 |

Unidades e significado completos estão nos comentários de `game/data/game_data.gd` e no catálogo técnico. O limite de dano corpo a corpo é por passo da simulação; não equivale a um teto universal para todos os ataques.

[[02 Conteúdo/Armas]] · [[02 Conteúdo/Classes]] · [[02 Conteúdo/Inimigos]] · [[90 Referências/docs/tech/COMBAT_CATALOG|COMBAT_CATALOG]].
