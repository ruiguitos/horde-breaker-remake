---
titulo: "Bioma — Jungle"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-14"
tags: ["horde-breaker", "biomes"]
fontes: ["game/data/biomes/jungle.tres", "game/data/resources/biome_data.gd"]
---

# Bioma — Jungle

← [[02 Conteúdo/Biomas|Biomas]]

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `jungle` · **Nome no jogo:** Jungle

| Campo | Valor | Origem |
|---|---|---|
| coast | Color(0.6, 0.58, 0.4, 1) | `.tres` |
| inland | Color(0.2, 0.35, 0.15, 1) | `.tres` |
| building | Color(0.4, 0.42, 0.36, 1) | `.tres` |
| foliage | Color(0.12, 0.38, 0.14, 1) | `.tres` |
| sky | Color(0.3, 0.42, 0.34, 1) | `.tres` |
| fog | 0.006 | `.tres` |
| palms | Sim | `.tres` |
| Disponível nas rotas | Sim | Por defeito no Resource |
| grading | SubResource("CompositorEffect_grade") | `.tres` |

## Fontes

- `game/data/biomes/jungle.tres`
- `game/data/resources/biome_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
