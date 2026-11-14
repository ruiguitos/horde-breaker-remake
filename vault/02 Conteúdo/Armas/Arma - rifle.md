---
titulo: "Arma — Assault Rifle"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-14"
tags: ["horde-breaker", "weapons"]
fontes: ["game/data/weapons/rifle.tres", "game/data/resources/weapon_data.gd"]
---

# Arma — Assault Rifle

← [[02 Conteúdo/Armas|Armas]]

Balanced primary. Infinite reserve, 30-round magazine.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `rifle` · **Nome no jogo:** Assault Rifle

| Campo | Valor | Origem |
|---|---|---|
| Dano base (HP) | 12.0 | `.tres` |
| Cadência (tiros/s) | 9.0 | `.tres` |
| Alcance (m) | 30.0 | `.tres` |
| Projéteis por disparo | 1 | Por defeito no Resource |
| Dispersão (graus) | 2.0 | `.tres` |
| Alvos por projétil | 1 | Por defeito no Resource |
| Reserva (-1 = infinita) | -1 | Por defeito no Resource |
| Empurrão (m) | 0.05 | `.tres` |
| Carregador (0 = sem carregador) | 30 | `.tres` |
| Desbloqueio (Intel) | 0 | Por defeito no Resource |
| Arma principal | Sim | `.tres` |
| Recarga (s) | 0.0 | Por defeito no Resource |
| Multiplicador de movimento | 1.0 | Por defeito no Resource |
| Multiplicador de dano próximo | 1.0 | Por defeito no Resource |
| Distância do bónus próximo (m) | 0.0 | Por defeito no Resource |

## Fontes

- `game/data/weapons/rifle.tres`
- `game/data/resources/weapon_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
