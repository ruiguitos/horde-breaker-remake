---
titulo: "XP e cartas"
tipo: "nota"
estado: "consulta"
atualizado: "2026-11-14"
tags: ["horde-breaker"]
fontes: ["game/data/game_data.gd", "game/world/island_run.gd", "game/world/card_offers.gd", "docs/DECISIONS.md"]
---

# XP e cartas

Os abates deixam XP. Ao subir de nível escolhe-se uma carta; as ofertas e os filtros vivem em `game/world/card_offers.gd`. As fichas estão em [[02 Conteúdo/Cartas]].

## Regras a acompanhar

- A curva observada em `GameData.xp_for_level` é `10 × (8 + 6L + L²)` para o nível atual L.
- Fast Learner anuncia +5% por rank. A recolha usa o multiplicador e guarda a fração em `xp_fraction`; o arredondamento não deve perder sistematicamente o bónus.
- O nível de recolha automática de XP definido nos dados é 30.
- Há um reroll gratuito por ecrã; não acumula. Extra Reroll aplica-se ao ecrã seguinte.
- Cartas no rank máximo não devem continuar nas ofertas; isto pertence às regras de ofertas, não apenas ao texto da carta.

| Nível L | XP necessária pela fórmula base |
|---:|---:|
| 1 | 150 |
| 10 | 1 680 |
| 30 | 10 880 |

Esta nota não mede o tempo real para ganhar níveis. O equilíbrio precisa de runs e telemetria.

Fontes: `game/data/game_data.gd::xp_for_level`, `game/world/island_run.gd::_collect_xp_orb`, `game/world/card_offers.gd`, [[90 Referências/docs/DECISIONS|DECISIONS]].
