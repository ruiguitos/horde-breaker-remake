---
titulo: "Bioma — Industrial Port"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-14"
tags: ["horde-breaker", "biomes"]
fontes: ["game/data/biomes/port.tres", "game/data/resources/biome_data.gd"]
---

# Bioma — Industrial Port

← [[02 Conteúdo/Biomas|Biomas]]

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `port` · **Nome no jogo:** Industrial Port

| Campo | Valor | Origem |
|---|---|---|
| coast | Color(0.5, 0.5, 0.48, 1) | `.tres` |
| inland | Color(0.36, 0.36, 0.36, 1) | `.tres` |
| building | Color(0.7, 0.3, 0.2, 1) | `.tres` |
| foliage | Color(0.25, 0.4, 0.22, 1) | `.tres` |
| sky | Color(0.6, 0.62, 0.66, 1) | `.tres` |
| fog | 0.0 | Por defeito no Resource |
| palms | Não | Por defeito no Resource |
| Disponível nas rotas | Sim | Por defeito no Resource |
| grading | SubResource("CompositorEffect_grade") | `.tres` |

## Fontes

- `game/data/biomes/port.tres`
- `game/data/resources/biome_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
