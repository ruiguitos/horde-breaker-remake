---
titulo: "Carta — Wildfire"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-14"
tags: ["horde-breaker", "cards"]
fontes: ["game/data/cards/wildfire.tres", "game/data/resources/card_data.gd"]
---

# Carta — Wildfire

← [[02 Conteúdo/Cartas|Cartas]]

Direct kills of burning enemies spread fire to one nearby target per rank. Requires Fire Rounds.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `wildfire` · **Nome no jogo:** Wildfire

| Campo | Valor | Origem |
|---|---|---|
| Ranks máximos | 3 | `.tres` |
| Categoria | elements | `.tres` |
| Etiquetas do jogo | Array[StringName]([&"fire", &"kill"]) | `.tres` |
| Filtro de classe | — | Por defeito no Resource |
| Filtro de arma | Array[StringName]([&"rifle", &"smg", &"machine_gun"]) | `.tres` |
| Exige arma com reserva limitada | Não | Por defeito no Resource |
| Pré-requisitos | Dictionary[StringName, int]({ &"fire_rounds": 1 }) | `.tres` |
| Desbloqueio (Intel) | 30 | `.tres` |

Ver [[03 Sistemas/XP e cartas]] para recolha de XP, ranks máximos e rerolls.

## Fontes

- `game/data/cards/wildfire.tres`
- `game/data/resources/card_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
