---
titulo: "Assets e licenças"
tipo: "nota"
estado: "consulta"
atualizado: "2026-11-14"
tags: ["horde-breaker"]
fontes: ["assets/LICENSES.md", "docs/DECISIONS.md", "docs/tech/ASSETS.md", "docs/tech/PLUGINS_REVIEW.md", "docs/tech/CREDITS.md"]
---

# Assets e licenças

O registo de licenças é [[90 Referências/assets/LICENSES|LICENSES]]. Licenças livres não são todas equivalentes: algumas exigem atribuição, preservar avisos ou outras condições.

## Exceções explicitamente registadas

| Conteúdo | Licença / obrigação a consultar |
|---|---|
| Dados OpenStreetMap | ODbL; crédito «© OpenStreetMap contributors» |
| Céu noturno Sky3D, ESO/S. Brunier | CC BY 4.0; atribuição específica nos créditos |
| Special Elite | Apache 2.0, aceite a 2026-11-11 |
| Libre Franklin | OFL |
| Assets originais com declaração CC0 | Confirmar os ficheiros de licença da entrega; não generalizar a assets de terceiros |

## Poly Haven (CC0): estado de cada asset em 2026-11-14

| Asset | Descarregado | Preparado | Integrado | Visto em jogo |
|---|---|---|---|---|
| portable_generator, wooden_crate_02, metal_jerrycan_green, concrete_road_barrier_02 | sim | sim | sim | sim |
| boulder_01 (3 984 triângulos, 1K) | sim | sim | sim, `beach_01` | só em capturas |
| coast_sand_01 (1K) | sim | sim | sim, `beach_01` | só em capturas |
| «Venus», fourareen (barco; Scottish Maritime Museum, não Poly Haven) | sim | sim | sim, todas as ilhas com barco | só em capturas |
| modular_wooden_pier, secção 02 (cais) | sim | sim | sim, todas as ilhas com barco | só em capturas |
| modular_fort_01, Barrel_02, barrel_stove, industrial_storage_cart, lifebuoy, vintage_radio_transceiver | sim | não | não | não |

Os originais ficam em `assets/source/polyhaven/`, fora do git. Pormenores e medidas: `docs/tech/BEACH_VISUAL_PILOT.md`. Ver também [[04 Arte e interface/Ilhas - melhoria visual]].

As exceções aprovadas são específicas; aceitar o céu CC BY não autoriza qualquer modelo CC BY. Antes de integrar algo, conferir licença, origem, necessidade de créditos e escala/custo.

[[90 Referências/docs/tech/ASSETS|ASSETS]] · [[90 Referências/docs/tech/PLUGINS_REVIEW|PLUGINS_REVIEW]] · [[90 Referências/docs/tech/CREDITS|CREDITS]] · [[05 Desenvolvimento/Ferramentas e plugins]].
