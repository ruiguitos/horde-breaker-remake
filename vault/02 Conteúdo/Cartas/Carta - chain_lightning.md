---
titulo: "Carta — Chain Lightning"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-15"
tags: ["horde-breaker", "cards"]
fontes: ["game/data/cards/chain_lightning.tres", "game/data/resources/card_data.gd"]
---

# Carta — Chain Lightning

← [[02 Conteúdo/Cartas|Cartas]]

Discharges jump to one extra target per rank. Requires Storm Rounds.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `chain_lightning` · **Nome no jogo:** Chain Lightning

| Campo | Valor | Origem |
|---|---|---|
| Ranks máximos | 3 | `.tres` |
| Categoria | elements | `.tres` |
| Etiquetas do jogo | Array[StringName]([&"storm", &"chain"]) | `.tres` |
| Filtro de classe | — | Por defeito no Resource |
| Filtro de arma | Array[StringName]([&"rifle", &"smg", &"machine_gun"]) | `.tres` |
| Exige arma com reserva limitada | Não | Por defeito no Resource |
| Pré-requisitos | Dictionary[StringName, int]({ &"storm_rounds": 1 }) | `.tres` |
| Desbloqueio (Intel) | 30 | `.tres` |

Ver [[03 Sistemas/XP e cartas]] para recolha de XP, ranks máximos e rerolls.

## Fontes

- `game/data/cards/chain_lightning.tres`
- `game/data/resources/card_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
