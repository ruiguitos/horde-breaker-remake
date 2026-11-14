---
titulo: "Carta — Ammo Reserves"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-14"
tags: ["horde-breaker", "cards"]
fontes: ["game/data/cards/bigger_mags.tres", "game/data/resources/card_data.gd"]
---

# Carta — Ammo Reserves

← [[02 Conteúdo/Cartas|Cartas]]

+15% maximum reserve ammo per rank for weapons with a finite reserve. Does not refill ammo.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `bigger_mags` · **Nome no jogo:** Ammo Reserves

| Campo | Valor | Origem |
|---|---|---|
| Ranks máximos | 5 | `.tres` |
| Categoria | utility | Por defeito no Resource |
| Etiquetas do jogo | Array[StringName]([&"ammo"]) | `.tres` |
| Filtro de classe | — | Por defeito no Resource |
| Exige arma com reserva limitada | Sim | `.tres` |
| Pré-requisitos | {} | Por defeito no Resource |
| Desbloqueio (Intel) | 0 | Por defeito no Resource |

Ver [[03 Sistemas/XP e cartas]] para recolha de XP, ranks máximos e rerolls.

## Fontes

- `game/data/cards/bigger_mags.tres`
- `game/data/resources/card_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
