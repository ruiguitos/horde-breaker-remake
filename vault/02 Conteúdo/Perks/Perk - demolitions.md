---
titulo: "Perk — Demolitions"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-15"
tags: ["horde-breaker", "perks"]
fontes: ["game/data/perks/demolitions.tres", "game/data/resources/perk_data.gd"]
---

# Perk — Demolitions

← [[02 Conteúdo/Perks|Perks]]

Frequent grenade cover.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `demolitions` · **Nome no jogo:** Demolitions

| Campo | Valor | Origem |
|---|---|---|
| Ramo | breaker | `.tres` |
| Patamar | 3 | `.tres` |
| Alternativa (0=A, 1=B) | 0 | `.tres` |
| Filtro de classe | recruit | `.tres` |
| Benefício | Grenade cooldown −{v}% | `.tres` |
| Valores do benefício (I/II/III) | PackedFloat32Array(12, 24, 35) | `.tres` |
| Segundo benefício | Grenade radius +{v} m | `.tres` |
| Valores do segundo benefício | PackedFloat32Array(0.3, 0.6, 1) | `.tres` |
| Contrapartida | Grenade damage −{v}% | `.tres` |
| Valores da contrapartida (I/II/III) | PackedFloat32Array(10, 20, 30) | `.tres` |

Os arrays de valores são totais por rank, não incrementos. Os ranks pertencem ao nó; há alternativas com contrapartidas. Ver [[03 Sistemas/Intel e perks]].

## Fontes

- `game/data/perks/demolitions.tres`
- `game/data/resources/perk_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
