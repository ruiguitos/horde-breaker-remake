---
titulo: "Carta — Grenadier"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-15"
tags: ["horde-breaker", "cards"]
fontes: ["game/data/cards/grenadier.tres", "game/data/resources/card_data.gd"]
---

# Carta — Grenadier

← [[02 Conteúdo/Cartas|Cartas]]

Grenade cooldown is multiplied by 0.9 per rank.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `grenadier` · **Nome no jogo:** Grenadier

| Campo | Valor | Origem |
|---|---|---|
| Ranks máximos | 5 | `.tres` |
| Categoria | class_recruit | `.tres` |
| Etiquetas do jogo | Array[StringName]([&"grenade", &"cooldown"]) | `.tres` |
| Filtro de classe | Array[StringName]([&"recruit"]) | `.tres` |
| Exige arma com reserva limitada | Não | Por defeito no Resource |
| Pré-requisitos | {} | Por defeito no Resource |
| Desbloqueio (Intel) | 0 | Por defeito no Resource |

Ver [[03 Sistemas/XP e cartas]] para recolha de XP, ranks máximos e rerolls.

## Fontes

- `game/data/cards/grenadier.tres`
- `game/data/resources/card_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
