---
titulo: "Perk — Supply Run"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-15"
tags: ["horde-breaker", "perks"]
fontes: ["game/data/perks/supply_run.tres", "game/data/resources/perk_data.gd"]
---

# Perk — Supply Run

← [[02 Conteúdo/Perks|Perks]]

Supply caches patch you up and restock your ammo.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `supply_run` · **Nome no jogo:** Supply Run

| Campo | Valor | Origem |
|---|---|---|
| Ramo | logistics | `.tres` |
| Patamar | 1 | `.tres` |
| Alternativa (0=A, 1=B) | 0 | `.tres` |
| Filtro de classe |  | Por defeito no Resource |
| Benefício | Supply caches heal {v} HP | `.tres` |
| Valores do benefício (I/II/III) | PackedFloat32Array(10, 20, 30) | `.tres` |
| Segundo benefício | Supply caches restock {v}% ammo | `.tres` |
| Valores do segundo benefício | PackedFloat32Array(20, 35, 50) | `.tres` |
| Valores da contrapartida (I/II/III) | PackedFloat32Array() | Por defeito no Resource |

Os arrays de valores são totais por rank, não incrementos. Os ranks pertencem ao nó; há alternativas com contrapartidas. Ver [[03 Sistemas/Intel e perks]].

## Fontes

- `game/data/perks/supply_run.tres`
- `game/data/resources/perk_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
