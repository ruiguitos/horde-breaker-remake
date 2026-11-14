---
titulo: "Perk — Bulwark"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-14"
tags: ["horde-breaker", "perks"]
fontes: ["game/data/perks/bulwark.tres", "game/data/resources/perk_data.gd"]
---

# Perk — Bulwark

← [[02 Conteúdo/Perks|Perks]]

Stand firm behind the War Cry.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `bulwark` · **Nome no jogo:** Bulwark

| Campo | Valor | Origem |
|---|---|---|
| Ramo | breaker | `.tres` |
| Patamar | 3 | `.tres` |
| Alternativa (0=A, 1=B) | 0 | `.tres` |
| Filtro de classe | vanguard | `.tres` |
| Benefício | War Cry lasts +{v} s | `.tres` |
| Valores do benefício (I/II/III) | PackedFloat32Array(0.5, 1, 1.5) | `.tres` |
| Valores do segundo benefício | PackedFloat32Array() | Por defeito no Resource |
| Contrapartida | Speed during War Cry −{v}% | `.tres` |
| Valores da contrapartida (I/II/III) | PackedFloat32Array(10, 20, 30) | `.tres` |

Os arrays de valores são totais por rank, não incrementos. Os ranks pertencem ao nó; há alternativas com contrapartidas. Ver [[03 Sistemas/Intel e perks]].

## Fontes

- `game/data/perks/bulwark.tres`
- `game/data/resources/perk_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
