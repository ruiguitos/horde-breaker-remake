---
titulo: "Bioma — Volcano"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-14"
tags: ["horde-breaker", "biomes"]
fontes: ["game/data/biomes/volcano.tres", "game/data/resources/biome_data.gd"]
---

# Bioma — Volcano

← [[02 Conteúdo/Biomas|Biomas]]

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `volcano` · **Nome no jogo:** Volcano

| Campo | Valor | Origem |
|---|---|---|
| coast | Color(0.22, 0.2, 0.2, 1) | `.tres` |
| inland | Color(0.32, 0.28, 0.26, 1) | `.tres` |
| building | Color(0.3, 0.27, 0.26, 1) | `.tres` |
| foliage | Color(0.16, 0.13, 0.12, 1) | `.tres` |
| sky | Color(0.35, 0.18, 0.14, 1) | `.tres` |
| fog | 0.0 | Por defeito no Resource |
| palms | Não | Por defeito no Resource |
| Disponível nas rotas | Não | `.tres` |
| grading | SubResource("CompositorEffect_grade") | `.tres` |

## Fontes

- `game/data/biomes/volcano.tres`
- `game/data/resources/biome_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
