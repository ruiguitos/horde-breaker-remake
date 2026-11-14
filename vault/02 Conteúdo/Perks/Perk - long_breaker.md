---
titulo: "Perk — Battering Ram"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-14"
tags: ["horde-breaker", "perks"]
fontes: ["game/data/perks/long_breaker.tres", "game/data/resources/perk_data.gd"]
---

# Perk — Battering Ram

← [[02 Conteúdo/Perks|Perks]]

Charge right through the horde.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `long_breaker` · **Nome no jogo:** Battering Ram

| Campo | Valor | Origem |
|---|---|---|
| Ramo | breaker | `.tres` |
| Patamar | 1 | `.tres` |
| Alternativa (0=A, 1=B) | 0 | `.tres` |
| Filtro de classe |  | Por defeito no Resource |
| Benefício | Breaker distance +{v}% | `.tres` |
| Valores do benefício (I/II/III) | PackedFloat32Array(13, 27, 40) | `.tres` |
| Valores do segundo benefício | PackedFloat32Array() | Por defeito no Resource |
| Contrapartida | Breaker cooldown +{v} s | `.tres` |
| Valores da contrapartida (I/II/III) | PackedFloat32Array(0.5, 1, 1.5) | `.tres` |

Os arrays de valores são totais por rank, não incrementos. Os ranks pertencem ao nó; há alternativas com contrapartidas. Ver [[03 Sistemas/Intel e perks]].

## Fontes

- `game/data/perks/long_breaker.tres`
- `game/data/resources/perk_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
