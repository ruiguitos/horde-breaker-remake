---
titulo: "Perk — Opening Volley"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-15"
tags: ["horde-breaker", "perks"]
fontes: ["game/data/perks/opening_volley.tres", "game/data/resources/perk_data.gd"]
---

# Perk — Opening Volley

← [[02 Conteúdo/Perks|Perks]]

Explosive entry: break in, then open fire.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `opening_volley` · **Nome no jogo:** Opening Volley

| Campo | Valor | Origem |
|---|---|---|
| Ramo | combat | `.tres` |
| Patamar | 3 | `.tres` |
| Alternativa (0=A, 1=B) | 0 | `.tres` |
| Filtro de classe |  | Por defeito no Resource |
| Benefício | After a Breaker: primary damage +{v}% for 2 s | `.tres` |
| Valores do benefício (I/II/III) | PackedFloat32Array(10, 20, 30) | `.tres` |
| Valores do segundo benefício | PackedFloat32Array() | Por defeito no Resource |
| Contrapartida | Breaker cooldown +{v} s | `.tres` |
| Valores da contrapartida (I/II/III) | PackedFloat32Array(0.5, 1, 1.5) | `.tres` |

Os arrays de valores são totais por rank, não incrementos. Os ranks pertencem ao nó; há alternativas com contrapartidas. Ver [[03 Sistemas/Intel e perks]].

## Fontes

- `game/data/perks/opening_volley.tres`
- `game/data/resources/perk_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
