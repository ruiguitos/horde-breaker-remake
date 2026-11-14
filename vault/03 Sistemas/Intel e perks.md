---
titulo: "Intel e perks"
tipo: "nota"
estado: "consulta"
atualizado: "2026-11-14"
tags: ["horde-breaker"]
fontes: ["game/data/game_data.gd", "game/data/resources/perk_data.gd", "game/core/profile.gd", "docs/design/CARDS_WEAPONS_PERKS.md"]
---

# Intel e perks

Intel é a progressão entre runs. Morrer conserva o que foi ganho; o multiplicador de extração configurado é 1,5. Os preços específicos constam das fichas de armas, classes, cartas e perks.

## Árvore observada

`game_data.gd` declara quatro ramos: **combat, survival, breaker e logistics**; três patamares e três ranks máximos. Há 26 Resources de alternativas. Recursos de alternativas, nós e slots não são a mesma contagem.

Os ranks são comprados por nó; as alternativas partilham ranks e podem ter filtros de classe. Os valores de benefício/penalização nos Resources são totais por rank. A regra de troca deve ser conferida no perfil e no Armory.

[[02 Conteúdo/Perks]] · [[02 Conteúdo/Armas]] · [[02 Conteúdo/Classes]].

Fontes: `game/data/game_data.gd`, `game/data/resources/perk_data.gd`, `game/core/profile.gd`, [[90 Referências/docs/design/CARDS_WEAPONS_PERKS|CARDS_WEAPONS_PERKS]].
