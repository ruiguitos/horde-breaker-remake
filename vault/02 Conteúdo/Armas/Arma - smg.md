---
titulo: "Arma — SMG"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-15"
tags: ["horde-breaker", "weapons"]
fontes: ["game/data/weapons/smg.tres", "game/data/resources/weapon_data.gd"]
---

# Arma — SMG

← [[02 Conteúdo/Armas|Armas]]

Mobile primary. +15% movement; +25% damage within 6 m. Short range, 40-round magazine, 1.1 s reload. Infinite reserve.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `smg` · **Nome no jogo:** SMG

| Campo | Valor | Origem |
|---|---|---|
| Dano base (HP) | 8.0 | `.tres` |
| Cadência (tiros/s) | 16.0 | `.tres` |
| Alcance (m) | 16.0 | `.tres` |
| Projéteis por disparo | 1 | Por defeito no Resource |
| Dispersão (graus) | 7.0 | `.tres` |
| Alvos por projétil | 1 | Por defeito no Resource |
| Reserva (-1 = infinita) | -1 | Por defeito no Resource |
| Empurrão (m) | 0.02 | `.tres` |
| Carregador (0 = sem carregador) | 40 | `.tres` |
| Desbloqueio (Intel) | 60 | `.tres` |
| Arma principal | Sim | `.tres` |
| Recarga (s) | 1.1 | `.tres` |
| Multiplicador de movimento | 1.15 | `.tres` |
| Multiplicador de dano próximo | 1.25 | `.tres` |
| Distância do bónus próximo (m) | 6.0 | `.tres` |

## Fontes

- `game/data/weapons/smg.tres`
- `game/data/resources/weapon_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
