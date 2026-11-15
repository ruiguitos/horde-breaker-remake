---
titulo: "Ilhas — melhoria visual"
tipo: "implementacao"
estado: "piloto_beach_implementado"
atualizado: "2026-11-14"
tags: ["horde-breaker", "mapas", "assets", "arte"]
---

# Ilhas — melhoria visual

Relacionado: [[04 Arte e interface/Arte e interface]] · [[04 Arte e interface/Assets e licenças]] · [[05 Desenvolvimento/Ferramentas e plugins]].

O piloto da `beach_01` foi implementado a 2026-11-14 por Codex, com planeamento
e revisão do Claude Code. Tem fachadas, materiais PBR, quatro camadas de terreno,
rochas e destroços costeiros e erva em lâminas. Passagens, alturas e marcadores
mantêm-se. As restantes quatro ilhas aguardam avaliação do piloto.

A avaliação completa está em `docs/tech/MAP_VISUAL_REWORK.md`, no repositório:
inventário local, cinco candidatos CC0 com links/tamanhos, alternativas,
ferramentas e limites de navegação/desempenho. A implementação está documentada
em `docs/tech/BEACH_VISUAL_PILOT.md`; foram integrados Boulder 01 e Coast Sand 01,
ambos CC0 e a 1K, com manifestos e preparação offline.

Suite: 89/89 testes, seguida de oito testes afetados repetidos. Grelha PNG
antes/depois idêntica. Capturas reais em `docs/design/beach_pilot_20261114/`.
Falta avaliação a jogar, luz horror, modelos menos geométricos e vegetação maior.
O gerador substitui o conteúdo de Dressing: conservar alterações no script de
autoria, em vez de esperar que uma edição manual sobreviva à reaplicação.

Entrega e prompt para Claude: `docs/history/2026-11-14_BEACH_VISUAL_PILOT_HANDOFF.md`.

## Revisão de 2026-11-14 (Claude Code)

- **Avaliação do piloto:** as fachadas, as telhas e os materiais resultam; a aldeia já lê como
  aldeia. Continuam fracos a erva (pequena e rara), o terreno entre casas (uniforme), os
  volumes das casas, da torre, da ponte e do barco, e as falésias esticadas.
- **Luz do horror corrigida:** luz ambiente com cor própria, névoa do chão mais fina e
  contraluz um pouco mais forte. Antes e depois em `docs/design/beach_pilot_20261114/`
  (`horror_bridge_fixed.png` e `horror_bridge_fixed_v2.png`). Por confirmar a jogar.
- **Originais já descarregados e por usar:** um barco (fourareen) e um cais modular, que servem
  o barco de extração e a ponte. Estado de cada asset em
  [[04 Arte e interface/Assets e licenças]].
- **Próxima ação:** preparar esses dois originais (triângulos, texturas a 1K, medidas) e
  pô-los na `beach_01`. Lista ativa: `TODO.md`, secção «Conteúdo e apresentação».
- **Barco e cais feitos (2026-11-14):** o fourareen e uma secção do cais modular foram
  preparados (5983 e 2484 triângulos, texturas a 1K) e aparecem no ponto de extração de todas as
  ilhas com barco. Captura: `docs/design/beach_pilot_20261114/boat_and_pier.png`.
- **Casas e plantas (2026-11-15):** soco de pedra, cunhais e degrau em cada casa; 140 plantas
  baixas junto a paredes, falésias e rochas, metade à volta da aldeia. Captura:
  `docs/design/beach_pilot_20261114/houses_and_plants.png`.
- Não houve parecer JEV novo nesta revisão; o último é o 07.

Terrain3D, Sky3D, Road Generator e Color Grading já estão ativos. ProtonScatter
é apenas candidato: a listagem atual está marcada como instável. A pintura
de vegetação do Terrain3D 1.0.2 não gera colisões; bloquear a horda também
exige respeitar a grelha de `HandmadeIsland`.

Parecer documental: [[99 Ferramentas/JEV/06_mapas_assets_plugins.json]].
Revisão da implementação: [[99 Ferramentas/JEV/07_beach_visual_pilot.json]] —
consultiva, sem aprovação automática; confirma as verificações de grelha e
adereços, mas pede revisão por confiança insuficiente e evidência parcial da
cronologia dos testes.
