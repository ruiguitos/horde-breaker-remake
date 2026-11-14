---
titulo: "Perk — Head Hunter"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-14"
tags: ["horde-breaker", "perks"]
fontes: ["game/data/perks/head_hunter.tres", "game/data/resources/perk_data.gd"]
---

# Perk — Head Hunter

← [[02 Conteúdo/Perks|Perks]]

Headshot specialist.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `head_hunter` · **Nome no jogo:** Head Hunter

| Campo | Valor | Origem |
|---|---|---|
| Ramo | combat | `.tres` |
| Patamar | 1 | `.tres` |
| Alternativa (0=A, 1=B) | 0 | `.tres` |
| Filtro de classe |  | Por defeito no Resource |
| Benefício | Headshot cone {v}° | `.tres` |
| Valores do benefício (I/II/III) | PackedFloat32Array(11, 13, 15) | `.tres` |
| Valores do segundo benefício | PackedFloat32Array() | Por defeito no Resource |
| Contrapartida | Body-shot damage −{v}% | `.tres` |
| Valores da contrapartida (I/II/III) | PackedFloat32Array(5, 10, 15) | `.tres` |

Os arrays de valores são totais por rank, não incrementos. Os ranks pertencem ao nó; há alternativas com contrapartidas. Ver [[03 Sistemas/Intel e perks]].

## Fontes

- `game/data/perks/head_hunter.tres`
- `game/data/resources/perk_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
