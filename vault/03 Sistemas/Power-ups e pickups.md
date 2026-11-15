---
titulo: "Power-ups e pickups"
tipo: "nota"
estado: "consulta"
atualizado: "2026-11-15"
tags: ["horde-breaker"]
fontes: ["docs/tech/POWER_UPS_AND_DEFEAT.md", "docs/DECISIONS.md", "game/data/game_data.gd"]
---

# Power-ups e pickups

Power-ups de abate são recolhas temporárias distintas das cartas e das caixas de mantimentos. **Só têm efeito quando apanhados.** Expirar ou sair sem recolher significa perder o power-up.

Há 7 tipos em [[02 Conteúdo/Power-ups]]. Cada ficha apresenta os campos do seu Resource; regras globais de queda, pity e tempo no chão ficam em `game_data.gd`.

| Constante observada | Valor literal |
|---|---|
| `POWER_UP_CHANCE` | 0.015 |
| `POWER_UP_SPECIAL_CHANCE` | 0.05 |
| `POWER_UP_PITY_KILLS` | 60 |
| `POWER_UP_DROP_INTERVAL` | 35.0 |
| `POWER_UP_GROUND_SECONDS` | 25.0 |
| `POWER_UP_BLINK_SECONDS` | 10.0 |
| `POWER_UP_PICKUP_RADIUS` | 1.4 |

Probabilidades são frações de 0 a 1; intervalos e tempos estão em segundos, e o raio em metros. São valores para playtest.

Fontes: [[90 Referências/docs/tech/POWER_UPS_AND_DEFEAT|POWER_UPS_AND_DEFEAT]] · [[90 Referências/docs/DECISIONS|DECISIONS]] · `game/data/game_data.gd`.
