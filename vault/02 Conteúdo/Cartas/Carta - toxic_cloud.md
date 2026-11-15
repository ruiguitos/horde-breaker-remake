---
titulo: "Carta — Toxic Cloud"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-15"
tags: ["horde-breaker", "cards"]
fontes: ["game/data/cards/toxic_cloud.tres", "game/data/resources/card_data.gd"]
---

# Carta — Toxic Cloud

← [[02 Conteúdo/Cartas|Cartas]]

Direct kills of poisoned enemies leave a 2 m cloud dealing 6 damage/s for 1 + rank seconds. Requires Toxic Rounds.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `toxic_cloud` · **Nome no jogo:** Toxic Cloud

| Campo | Valor | Origem |
|---|---|---|
| Ranks máximos | 3 | `.tres` |
| Categoria | elements | `.tres` |
| Etiquetas do jogo | Array[StringName]([&"toxic", &"kill", &"area"]) | `.tres` |
| Filtro de classe | — | Por defeito no Resource |
| Filtro de arma | Array[StringName]([&"rifle", &"smg", &"machine_gun"]) | `.tres` |
| Exige arma com reserva limitada | Não | Por defeito no Resource |
| Pré-requisitos | Dictionary[StringName, int]({ &"toxic_rounds": 1 }) | `.tres` |
| Desbloqueio (Intel) | 0 | Por defeito no Resource |

Ver [[03 Sistemas/XP e cartas]] para recolha de XP, ranks máximos e rerolls.

## Fontes

- `game/data/cards/toxic_cloud.tres`
- `game/data/resources/card_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
