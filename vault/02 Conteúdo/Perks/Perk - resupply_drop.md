---
titulo: "Perk — Resupply Drop"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-14"
tags: ["horde-breaker", "perks"]
fontes: ["game/data/perks/resupply_drop.tres", "game/data/resources/perk_data.gd"]
---

# Perk — Resupply Drop

← [[02 Conteúdo/Perks|Perks]]

Ammo drops from generators, signals and escort stops come in heavier.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `resupply_drop` · **Nome no jogo:** Resupply Drop

| Campo | Valor | Origem |
|---|---|---|
| Ramo | logistics | `.tres` |
| Patamar | 2 | `.tres` |
| Alternativa (0=A, 1=B) | 1 | `.tres` |
| Filtro de classe |  | Por defeito no Resource |
| Benefício | Generator, signal and escort-stop ammo +{v}% | `.tres` |
| Valores do benefício (I/II/III) | PackedFloat32Array(30, 45, 60) | `.tres` |
| Valores do segundo benefício | PackedFloat32Array() | Por defeito no Resource |
| Valores da contrapartida (I/II/III) | PackedFloat32Array() | Por defeito no Resource |

Os arrays de valores são totais por rank, não incrementos. Os ranks pertencem ao nó; há alternativas com contrapartidas. Ver [[03 Sistemas/Intel e perks]].

## Fontes

- `game/data/perks/resupply_drop.tres`
- `game/data/resources/perk_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
