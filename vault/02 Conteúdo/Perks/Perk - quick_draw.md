---
titulo: "Perk — Quick Draw"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-14"
tags: ["horde-breaker", "perks"]
fontes: ["game/data/perks/quick_draw.tres", "game/data/resources/perk_data.gd"]
---

# Perk — Quick Draw

← [[02 Conteúdo/Perks|Perks]]

Emergency answer: swap and unload.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `quick_draw` · **Nome no jogo:** Quick Draw

| Campo | Valor | Origem |
|---|---|---|
| Ramo | survival | `.tres` |
| Patamar | 2 | `.tres` |
| Alternativa (0=A, 1=B) | 1 | `.tres` |
| Filtro de classe |  | Por defeito no Resource |
| Benefício | Switching to the secondary: its fire rate +{v}% for 2 s (once per 8 s) | `.tres` |
| Valores do benefício (I/II/III) | PackedFloat32Array(15, 25, 35) | `.tres` |
| Valores do segundo benefício | PackedFloat32Array() | Por defeito no Resource |
| Contrapartida | Secondary max ammo −{v}% | `.tres` |
| Valores da contrapartida (I/II/III) | PackedFloat32Array(20, 35, 50) | `.tres` |

Os arrays de valores são totais por rank, não incrementos. Os ranks pertencem ao nó; há alternativas com contrapartidas. Ver [[03 Sistemas/Intel e perks]].

## Fontes

- `game/data/perks/quick_draw.tres`
- `game/data/resources/perk_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
