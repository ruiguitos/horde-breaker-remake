---
titulo: "Bioma — Beach"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-14"
tags: ["horde-breaker", "biomes"]
fontes: ["game/data/biomes/beach.tres", "game/data/resources/biome_data.gd"]
---

# Bioma — Beach

← [[02 Conteúdo/Biomas|Biomas]]

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `beach` · **Nome no jogo:** Beach

| Campo | Valor | Origem |
|---|---|---|
| coast | Color(0.78, 0.7, 0.5, 1) | `.tres` |
| inland | Color(0.62, 0.6, 0.42, 1) | `.tres` |
| building | Color(0.55, 0.42, 0.3, 1) | `.tres` |
| foliage | Color(0.3, 0.55, 0.25, 1) | `.tres` |
| sky | Color(0.5, 0.7, 0.85, 1) | `.tres` |
| fog | 0.0 | Por defeito no Resource |
| palms | Sim | `.tres` |
| Disponível nas rotas | Sim | Por defeito no Resource |
| grading | SubResource("CompositorEffect_grade") | `.tres` |

## Fontes

- `game/data/biomes/beach.tres`
- `game/data/resources/biome_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
