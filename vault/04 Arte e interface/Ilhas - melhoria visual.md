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

Terrain3D, Sky3D, Road Generator e Color Grading já estão ativos. ProtonScatter
é apenas candidato: a listagem atual está marcada como instável. A pintura
de vegetação do Terrain3D 1.0.2 não gera colisões; bloquear a horda também
exige respeitar a grelha de `HandmadeIsland`.

Parecer documental: [[99 Ferramentas/JEV/06_mapas_assets_plugins.json]].
Revisão da implementação: [[99 Ferramentas/JEV/07_beach_visual_pilot.json]] —
consultiva, sem aprovação automática; confirma as verificações de grelha e
adereços, mas pede revisão por confiança insuficiente e evidência parcial da
cronologia dos testes.
