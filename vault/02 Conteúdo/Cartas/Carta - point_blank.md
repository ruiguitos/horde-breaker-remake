---
titulo: "Carta — Point Blank"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-15"
tags: ["horde-breaker", "cards"]
fontes: ["game/data/cards/point_blank.tres", "game/data/resources/card_data.gd"]
---

# Carta — Point Blank

← [[02 Conteúdo/Cartas|Cartas]]

+10% primary damage per rank against targets within 4 m.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `point_blank` · **Nome no jogo:** Point Blank

| Campo | Valor | Origem |
|---|---|---|
| Ranks máximos | 3 | `.tres` |
| Categoria | primary_weapon | `.tres` |
| Etiquetas do jogo | Array[StringName]([&"damage", &"close_range"]) | `.tres` |
| Filtro de classe | — | Por defeito no Resource |
| Filtro de arma | Array[StringName]([&"rifle", &"smg", &"machine_gun"]) | `.tres` |
| Exige arma com reserva limitada | Não | Por defeito no Resource |
| Pré-requisitos | {} | Por defeito no Resource |
| Desbloqueio (Intel) | 0 | Por defeito no Resource |

Ver [[03 Sistemas/XP e cartas]] para recolha de XP, ranks máximos e rerolls.

## Fontes

- `game/data/cards/point_blank.tres`
- `game/data/resources/card_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
