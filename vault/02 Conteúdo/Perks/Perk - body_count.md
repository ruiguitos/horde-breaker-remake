---
titulo: "Perk — Body Count"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-15"
tags: ["horde-breaker", "perks"]
fontes: ["game/data/perks/body_count.tres", "game/data/resources/perk_data.gd"]
---

# Perk — Body Count

← [[02 Conteúdo/Perks|Perks]]

Steady fire into the crowd.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `body_count` · **Nome no jogo:** Body Count

| Campo | Valor | Origem |
|---|---|---|
| Ramo | combat | `.tres` |
| Patamar | 1 | `.tres` |
| Alternativa (0=A, 1=B) | 1 | `.tres` |
| Filtro de classe |  | Por defeito no Resource |
| Benefício | Body-shot damage +{v}% | `.tres` |
| Valores do benefício (I/II/III) | PackedFloat32Array(10, 20, 30) | `.tres` |
| Valores do segundo benefício | PackedFloat32Array() | Por defeito no Resource |
| Contrapartida | No headshots | `.tres` |
| Valores da contrapartida (I/II/III) | PackedFloat32Array(1, 1, 1) | `.tres` |

Os arrays de valores são totais por rank, não incrementos. Os ranks pertencem ao nó; há alternativas com contrapartidas. Ver [[03 Sistemas/Intel e perks]].

## Fontes

- `game/data/perks/body_count.tres`
- `game/data/resources/perk_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
